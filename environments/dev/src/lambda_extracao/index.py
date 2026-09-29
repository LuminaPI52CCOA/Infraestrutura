import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info("Iniciando extracao do SISAGUA...")
    # TODO: Logica de conversao do .ipynb para buscar dados do SISAGUA
    # e salvar no bucket Bronze em formato CSV.
    bucket_bronze = os.environ.get("BUCKET_BRONZE")
    logger.info(f"Dados seriam salvos no bucket: {bucket_bronze}")
    
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "success", "message": "Extracao finalizada e salva no Bronze."})
    }
