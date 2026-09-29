import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, lower

# Recupera argumentos passados na criacao/execucao do job
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET_BRONZE', 'BUCKET_SILVER'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print("Iniciando Transformacao Glue: Bronze -> Silver")

bucket_bronze = args['BUCKET_BRONZE']
bucket_silver = args['BUCKET_SILVER']

# 1. Processamento: Controle Semestral
print("Processando Controle Semestral...")
try:
    df_semestral = spark.read.option("header", "true").option("delimiter", ";").option("encoding", "latin1").csv(f"{bucket_bronze}/sisagua/controle_semestral/*/*.csv")
    
    # A 4ª coluna (indice 3) é NO_MUNICIPIO
    col_municipio_sem = df_semestral.columns[3]
    
    df_semestral_filtrado = df_semestral.filter(lower(col(col_municipio_sem)).contains("santo andre"))
    
    df_semestral_filtrado.write.mode("append").parquet(f"{bucket_silver}/sisagua/tratado/controle_semestral/")
    print("Controle Semestral processado e salvo como Parquet.")
except Exception as e:
    print(f"Aviso: Nao foi possivel processar o Controle Semestral. Detalhes: {str(e)}")

# 2. Processamento: Controle Mensal
print("Processando Controle Mensal...")
try:
    df_mensal = spark.read.option("header", "true").option("delimiter", ";").option("encoding", "latin1").csv(f"{bucket_bronze}/sisagua/controle_mensal/*/*.csv")
    
    # A 5ª coluna (indice 4) é Município
    col_municipio_men = df_mensal.columns[4]
    
    df_mensal_filtrado = df_mensal.filter(lower(col(col_municipio_men)).contains("santo andre"))
    
    df_mensal_filtrado.write.mode("append").parquet(f"{bucket_silver}/sisagua/tratado/controle_mensal/")
    
    # 3. Extração Específica: Fluoreto
    # A 20ª coluna (indice 19) é o Parâmetro
    col_parametro = df_mensal_filtrado.columns[19]
    df_fluoreto = df_mensal_filtrado.filter(lower(col(col_parametro)).contains("flu"))
    
    df_fluoreto.write.mode("append").parquet(f"{bucket_silver}/sisagua/tratado/fluoreto/")
    print("Controle Mensal e Fluoreto processados e salvos como Parquet.")
except Exception as e:
    print(f"Aviso: Nao foi possivel processar o Controle Mensal. Detalhes: {str(e)}")

job.commit()

