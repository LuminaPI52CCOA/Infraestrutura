# LocalStack Lumina

Projeto com recursos AWS criados no LocalStack para testes locais.

## Endpoint

```
http://localhost:4566
```

As credenciais AWS utilizadas são as dummy do LocalStack (Access Key: `test` / Secret Key: `test`, região `us-east-1`).

---

## Recursos Criados

### 1. Buckets S3

Três buckets criados no padrão de camadas de dados:

| Bucket | Finalidade |
|--------|-----------|
| `bronze` | Dados brutos (raw) |
| `silver` | Dados tratados / limpos |
| `gold` | Dados agregados / prontos para consumo |

**Deploy no script unificado:** `deploy-localstack-lumina.sh` (cria os buckets, a Lambda e o API Gateway de uma vez)

### 2. Lambda Function

| Item | Valor |
|------|-------|
| Nome | `lumina-test` |
| Runtime | Python 3.9 |
| Handler | `lambda_function.lambda_handler` |
| Resposta | `"Teste Lumina realizado com sucesso!"` |

**Arquivos:** `lambda_function.py` e `deploy-localstack-lumina.sh`

### 3. API Gateway

| Item | Valor |
|------|-------|
| API Name | `lumina-api` |
| Resource | `/lumina` |
| Método | `GET` |
| Stage | `prod` |

---

## Como Executar

### 1. Subir o LocalStack

```bash
localstack start -d -e GATEWAY_LISTEN=0.0.0.0:4566
```

> **Dica:** O `-d` roda o LocalStack em background (daemon). A porta é controlada pela variável `GATEWAY_LISTEN` (a flag `--port` foi removida nas versões novas do CLI). Para usar outra porta, basta trocar o número — ex: `GATEWAY_LISTEN=0.0.0.0:5000`. Lembre-se de ajustar os exemplos deste README e os scripts de acordo.

### 2. Deploy de tudo (buckets S3 + Lambda + API Gateway)

```bash
bash deploy-localstack-lumina.sh
```

O script:
1. Configura um perfil AWS dedicado `localstack` com credenciais dummy (`test`/`test`, região `us-east-1`) — **sem sobrescrever** o perfil `default` do seu `~/.aws`.
2. Aguarda o LocalStack ficar pronto.
3. Cria os buckets `bronze`/`silver`/`gold`.
4. Faz o deploy da Lambda `lumina-test` e configura o API Gateway (GET `/lumina`, stage `prod`).

No fim, exibe a **URL de acesso** e uma linha pronta para copiar:

```bash
export API_ID=<id>
```

que permite usar `$API_ID` em invocações manuais depois.

### 3. Fluxo recomendado na apresentação (Terraform + LocalStack)

```
1. localstack start -d -e GATEWAY_LISTEN=0.0.0.0:4566
2. terraform apply      # sobe os recursos via Terraform (apresentação)
3. ... apresentação ...
4. terraform destroy    # apaga todos os recursos
5. bash deploy-localstack-lumina.sh   # sobe buckets + Lambda + API de novo
```

> **Credenciais × endpoint × licença:** o LocalStack não valida credenciais AWS — use dummy (`test`/`test`). O que define o destino é o `--endpoint-url` (ou `endpoints` no provider do Terraform). Já a `LOCALSTACK_API_KEY` é apenas a licença do LocalStack **Pro**, usada ao subir o container — não tem relação com autenticação AWS.

---

## Como Acessar via Requisições Web

### Invocar a Lambda (GET /lumina)

```bash
curl http://localhost:4566/restapis/<API_ID>/prod/_user_request_/lumina
```

> Substitua `<API_ID>` pelo ID exibido no script `deploy-localstack-lumina.sh` ou obtenha com:
> ```bash
> aws --profile localstack --endpoint-url=http://localhost:4566 apigateway get-rest-apis
> ```

**Resposta esperada:**

```json
{"statusCode":200,"body":"\"Teste Lumina realizado com sucesso!\""}
```

### Listar buckets S3

```bash
aws --profile localstack --endpoint-url=http://localhost:4566 s3 ls
```

### Fazer upload de um arquivo

```bash
aws --profile localstack --endpoint-url=http://localhost:4566 s3 cp <arquivo> s3://bronze/
```

### Listar objetos de um bucket

```bash
aws --profile localstack --endpoint-url=http://localhost:4566 s3 ls s3://bronze/
```

### Baixar um objeto

```bash
aws --profile localstack --endpoint-url=http://localhost:4566 s3 cp s3://bronze/<arquivo> .
```

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| `LocalStack não está rodando` | Inicie com `localstack start` e aguarde ficar pronto |
| `Bucket ... já existe` | Buckets são globais no S3; delete ou use um nome único |
| `Unable to locate credentials` | Rode o `deploy-localstack-lumina.sh` (cria o perfil `localstack`) ou configure dummy com `aws configure set aws_access_key_id test --profile localstack` |
| Porta conflitante | Certifique-se de que a porta `4566` está livre |