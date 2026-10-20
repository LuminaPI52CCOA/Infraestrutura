# Guia de Engenharia: Criação e Integração de Novos Repositórios / Componentes
## Sistema Lumina Odontológica — Arquitetura Híbrida Modular & CI/CD Multi-Repo

**Público-Alvo:** Desenvolvedores, Engenheiros de Software e DevOps do time Lumina  
**Referência Arquitetural Oficial:** [`REFINAMENTO_ARQUITETURA_INFRA_CICD.md`](./REFINAMENTO_ARQUITETURA_INFRA_CICD.md)  
**Ambiente Cloud Oficial:** AWS Academy Learner Lab (Sessões Efêmeras de 4h, `LabRole`)  
**Fuso Horário Padrão:** `America/Sao_Paulo` (UTC-3)  

---

## 1. Visão Geral e Princípios Fundamentais

O sistema **Lumina** adota uma arquitetura **Multi-Repo com Modelo Híbrido Modular**. Isso significa que cada peça do sistema possui seu próprio repositório Git com ciclo de vida, testes e deploy de código autônomos, enquanto o repositório central [`Infraestrutura`](../Infraestrutura) atua como a **Torre de Controle** que orquestra recursos compartilhados (VPC, Subnets, ALBs, Security Groups, IAM Roles) e garante a subida e destruição centralizada (*One-Click Deploy & Destroy*).

Ao planejar a criação de uma nova peça na arquitetura (ex: um microsserviço de OCR/Visão Computacional, uma Lambda de ETL para o Data Lake, um worker de mensageria SQS, etc.), você **não cria um componente isolado do mundo**. Você deve seguir as regras de governança para que sua peça:
1. Possa ser testada automaticamente no GitHub Actions sem custos.
2. Possa ser atualizada em menos de 1 minuto em produção/dev sem recriar servidores.
3. Seja provisionada automaticamente pelo Terraform no repositório de `Infraestrutura`.
4. Seja destruída sem deixar recursos órfãos que consumam os créditos de $100 do Learner Lab.

---

## 2. Matriz de Responsabilidades: Onde Fica Cada Código?

Antes de criar qualquer arquivo, compreenda a divisão de responsabilidades:

| Responsabilidade | No Novo Repositório do Componente (`ex: Lumina-ETL`) | No Repositório Central ([`Infraestrutura`](../Infraestrutura)) |
| :--- | :--- | :--- |
| **Código de Negócio** | ✅ 100% aqui (Python, Node, Java, Go, etc.) | ❌ Nunca |
| **Testes Unitários / Mocks** | ✅ 100% aqui (`npm test`, `pytest`, `mvn test`) | ❌ Nunca |
| **Pipeline de Integração (CI)** | ✅ Valida lint, build e testes a cada push/PR | ❌ Apenas valida sintaxe do Terraform |
| **Deploy Rápido de Código (CD)** | ✅ Atualiza apenas o artefato (SCP `.jar`/HTML ou `update-function-code`) | ❌ Nunca usado para deploy de app |
| **Declaração do Recurso Cloud** | ✅ Manifestos autônomos locais (`terraform/` no caso de Lambdas/workers) | ✅ Instanciação do módulo nos ambientes `dev` e `prod` |
| **Rede, VPC, Subnets e ALBs** | ❌ Não gerencia rede nem firewalls | ✅ 100% centralizado em `modules/network` |
| **IAM e Credenciais** | ❌ Nunca cria chaves permanentes de acesso | ✅ Vincula à `LabRole` existente da AWS Academy |

---

## 3. Estrutura Canônica de Pastas do Novo Repositório

Todo novo repositório adicionado à organização `LuminaPI52CCOA` deve adotar obrigatoriamente a estrutura abaixo:

```text
nome-do-novo-repositorio/
├── .github/
│   └── workflows/
│       ├── <nome>-ci.yml          # CI Automático: Linting, Typecheck e Testes Unitários
│       └── <nome>-cd.yml          # CD Manual (workflow_dispatch): Deploy rápido de artefato
├── src/                           # Código-fonte da aplicação
│   └── ...
├── test/                          # Suíte de testes automatizados independentes
│   └── ...
├── terraform/                     # (Obrigatório se for Serverless/Lambda ou módulo customizado)
│   ├── main.tf                    # Declaração do recurso AWS (ex: aws_lambda_function)
│   ├── variables.tf               # Variáveis de entrada (endpoints, timeouts, roles)
│   └── outputs.tf                 # ARNs, nomes e identificadores para o orquestrador
├── .gitignore                     # Ignora .terraform, .env, *.pem, node_modules, dist, etc.
└── README.md                      # Documentação de arquitetura, variáveis e execução local
```

---

## 4. As 5 Regras de Ouro Técnicas da Arquitetura Lumina

Qualquer novo componente deve aderir rigorosamente a estas 5 regras:

### Regra 1: Proibido Criar Usuários IAM ou Chaves Permanentes
No AWS Academy Learner Lab, estudantes não têm permissão para criar `aws_iam_user`, `aws_iam_access_key` ou `aws_iam_role`.
- **Em funções Lambda:** Use sempre a role pré-existente do Lab:
  ```hcl
  data "aws_iam_role" "lab_role" {
    name = "LabRole"
  }

  resource "aws_lambda_function" "this" {
    # ...
    role = data.aws_iam_role.lab_role.arn
  }
  ```
