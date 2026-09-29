import json
import logging
import os
import boto3
import urllib.request
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

# URLs de dados abertos do SISAGUA (exemplo/placeholders que podem ser substituidos pelas URLs reais do portal)
URL_SEMESTRAL = "https://dados.gov.br/dataset/.../controle_semestral_2026.csv" 
URL_MENSAL = "https://dados.gov.br/dataset/.../controle_mensal_parametros_basicos_2026.csv"

def download_and_upload_to_s3(url, bucket, key):
    try:
        logger.info(f"Baixando dados de: {url}")
        # Para um cenario real de grandes arquivos, ideal usar streaming
        # response = urllib.request.urlopen(url)
        # s3_client.upload_fileobj(response, bucket, key)
        
        # Simulação para o ambiente de dev:
        dummy_csv = "col1;col2;col3;NO_MUNICIPIO;Município\\n1;2;3;SANTO ANDRE;SANTO ANDRE\\n"
        s3_client.put_object(Bucket=bucket, Key=key, Body=dummy_csv.encode('latin-1'))
        logger.info(f"Arquivo salvo no S3: s3://{bucket}/{key}")
    except Exception as e:
        logger.error(f"Erro ao processar {url}: {e}")
        raise e

def handler(event, context):
    logger.info("Iniciando extracao do SISAGUA...")
    bucket_bronze = os.environ.get("BUCKET_BRONZE")
    
    if not bucket_bronze:
        raise ValueError("Variavel de ambiente BUCKET_BRONZE nao configurada.")
        
    mes_atual = datetime.now().strftime("%Y-%m")
    
    # 1. Extrai Controle Semestral
    key_semestral = f"sisagua/controle_semestral/{mes_atual}/controle_semestral.csv"
    download_and_upload_to_s3(URL_SEMESTRAL, bucket_bronze, key_semestral)
    
    # 2. Extrai Controle Mensal (Parametros Basicos)
    key_mensal = f"sisagua/controle_mensal/{mes_atual}/controle_mensal.csv"
    download_and_upload_to_s3(URL_MENSAL, bucket_bronze, key_mensal)
    
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "success", "message": "Extracao finalizada e salva no Bronze."})
    }

