# ☁️ Lumina — Infraestrutura como Código (Terraform & AWS Cloud)

Este repositório gerencia todo o provisionamento de infraestrutura em nuvem (AWS Cloud) e esteiras de automação (CI/CD) do ecossistema **Lumina Odontológica** utilizando **Terraform** e **GitHub Actions**.

A arquitetura foi projetada para atender aos requisitos de alta disponibilidade e segurança, sendo 100% compatível com as políticas de controle de serviço (SCPs) e permissões de perfil (`LabRole`) do **AWS Academy Learner Lab**.

---

## 🏛️ Arquitetura dos Ambientes

A infraestrutura é estruturada de forma modular em `modules/` e instanciada em diretórios isolados dentro de `environments/`:

```text
Infraestrutura/
├── .github/workflows/
│   ├── terraform-deploy.yml      # CD: Provisionamento e destruição de Dev e Prod
│   ├── terraform-ci.yml          # CI: Validação sintática, formatação e linter
│   └── data-pipeline-deploy.yml  # CD: Provisionamento isolado da Pipeline de Dados
├── environments/
│   ├── dev/                      # Ambiente Econômico (3 instâncias, IP público, sem NAT)
│   ├── prod/                     # Ambiente de Banca (Multi-AZ, 7 instâncias, 2 ALBs, NAT)
│   └── data/                     # Ambiente Isolado da Pipeline SISAGUA (S3, Glue, Lambda)
├── modules/
│   ├── network/                  # VPC, Sub-redes, Route Tables, NAT Gateway, ALBs e SGs
│   ├── database/                 # EC2 MySQL Server com provisionamento automático do schema
│   ├── backend/                  # EC2 Spring Boot API com systemd e compilação Maven
│   ├── frontend/                 # EC2 NGINX com bundle React/Vite e proxy reverso
│   ├── s3/                       # Buckets S3 multi-camada (Bronze, Silver, Gold, Athena)
│   ├── lambda_alexa/             # Função Lambda Serverless da Skill de voz Alexa
│   ├── keypair/                  # Chave pública SSH gerenciada
│   └── efs/                      # Armazenamento compartilhado EFS (Modo Prod)
└── Terraform/                    # Estrutura monolítica legada (mantida para referência)
```

### 1. Ambiente `dev` (Econômico / Testes Rápidos)
* **Objetivo:** Menor consumo de créditos AWS e subida rápida (~3 a 4 minutos).
* **Topologia:** 3 instâncias EC2 (`t3.small` / `t3.micro`): Frontend (NGINX), Backend (Spring Boot) e Database (MySQL).
* **Rede:** Sub-rede pública com IP público e Internet Gateway (sem custo de NAT Gateway).

### 2. Ambiente `prod` (Multi-AZ / Apresentação de Banca)
* **Objetivo:** Alta disponibilidade, resiliência e isolamento de segurança em múltiplas Zonas de Disponibilidade (`us-east-1a` e `us-east-1b`).
* **Topologia:** 7 instâncias EC2 + 2 Application Load Balancers:
  * ALB Público (Borda) direcionando para 2 Frontend EC2s em sub-redes públicas.
  * ALB Interno privado direcionando para 2 Backend EC2s em sub-redes privadas.
  * 2 Database EC2s em sub-redes privadas de dados.
  * 1 Bastion Host (Jump Box) para administração SSH segura.
  * NAT Gateway para saída segura das instâncias privadas.

### 3. Ambiente `data` (Pipeline de Engenharia de Dados)
* **Objetivo:** Execução e teste da esteira analítica SISAGUA sem necessidade de subir servidores web ou bancos relacionais.
* **Recursos:** S3 Data Lake (Bronze, Silver, Gold, Athena Results), AWS Glue (Job PySpark e Crawler), EventBridge e Lambda de ingestão.

---

## 🔐 Configuração de Segurança e Secrets (GitHub Actions)

Seguindo a política de **Zero Credenciais Hardcoded (DevSecOps)**, nenhuma senha ou chave privada fica versionada nos arquivos `.tf`. Todas as credenciais são injetadas em tempo de execução via **GitHub Actions Secrets**.

Para configurar, acesse o repositório no GitHub:  
**Settings** > **Secrets and variables** > **Actions** > **New repository secret**.

| Nome do Secret | Finalidade |
| :--- | :--- |
| `SSH_PRIVATE_KEY` | Chave privada RSA correspondente à `lumina-deploy-key` (para deploy via SSH) |
| `DB_PASSWORD` | Senha configurada para o usuário `lumina_user` do banco MySQL |
| `JWT_SECRET` | Chave secreta HMAC para geração e validação de tokens JWT |
| `ALEXA_LWA_CLIENT_ID` | Client ID do Login with Amazon (LWA) para envio de lembretes da Alexa |
| `ALEXA_LWA_CLIENT_SECRET` | Client Secret do Login with Amazon (LWA) para autenticação OAuth2 |
| `GEMINI_API_KEY` | Chave de API do Google Gemini para resumos clínicos inteligentes |

---

## 🚀 Como Executar o Deploy via GitHub Actions

### 1. Provisionamento de Infraestrutura Completa (Dev ou Prod)
1. Acesse a aba **Actions** no repositório `Infraestrutura`.
2. Selecione o workflow **Terraform Infrastructure Deploy/Destroy**.
3. Clique em **Run workflow**:
   * **Ação:** `apply` (para provisionar) ou `destroy` (para destruir).
   * **Perfil de Ambiente:** `dev` ou `prod`.
   * **Credenciais AWS:** Cole suas credenciais ativas do Learner Lab (`aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`).
4. Clique em **Run workflow**. Ao término, a URL do Load Balancer público será exibida nos logs e outputs.

### 2. Provisionamento da Pipeline de Dados
1. Na aba **Actions**, selecione o workflow **Data Pipeline Deploy/Destroy**.
2. Clique em **Run workflow**, informe as credenciais do Learner Lab e selecione `apply` ou `destroy`.

---

## 💾 Persistência de Estado (Remote State)

Como os runners do GitHub Actions são efêmeros, o arquivo `terraform.tfstate` de cada ambiente é persistido automaticamente entre execuções na branch isolada **`terraform-states`** deste mesmo repositório, garantindo que o comando `destroy` ou novos `apply` reconheçam o estado exato dos recursos previamente criados.

---

## 💻 Execução Local (Opcional)

Para rodar via linha de comando local:
1. Navegue até a pasta do ambiente desejado (ex: `cd environments/dev`).
2. Crie seu arquivo de variáveis local: `cp terraform.tfvars.example terraform.tfvars`.
3. Preencha os valores reais no `terraform.tfvars` (arquivo ignorado pelo Git).
4. Execute:
   ```bash
   terraform init
   terraform apply
   ```
