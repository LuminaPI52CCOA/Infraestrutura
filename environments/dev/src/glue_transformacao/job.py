import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job

# args = getResolvedOptions(sys.argv, ['JOB_NAME', 'BUCKET_BRONZE', 'BUCKET_SILVER'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
# job.init(args['JOB_NAME'], args)

print("Iniciando Transformacao Glue: Bronze -> Silver")
# TODO: Logica de transformacao e melhoria de dados (CSV para Parquet)

job.commit()
