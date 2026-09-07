#!/bin/bash
set -e

PORT="4566"
ENDPOINT="http://127.0.0.1:${PORT}"
REGION="us-east-1"
AWS_ACCOUNT_ID="000000000000"
BUCKETS=("bronze" "silver" "gold")
FUNCTION_NAME="lumina-test"
ROLE_NAME="lambda-role"
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
LAMBDA_ARN="arn:aws:lambda:${REGION}:${AWS_ACCOUNT_ID}:function:${FUNCTION_NAME}"
ZIP_FILE="lambda_function.zip"
STAGE_NAME="prod"
PATH_PART="lumina"

echo "=== 1. Configurando perfil AWS 'localstack' (credenciais dummy) ==="
aws configure set aws_access_key_id test --profile localstack
aws configure set aws_secret_access_key test --profile localstack
aws configure set region "$REGION" --profile localstack
export AWS_PROFILE=localstack

echo ""
echo "=== 2. Aguardando o LocalStack ficar pronto em $ENDPOINT ==="
for i in $(seq 1 45); do
  if curl -s --fail --max-time 2 "$ENDPOINT/_localstack/health" > /dev/null 2>&1; then
    echo "LocalStack pronto!"
    break
  fi
  if [ "$i" -eq 45 ]; then
    echo "ERRO: LocalStack não respondeu em $ENDPOINT após 90 segundos."
    echo "Verifique se ele está rodando: docker logs localstack-main"
    exit 1
  fi
  printf '.'
  sleep 2
done

echo ""
echo "=== 3. Criando buckets S3 ==="
for bucket in "${BUCKETS[@]}"; do
  echo "Criando bucket: $bucket"
  if aws --endpoint-url="$ENDPOINT" s3api create-bucket --bucket "$bucket" > /dev/null 2>&1; then
    echo "Bucket '$bucket' criado com sucesso"
  else
    echo "ERRO: Falha ao criar bucket '$bucket'. Verifique se ele já existe."
    exit 1
  fi
done

aws --endpoint-url="$ENDPOINT" s3 ls

echo ""
echo "=== 4. Criando IAM Role ($ROLE_NAME) ==="
aws --endpoint-url="$ENDPOINT" iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' \
  > /dev/null 2>&1 || echo "Role '$ROLE_NAME' já existe, prosseguindo..."

echo ""
echo "=== 5. Empacotando Lambda ==="
rm -f "$ZIP_FILE"
zip -r "$ZIP_FILE" lambda_function.py

echo ""
echo "=== 6. Criando Lambda ($FUNCTION_NAME) ==="
if aws --endpoint-url="$ENDPOINT" lambda get-function --function-name "$FUNCTION_NAME" > /dev/null 2>&1; then
  echo "Função '$FUNCTION_NAME' já existe, atualizando código..."
  aws --endpoint-url="$ENDPOINT" lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://$ZIP_FILE" > /dev/null
else
  aws --endpoint-url="$ENDPOINT" lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.9 \
    --role "$ROLE_ARN" \
    --handler lambda_function.lambda_handler \
    --zip-file "fileb://$ZIP_FILE" > /dev/null
  echo "Função '$FUNCTION_NAME' criada com sucesso"
fi

echo ""
echo "=== 7. Criando API Gateway REST API ==="
API_ID=$(aws --endpoint-url="$ENDPOINT" apigateway create-rest-api --name "lumina-api" --region "$REGION" --query 'id' --output text)
echo "API ID: $API_ID"

PARENT_ID=$(aws --endpoint-url="$ENDPOINT" apigateway get-resources --rest-api-id "$API_ID" --query 'items[0].id' --output text)

RESOURCE_ID=$(aws --endpoint-url="$ENDPOINT" apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$PARENT_ID" \
  --path-part "$PATH_PART" \
  --query 'id' --output text)

echo ""
echo "=== 8. Configurando método GET no recurso /$PATH_PART ==="
aws --endpoint-url="$ENDPOINT" apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --authorization-type NONE > /dev/null

aws --endpoint-url="$ENDPOINT" apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" > /dev/null

echo ""
echo "=== 9. Deploy no stage '$STAGE_NAME' ==="
aws --endpoint-url="$ENDPOINT" apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --stage-name "$STAGE_NAME" > /dev/null

echo ""
echo "=== 10. Adicionando permissão para API Gateway invocar a Lambda ==="
aws --endpoint-url="$ENDPOINT" lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "apigateway-invoke" \
  --action "lambda:InvokeFunction" \
  --principal "apigateway.amazonaws.com" \
  --source-arn "arn:aws:execute-api:${REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/GET/${PATH_PART}" \
  > /dev/null || echo "Permissão já existente ou erro ao adicionar (prosseguindo...)"

echo ""
echo "=== Testando Lambda invocação direta ==="
aws --endpoint-url="$ENDPOINT" lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --payload '{}' \
  response.json > /dev/null
cat response.json
rm -f response.json

echo ""
echo ""
echo "=== Deploy concluído com sucesso! ==="
echo "Buckets S3 criados: bronze, silver, gold"
echo "Lambda: $FUNCTION_NAME"
echo ""
echo "URL de acesso via web:"
echo "  http://localhost:${PORT}/restapis/${API_ID}/${STAGE_NAME}/_user_request_/${PATH_PART}"
echo ""
echo "Exemplo:"
echo "  curl http://localhost:${PORT}/restapis/${API_ID}/${STAGE_NAME}/_user_request_/${PATH_PART}"

echo ""
echo ""
echo "=== Para ter o API_ID na sua sessão (copie e cole) ==="
echo "export API_ID=${API_ID}"
echo ""
echo "Invoke manual via HTTP:"
echo "  curl \"http://localhost:${PORT}/restapis/\$API_ID/${STAGE_NAME}/_user_request_/${PATH_PART}\""
echo ""
echo "Invoke manual via AWS CLI:"
echo "  aws --profile localstack --endpoint-url=${ENDPOINT} lambda invoke --function-name ${FUNCTION_NAME} --payload '{}' response.json"