- **Em instâncias EC2:** Associe o profile existente `LabInstanceProfile`.

### Regra 2: Fuso Horário Obrigatório `America/Sao_Paulo` (UTC-3)
Todas as regras de negócio de agendamento, expiração, logs e rotinas cron operam no horário de Brasília.
- **Nos testes:** Nunca compare `LocalDateTime.now()` direto com classes de negócio se a lógica interna do serviço usar `ZoneId.of("America/Sao_Paulo")`, pois os runners do GitHub Actions rodam em **UTC padrão** e as asserções de tempo quebrarão.

### Regra 3: Testes de CI 100% Isolados e Independentes (Zero Dependências Externas)
A pipeline de CI (`<nome>-ci.yml`) deve rodar em um runner Ubuntu limpo.
- **Se precisar de banco de dados:** Utilize banco em memória (ex: H2 com compatibilidade MySQL para Java, SQLite para Python) ou mocks via Mockito/Jest/unittest.mock.
- **Nunca assuma que a AWS ou o MySQL estão rodando no runner de CI.**

### Regra 4: Alinhamento de Nomes e Variáveis de Ambiente
- **Banco de Dados:** O schema oficial é sempre grafado como **`Lumina`** (com 'L' maiúsculo — MySQL em Linux é sensível a maiúsculas).
- **Parâmetros Dinâmicos:** Nunca hardcode IPs ou URLs da AWS no código. Obtenha-os via variáveis de ambiente com fallback para ambiente local:
  ```javascript
  const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:8080";
  ```

### Regra 5: Padrão de Chave SSH Institucional
Se o novo componente rodar em uma máquina EC2 ou precisar de salto SSH pelo Bastion Host:
- O par de chaves oficial é **`lumina-deploy-key`**.
- O GitHub Secret padrão compartilhado entre todos os repositórios é **`SSH_PRIVATE_KEY`**.

---

## 5. Passo a Passo Prático: Como Integrar o Novo Repositório na Infraestrutura

Suponha que você esteja criando um novo serviço chamado **`Lambda-ETL`** (ou um novo worker/API). Siga estes 4 passos exatos:

### Passo 1: Criar o Módulo Terraform no Novo Repositório
Crie a pasta `terraform/` dentro do seu novo repositório com os arquivos:

* **`terraform/variables.tf`**:
  ```hcl
  variable "function_name" {
    type        = string
    description = "Nome da função Lambda"
    default     = "lumina-etl-processor-dev"
  }

  variable "s3_bucket_arn" {
    type        = string
    description = "ARN do Bucket S3 de dados"
    default     = ""
  }
  ```

* **`terraform/main.tf`**:
  ```hcl
  data "aws_iam_role" "lab_role" {
    name = "LabRole"
  }

  data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "${path.module}/../src"
    output_path = "${path.module}/dist/lambda.zip"
    excludes    = ["node_modules", "test", "__pycache__"]
  }

  resource "aws_lambda_function" "this" {
    function_name = var.function_name
    role          = data.aws_iam_role.lab_role.arn
    handler       = "index.handler"
    runtime       = "nodejs20.x" # ou python3.12
    filename      = data.archive_file.lambda_zip.output_path
    timeout       = 30
    memory_size   = 256

    environment {
      variables = {
        S3_BUCKET_ARN = var.s3_bucket_arn
        TZ            = "America/Sao_Paulo"
      }
    }
  }
  ```

* **`terraform/outputs.tf`**:
  ```hcl
  output "lambda_arn" {
    value = aws_lambda_function.this.arn
  }
  ```

---

### Passo 2: Plugar o Módulo no Repositório `Infraestrutura`
No repositório central [`Infraestrutura`](../Infraestrutura):

1. Abra [`environments/dev/main.tf`](../Infraestrutura/environments/dev/main.tf) e adicione a chamada do seu módulo:
   ```hcl
   module "etl" {
     source        = "../../../Lambda-ETL/terraform"
     function_name = "lumina-etl-dev"
     s3_bucket_arn = module.network.bucket_dados_arn # caso aplicável
   }
   ```
2. Adicione a mesma chamada parametrizada em [`environments/prod/main.tf`](../Infraestrutura/environments/prod/main.tf) com nome de produção (ex: `lumina-etl-prod`).
3. Se quiser exibir saídas da sua peça após o `terraform apply`, exporte em `outputs.tf`:
   ```hcl
   output "etl_lambda_arn" {
     value = module.etl.lambda_arn
   }
   ```

---

### Passo 3: Atualizar os Workflows do Terraform para Multi-Repo Checkout
Como o Terraform em `Infraestrutura` precisa ler os arquivos da pasta `Lambda-ETL/terraform` durante a execução remota no GitHub Actions:

Abra [`.github/workflows/terraform-ci.yml`](../Infraestrutura/.github/workflows/terraform-ci.yml) e [`.github/workflows/terraform-deploy.yml`](../Infraestrutura/.github/workflows/terraform-deploy.yml) e adicione o checkout do seu novo repositório:

