#!/usr/bin/env bash
# ==============================================================================
# Lumina Infrastructure CLI Wrapper (AWS Academy Learner Lab Helper)
# Facilita o ciclo de vida da infraestrutura (Dev Econômico vs Prod Apresentação)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
  echo -e "${CYAN}====================================================================${NC}"
  echo -e "${CYAN}   ⚡ LUMINA INFRASTRUCTURE CLI — TORRE DE CONTROLE DE IAC ⚡   ${NC}"
  echo -e "${CYAN}====================================================================${NC}"
}

usage() {
  echo -e "${YELLOW}Uso:${NC} $0 <comando> <ambiente> [argumentos adicionais]"
  echo ""
  echo -e "${YELLOW}Comandos disponíveis:${NC}"
  echo -e "  ${GREEN}up${NC}       <dev|prod>    Inicializa e aplica o ambiente selecionado"
  echo -e "  ${GREEN}down${NC}     <dev|prod>    Destroi todos os recursos do ambiente"
  echo -e "  ${GREEN}plan${NC}     <dev|prod>    Gera e exibe o plano de execução"
  echo -e "  ${GREEN}outputs${NC}  <dev|prod>    Exibe as saídas (IPs, DNS do ALB, ARNs)"
  echo -e "  ${GREEN}validate${NC} <dev|prod>    Valida a sintaxe e configuração do Terraform"
  echo ""
  echo -e "${YELLOW}Ambientes:${NC}"
  echo -e "  ${BLUE}dev${NC}   Modo Econômico (3 instâncias, Single-AZ, sem NAT Gateway)"
  echo -e "  ${BLUE}prod${NC}  Modo Apresentação (7 instâncias, Multi-AZ, ALBs, NAT, EFS)"
  echo ""
  exit 1
}

check_credentials() {
  echo -e "${BLUE}🔍 Verificando credenciais ativas da AWS...${NC}"
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]] || [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]] || [[ -z "${AWS_SESSION_TOKEN:-}" ]]; then
    echo -e "${YELLOW}⚠️  Credenciais temporárias de sessão do Learner Lab não encontradas no ambiente!${NC}"
    echo -e "Por favor, cole as variáveis do painel AWS Academy Learner Lab:"
    echo ""
    read -r -p "AWS_ACCESS_KEY_ID: " input_key
    read -r -p "AWS_SECRET_ACCESS_KEY: " input_secret
    read -r -p "AWS_SESSION_TOKEN: " input_token

    export AWS_ACCESS_KEY_ID="$input_key"
    export AWS_SECRET_ACCESS_KEY="$input_secret"
    export AWS_SESSION_TOKEN="$input_token"
    export AWS_DEFAULT_REGION="us-east-1"
  fi

  echo -e "${GREEN}✅ Credenciais configuradas para a região us-east-1.${NC}"
}

COMMAND="${1:-}"
ENV="${2:-}"

if [[ -z "$COMMAND" ]] || [[ -z "$ENV" ]]; then
  print_banner
  usage
fi

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo -e "${RED}Erro: Ambiente inválido '${ENV}'. Escolha 'dev' ou 'prod'.${NC}"
  exit 1
fi

TARGET_DIR="${ROOT_DIR}/environments/${ENV}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo -e "${RED}Erro: Diretório de ambiente não encontrado em ${TARGET_DIR}${NC}"
  exit 1
fi

print_banner
echo -e "${CYAN}Ambiente selecionado:${NC} ${GREEN}${ENV}${NC}"
echo -e "${CYAN}Comando:${NC}              ${GREEN}${COMMAND}${NC}"
echo -e "${CYAN}Diretório de trabalho:${NC} ${TARGET_DIR}"
echo ""

cd "$TARGET_DIR"

case "$COMMAND" in
  validate)
    echo -e "${BLUE}▶ Executando terraform init e validate...${NC}"
    terraform init -backend=false
    terraform validate
    echo -e "${GREEN}✅ Validação concluída com sucesso!${NC}"
    ;;

  plan)
    check_credentials
    echo -e "${BLUE}▶ Inicializando módulos e gerando plano...${NC}"
    terraform init
    terraform plan "${@:3}"
    ;;

  up)
    check_credentials
    echo -e "${BLUE}▶ Provisionando infraestrutura (${ENV})...${NC}"
    terraform init
    terraform apply -auto-approve "${@:3}"
    echo ""
    echo -e "${GREEN}🎉 Ambiente ${ENV} provisionado com sucesso!${NC}"
    terraform output
    ;;

  down)
    check_credentials
    echo -e "${RED}⚠️  ATENÇÃO: Você está prestes a DESTRUIR todos os recursos do ambiente ${ENV}!${NC}"
    read -r -p "Tem certeza que deseja continuar? (s/N): " confirm
    if [[ "$confirm" =~ ^[sS]$ ]]; then
      terraform init
      terraform destroy -auto-approve "${@:3}"
      echo -e "${GREEN}🧹 Recursos destruídos com sucesso. Conta limpa!${NC}"
    else
      echo -e "${YELLOW}Operação cancelada pelo usuário.${NC}"
    fi
    ;;

  outputs)
    echo -e "${BLUE}▶ Saídas do ambiente ${ENV}:${NC}"
    terraform output
    ;;

  *)
    usage
    ;;
esac
