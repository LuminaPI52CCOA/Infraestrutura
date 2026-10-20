import sys
import re
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import (
    col, input_file_name, regexp_extract, to_timestamp, 
    coalesce, lit, current_timestamp, year, month, dayofmonth,
    when, to_json, struct
)
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType, 
    LongType, DoubleType, TimestampType
)

# ==============================================================================
# 1. Inicializacao do Contexto Glue e Argumentos
# ==============================================================================
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET_BRONZE', 'BUCKET_SILVER'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

bucket_bronze = args['BUCKET_BRONZE'].rstrip('/')
bucket_silver = args['BUCKET_SILVER'].rstrip('/')

print(f"Iniciando Pipeline Dedicado de Logs Lumina: Bronze ({bucket_bronze}) -> Silver ({bucket_silver})")

# ==============================================================================
# 2. Leitura dos Logs Brutos da Camada Bronze (JSON e GZIP gerados pelo Fluent Bit)
# ==============================================================================
bronze_logs_path = f"{bucket_bronze}/logs/*/*/*/*/*.json*"
print(f"Lendo arquivos de log em: {bronze_logs_path}")

try:
    df_raw = spark.read.json(bronze_logs_path)
    
    # Identifica o caminho de origem do arquivo para classificar a fonte (source)
    df_with_meta = df_raw.withColumn("file_path", input_file_name())

    # Determina a fonte do log com base na pasta S3 (/logs/nginx/, /logs/backend/, etc.)
    df_with_meta = df_with_meta.withColumn(
        "log_source",
        when(col("file_path").contains("/logs/nginx/"), lit("nginx"))
        .when(col("file_path").contains("/logs/backend/"), lit("backend"))
        .when(col("file_path").contains("/logs/containers/"), lit("containers"))
        .when(col("file_path").contains("/logs/system_auth/"), lit("system_auth"))
        .otherwise(lit("outros"))
    )

    # ==============================================================================
    # 3. Normalizacao e Padronizacao dos Campos
    # ==============================================================================
    cols = df_with_meta.columns

    def get_col(column_name, fallback=None):
        if column_name in cols:
            return col(column_name)
        elif fallback and fallback in cols:
            return col(fallback)
        return lit(None)

    df_normalized = df_with_meta.select(
        coalesce(
            to_timestamp(get_col("time")),
            to_timestamp(get_col("@timestamp")),
            current_timestamp()
        ).alias("event_timestamp"),

        col("log_source").alias("source"),

        coalesce(
            get_col("level"),
            when(get_col("stream") == "stderr", lit("ERROR"))
            .when(get_col("stream") == "stdout", lit("INFO")),
            when(get_col("code") >= 500, lit("ERROR"))
            .when(get_col("code") >= 400, lit("WARN"))
            .when(get_col("code").isNotNull(), lit("INFO")),
            lit("INFO")
        ).alias("level"),

        coalesce(
            get_col("message"),
            get_col("log"),
            lit("")
        ).alias("message"),

        get_col("code").cast(IntegerType()).alias("http_status"),
        get_col("method").alias("http_method"),
        get_col("path").alias("http_path"),
        coalesce(get_col("remote"), get_col("host")).alias("client_ip"),

        coalesce(get_col("service"), lit("lumina-app")).alias("service_name"),
        get_col("logger").alias("logger_class"),

        year(coalesce(to_timestamp(get_col("time")), current_timestamp())).cast(StringType()).alias("year"),
        month(coalesce(to_timestamp(get_col("time")), current_timestamp())).cast(StringType()).alias("month"),
        dayofmonth(coalesce(to_timestamp(get_col("time")), current_timestamp())).cast(StringType()).alias("day")
    )

    # ==============================================================================
    # 4. Escrita Otimizada em Parquet na Camada Silver (Particionada)
    # ==============================================================================
    silver_output_path = f"{bucket_silver}/logs/"
    print(f"Gravando logs tratados e enriquecidos em Parquet em: {silver_output_path}")

    df_normalized.write \
        .mode("append") \
        .partitionBy("source", "year", "month", "day") \
        .parquet(silver_output_path)

    print("Processamento do Pipeline de Logs concluido com sucesso!")

except Exception as e:
    print(f"Aviso durante a execucao do pipeline de logs: {str(e)}")
    raise e

job.commit()