```yaml
      - name: Checkout do Modulo Lambda-ETL
        uses: actions/checkout@v4
        with:
          repository: 'LuminaPI52CCOA/Lambda-ETL'
          ref: 'main'
          path: 'Lambda-ETL'

      - name: Configurar estrutura de pastas multi-repo
        run: |
          mkdir -p ../../../Lambda-ETL
          cp -r Lambda-ETL/* ../../../Lambda-ETL/ 2>/dev/null || true
          mkdir -p ../../Lambda-ETL
          cp -r Lambda-ETL/* ../../Lambda-ETL/ 2>/dev/null || true
          mkdir -p ../Lambda-ETL
          cp -r Lambda-ETL/* ../Lambda-ETL/ 2>/dev/null || true
```

---

### Passo 4: Validar Localmente antes de Commitar
No repositório `Infraestrutura`, execute a validação de sintaxe para garantir que a ligação entre os repositórios está perfeita:
```bash
terraform -chdir=environments/dev validate
terraform -chdir=environments/prod validate
```
Ambos devem retornar: `Success! The configuration is valid.`

---

## 6. Modelos de Workflows de CI/CD para Copiar e Colar

Para acelerar a configuração, use os templates oficiais da Lumina:

### 6.1. Pipeline de Integração Contínua (CI Automático)
Crie `.github/workflows/<servico>-ci.yml` no seu novo repositório:

```yaml
name: "Novo Servico CI (Lint e Testes)"

on:
  push:
    branches: [main, develop, feat/*]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    name: "Validar Codigo e Executar Testes"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout do Repositorio
        uses: actions/checkout@v4

      # Ajuste para Node.js, Python ou Java conforme sua stack:
      - name: Configurar Ambiente de Runtime
        uses: actions/setup-node@v4 # ou actions/setup-python@v5 / actions/setup-java@v4
        with:
          node-version: "20"
          cache: "npm"

      - name: Instalar Dependencias
        run: npm ci

      - name: Executar Lint / Verificacao Estatica
        run: npm run lint || true

      - name: Executar Testes Unitarios
        run: npm test
```

### 6.2. Pipeline de Deploy Rápido (CD Manual para Lambda)
Se for uma função Lambda, crie `.github/workflows/<servico>-cd.yml`:

```yaml
name: "Novo Servico CD (Deploy Rapido na AWS Lambda)"

on:
  workflow_dispatch:
    inputs:
      function_name:
        description: "Nome da Funcao Lambda na AWS"
        required: true
        default: "lumina-etl-dev"
        type: string
      aws_access_key_id:
        description: "AWS Access Key ID (Lab)"
        required: true
        type: string
      aws_secret_access_key:
        description: "AWS Secret Access Key"
        required: true
        type: string
      aws_session_token:
        description: "AWS Session Token"
        required: true
        type: string

jobs:
  deploy:
    name: "Atualizar Codigo da Lambda"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout do Repositorio
        uses: actions/checkout@v4

      - name: Autenticar na AWS (Credenciais do Lab)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ inputs.aws_access_key_id }}
          aws-secret-access-key: ${{ inputs.aws_secret_access_key }}
          aws-session-token: ${{ inputs.aws_session_token }}
          aws-region: "us-east-1"

      - name: Empacotar Artefato (.zip)
        run: |
          mkdir -p dist
          zip -r dist/function.zip src/ package.json -x "*test*" "*node_modules*"

      - name: Atualizar Codigo na AWS Lambda
        run: |
          aws lambda update-function-code \
            --function-name ${{ inputs.function_name }} \
            --zip-file fileb://dist/function.zip

      - name: Sucesso
        run: echo "✅ Codigo da Lambda atualizado com sucesso em ~10 segundos!"
```

---

## 7. Checklist de Entrega do Novo Repositório

Antes de abrir o Pull Request ou considerar o novo repositório pronto para homologação, confirme todos os itens:

- [ ] Repositório criado sob a organização oficial `LuminaPI52CCOA`.
- [ ] Branches principais criadas: `main`, `develop` e a branch de trabalho `feat/<nome>`.
- [ ] O pipeline de CI (`<nome>-ci.yml`) executa em cada push e passa com **100% de sucesso**.
- [ ] Não há senhas, tokens ou credenciais AWS gravados no código (tudo injetado via `env` ou secrets).
- [ ] Fuso horário nos testes e lógica respeita `America/Sao_Paulo`.
- [ ] Pasta `terraform/` criada com `LabRole` (se for recurso serverless).
- [ ] Módulo conectado no [`environments/dev/main.tf`](../Infraestrutura/environments/dev/main.tf) e [`prod/main.tf`](../Infraestrutura/environments/prod/main.tf) da `Infraestrutura`.
- [ ] `terraform validate` executado com sucesso em `dev` e `prod`.
- [ ] Repositório adicionado no step de checkout multi-repo das pipelines de infraestrutura.
- [ ] Documentação (`README.md`) explicando como rodar o serviço localmente e quais variáveis de ambiente ele consome.
