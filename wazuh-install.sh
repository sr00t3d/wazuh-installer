#!/usr/bin/env bash
# ==============================================================================
# Wazuh Installer — Automated Single-Node Server & Agent Setup Script
# Author: Percio Castelo (sr00t3d)
# Version: 1.2.0
# Description: Automates the deployment of a Wazuh Single-Node Server via Docker,
#              configures certificates, opens firewall ports, and installs
#              and optimizes the Wazuh Agent for Debian/RHEL systems.
# GitHub:  https://github.com/sr00t3d/wazuh-install
# License: MIT
# ==============================================================================

set -eo pipefail

# ─── Versioning ───────────────────────────────────────────────────────────────
SCRIPT_VERSION="1.2.0"
WAZUH_VERSION="${WAZUH_VERSION:-4.14.3}"
LOG_FILE="/var/log/wazuh-install.log"

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Logging ──────────────────────────────────────────────────────────────────
_log_to_file() {
    local level="$1"; shift
    printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$(printf '%s' "$*")" >> "$LOG_FILE" 2>/dev/null || true
}
log_info() {
    local fmt=$1; shift
    printf "${BLUE}[INFO]${NC} $fmt\n" "$@"
    _log_to_file "INFO" "$(printf "$fmt" "$@")"
}
log_success() {
    local fmt=$1; shift
    printf "${GREEN}[SUCCESS]${NC} $fmt\n" "$@"
    _log_to_file "SUCCESS" "$(printf "$fmt" "$@")"
}
log_warning() {
    local fmt=$1; shift
    printf "${YELLOW}[WARNING]${NC} $fmt\n" "$@"
    _log_to_file "WARNING" "$(printf "$fmt" "$@")"
}
log_error() {
    local fmt=$1; shift
    printf "${RED}[ERROR]${NC} $fmt\n" "$@"
    _log_to_file "ERROR" "$(printf "$fmt" "$@")"
}

# ─── Unattended mode defaults (override via environment variables) ─────────────
UNATTENDED=false
WAZUH_MODE="${WAZUH_MODE:-}"                      # server | agent
WAZUH_ADMIN_PASS="${WAZUH_ADMIN_PASS:-}"          # Server: admin password (empty = auto-generate)
WAZUH_MANAGER_IP="${WAZUH_MANAGER_IP:-}"          # Agent: Wazuh Manager IP/hostname
WAZUH_AGENT_NAME="${WAZUH_AGENT_NAME:-}"          # Agent: name for this agent
WAZUH_AGENT_GROUP="${WAZUH_AGENT_GROUP:-default}" # Agent: group for this agent
WAZUH_MEM_OPT="${WAZUH_MEM_OPT:-3}"              # Agent: 1=swap 2=zram 3=none
WAZUH_FORCE_RAM="${WAZUH_FORCE_RAM:-false}"       # Server: skip low-RAM check

# ─── Language detection ────────────────────────────────────────────────────────
LANG_PREF="en"
if [[ "${LANG:-}" =~ "pt" ]] || [[ "${LANGUAGE:-}" =~ "pt" ]] || [[ "${LC_ALL:-}" =~ "pt" ]]; then
    LANG_PREF="pt"
fi

# ─── Help (shown before i18n is loaded — always in English) ──────────────────
show_help() {
    printf "${YELLOW}"
    echo "██╗    ██╗ █████╗ ███████╗██╗   ██╗██╗  ██╗"
    echo "██║    ██║██╔══██╗╚══███╔╝██║   ██║██║  ██║"
    echo "██║ █╗ ██║███████║  ███╔╝ ██║   ██║███████║"
    echo "██║███╗██║██╔══██║ ███╔╝  ██║   ██║██╔══██║"
    echo "╚███╔███╔╝██║  ██║███████╗╚██████╔╝██║  ██║"
    echo " ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝"
    printf "${NC}"
    cat <<EOF

${BOLD}Wazuh Automated Installer v${SCRIPT_VERSION}${NC} — Wazuh ${WAZUH_VERSION}
Author  : Percio Castelo (sr00t3d) — https://perciocastelo.com.br
GitHub  : https://github.com/sr00t3d/wazuh-install
License : MIT

${BOLD}USAGE:${NC}
  sudo ./wazuh-install.sh [OPTIONS]
  curl -sSL https://perciocastelo.com.br/assets/downloads/wazuh-install.sh | sudo bash -s -- [OPTIONS]

${BOLD}OPTIONS:${NC}
  --lang=pt|en      Force UI language (default: auto-detect from locale)
  --unattended      Non-interactive mode — reads config from environment variables
  --version         Show script and Wazuh target version, then exit
  --help, -h        Show this help message and exit

${BOLD}UNATTENDED MODE — ENVIRONMENT VARIABLES:${NC}
  WAZUH_MODE          (Required) 'server' or 'agent'
  WAZUH_VERSION       Target Wazuh version (default: ${WAZUH_VERSION})
  WAZUH_ADMIN_PASS    [Server] Admin password (min 8 chars). Empty = auto-generate.
  WAZUH_FORCE_RAM     [Server] Set 'true' to skip low-RAM safety check.
  WAZUH_MANAGER_IP    [Agent]  IP or domain of the Wazuh Manager (required)
  WAZUH_AGENT_NAME    [Agent]  Name for this agent (default: hostname)
  WAZUH_AGENT_GROUP   [Agent]  Group for this agent (default: 'default')
  WAZUH_MEM_OPT       [Agent]  Memory option: 1=swap 2=zram 3=none (default: 3)

${BOLD}EXAMPLES:${NC}
  # Interactive menu (default):
  sudo ./wazuh-install.sh

  # Force English UI:
  sudo ./wazuh-install.sh --lang=en

  # Unattended server install (auto-generated admin password):
  sudo WAZUH_MODE=server ./wazuh-install.sh --unattended

  # Unattended server install with custom password:
  sudo WAZUH_MODE=server WAZUH_ADMIN_PASS='Str0ngP@ss!' ./wazuh-install.sh --unattended

  # Unattended agent install with 2GB swap:
  sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.10 WAZUH_AGENT_NAME=webserver01 WAZUH_MEM_OPT=1 ./wazuh-install.sh --unattended

  # Via curl, unattended agent:
  curl -sSL https://perciocastelo.com.br/assets/downloads/wazuh-install.sh | \\
    sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.10 bash -s -- --unattended

${BOLD}LOG FILE:${NC}
  All output is also saved to: ${LOG_FILE}

EOF
    exit 0
}

# ─── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --lang=pt|--lang-pt)  LANG_PREF="pt" ;;
        --lang=en|--lang-en)  LANG_PREF="en" ;;
        --unattended)         UNATTENDED=true ;;
        --version)
            echo "wazuh-install.sh v${SCRIPT_VERSION} (Wazuh target: ${WAZUH_VERSION})"
            exit 0
            ;;
        --help|-h) show_help ;;
    esac
done

# ─── Internationalization Dictionary ──────────────────────────────────────────
if [ "$LANG_PREF" = "pt" ]; then
    MSG_ERR_ROOT="Este script precisa ser executado como root (sudo)."
    MSG_CHECK_DEPS="Verificando dependências básicas..."
    MSG_CURL_MISSING="curl não está instalado. Instalando..."
    MSG_CURL_FAIL="Não foi possível instalar o curl automaticamente."
    MSG_CURL_OK="curl instalado com sucesso."
    MSG_DOCKER_CHECK="Verificando se Docker está instalado..."
    MSG_DOCKER_MISSING="Docker não detectado. Iniciando instalação..."
    MSG_DOCKER_UNSUPPORTED="SO não suportado para instalação automática do Docker."
    MSG_DOCKER_OK="Docker instalado e ativado com sucesso."
    MSG_DOCKER_EXIST="Docker já está instalado: %s"
    MSG_COMPOSE_CHECK="Verificando se Docker Compose está instalado..."
    MSG_COMPOSE_MISSING="Docker Compose não detectado. Instalando plugin..."
    MSG_COMPOSE_FAIL="Não foi possível instalar o Docker Compose automaticamente."
    MSG_COMPOSE_OK="Docker Compose plugin instalado com sucesso."
    MSG_COMPOSE_EXIST="Docker Compose está disponível."
    MSG_FW_DETECTED="Detectado firewall ativo: %s"
    MSG_FW_SERVER_CFG="Configurando regras de entrada no firewall para o Servidor Wazuh..."
    MSG_FW_UFW_SERVER_OK="Portas liberadas no UFW: 1514/tcp, 1515/tcp, 514/udp, 55000/tcp, 4443/tcp."
    MSG_FW_FIREWALLD_SERVER_OK="Portas liberadas no Firewalld: 1514/tcp, 1515/tcp, 514/udp, 55000/tcp, 4443/tcp."
    MSG_FW_IPTABLES_SERVER_OK="Portas configuradas no iptables."
    MSG_FW_NONE_WARNING="Nenhum firewall gerenciado ativo. Certifique-se de liberar manualmente:"
    MSG_FW_AGENT_CFG="Configurando regras de saída/conexão para o Manager (%s)..."
    MSG_FW_UFW_AGENT_OK="Conexões de saída para o Manager liberadas no UFW."
    MSG_FW_FIREWALLD_AGENT_OK="Regras de saída para o Manager configuradas no Firewalld."
    MSG_FW_IPTABLES_AGENT_OK="Regras de saída para o Manager configuradas no iptables."
    MSG_FW_AGENT_NONE="Firewall de saída irrestrito ou não detectado. Certifique-se de que a comunicação para %s nas portas TCP 1514, 1515, 55000 está permitida."
    MSG_SWAP_CONFIG="Configurando Swap de 2GB..."
    MSG_SWAP_EXIST="Arquivo /swapfile já existe. Ativando se estiver desligado."
    MSG_SWAP_OK="Swap de 2GB criado e adicionado ao /etc/fstab."
    MSG_ZRAM_CONFIG="Configurando ZRAM..."
    MSG_ZRAM_DEB_OK="ZRAM instalado e ativado com sucesso via zram-config."
    MSG_ZRAM_RHEL_OK="ZRAM de 2GB ativado temporariamente em /dev/zram0."
    MSG_ZRAM_FAIL="Não foi possível habilitar ZRAM. Configurando swapfile padrão como fallback."
    MSG_ZRAM_UNSUPPORTED="SO não suporta ZRAM automatizado neste script. Configurando swapfile como fallback."
    MSG_SERVER_START="Iniciando fluxo de instalação do Servidor Wazuh..."
    MSG_RAM_DETECTED="Memória RAM total detectada: %sMB"
    MSG_RAM_WARNING_1="O Servidor Wazuh (especialmente o Indexer) necessita de pelo menos 4GB de RAM para funcionar de forma estável."
    MSG_RAM_WARNING_2="Este sistema possui apenas %sMB de RAM disponível."
    MSG_RAM_FORCE_PROMPT="Deseja forçar a instalação mesmo assim? [s/N]: "
    MSG_SERVER_ABORT_RAM="Instalação do Servidor abortada pelo usuário devido aos limites de hardware."
    MSG_RAM_DOUBLE_CONFIRM="Realmente deseja instalar neste sistema com pouca memoria? [s/N]: "
    MSG_SERVER_ABORT_DOUBLE="Instalação do Servidor abortada pelo usuário na dupla confirmação."
    MSG_SERVER_PROCEED_LOW_RAM="Prosseguindo com a instalação sob o risco de falhas por falta de memória (OOM)."
    MSG_IP_FALLBACK="IP_DO_SERVIDOR"
    MSG_CURL_CONN_ERR="Erro de Conexão"
    MSG_GIT_MISSING="git não detectado. Instalando..."
    MSG_GIT_FAIL="Por favor, instale o git manualmente antes de continuar."
    MSG_GIT_OK="git instalado com sucesso."
    MSG_VM_MAX_MAP_CONFIG="Configurando limite de memória vm.max_map_count..."
    MSG_VM_MAX_MAP_OK="Kernel tuning vm.max_map_count=262144 configurado persistentemente."
    MSG_SERVER_DIR_PREP="Preparando diretório de trabalho em: %s"
    MSG_SERVER_DIR_EXIST="O diretório %s/wazuh-docker já existe."
    MSG_SERVER_CLEAN_PROMPT="Deseja remover e clonar uma versão limpa? [s/N]: "
    MSG_SERVER_STOPPING_EXISTING="Parando instâncias existentes..."
    MSG_SERVER_REPO_ERR="Erro ao obter o repositório wazuh-docker."
    MSG_SEC_HEADER="--- Configuração de Segurança (Wazuh Admin) ---"
    MSG_SEC_INFO_1="Por questões de segurança, você deve definir uma senha personalizada para o usuário 'admin'."
    MSG_SEC_INFO_2="Pressione [ENTER] sem digitar nada para gerar uma senha aleatória forte."
    MSG_SEC_PASS_PROMPT="Senha do admin (mínimo 8 caracteres): "
    MSG_SEC_PASS_GEN="Gerada senha aleatória forte: %s"
    MSG_SEC_PASS_MIN="A senha deve conter pelo menos 8 caracteres. Tente novamente."
    MSG_HASH_START="Gerando hash BCrypt da senha de administrador (usando container indexer)..."
    MSG_HASH_ERR="Erro ao gerar o hash da senha de administrador. Abortando."
    MSG_HASH_OK="Hash da senha gerado com sucesso."
    MSG_CFG_WRITE_START="Gravando nova senha e hash nos arquivos de configuração..."
    MSG_CFG_WRITE_OK="Arquivos de configuração atualizados com a nova senha."
    MSG_CERTS_START="Gerando certificados para indexer, dashboard e server..."
    MSG_CERTS_OK="Certificados gerados com sucesso."
    MSG_PORT_CHANGE_START="Alterando porta padrão do Dashboard HTTPS para 4443 no docker-compose.yml..."
    MSG_PORT_CHANGE_OK="Configuração de portas atualizada."
    MSG_STACK_START="Subindo a stack do Wazuh via Docker Compose..."
    MSG_STACK_OK="Serviços iniciados no Docker."
    MSG_SERVER_BANNER_OK="Servidor Wazuh Single-Node Iniciado com Sucesso!"
    MSG_SERVER_URL="Acesse o Painel Web: https://%s:4443"
    MSG_SERVER_USER="Usuário padrão: admin"
    MSG_SERVER_PASS="Senha configurada: %s"
    MSG_AGENT_START="Iniciando fluxo de instalação do Agente Wazuh..."
    MSG_AGENT_MANAGER_PROMPT="Digite o IP ou Domínio do Manager (Servidor Wazuh): "
    MSG_AGENT_MANAGER_ERR="O IP/Domínio do Manager é obrigatório."
    MSG_AGENT_NAME_PROMPT="Digite o nome para este Agente (padrão: %s): "
    MSG_AGENT_GROUP_PROMPT="Digite o grupo para este Agente (padrão: default): "
    MSG_MEM_OPT_HEADER="--- Otimização de Memória ---"
    MSG_MEM_OPT_DETECT="Detecção: Já existe Swap/ZRAM ativo no sistema:"
    MSG_MEM_OPT_RECOMMEND="Para evitar configurações duplicadas, recomenda-se manter a configuração atual (Opção 3)."
    MSG_MEM_OPT_NONE="Detecção: Nenhum Swap/ZRAM ativo detectado."
    MSG_MEM_OPT_QUESTION="Deseja configurar Swap ou ZRAM para ajudar na estabilidade (essencial para VMs com <2GB RAM)?"
    MSG_MEM_OPT_OPT1="1) Criar Swapfile de 2GB (Recomendado/Estável)"
    MSG_MEM_OPT_OPT2="2) Configurar ZRAM de 2GB"
    MSG_MEM_OPT_OPT3="3) Manter configuração atual (Sem alterações)"
    MSG_MEM_OPT_PROMPT="Escolha uma opção [1-3, padrão: 3]: "
    MSG_MEM_OPT_NO_CHANGE="Nenhuma alteração na memória virtual."
    MSG_OVERCOMMIT_SET="Ajustando vm.overcommit_memory para 1 (Instalação)..."
    MSG_AGENT_DEB_PREP="Preparando download do pacote DEB..."
    MSG_ARCH_UNSUPPORTED="Arquitetura %s não suportada."
    MSG_AGENT_DEB_DOWN="Baixando pacote Debian de %s..."
    MSG_AGENT_INSTALL_START="Instalando pacote e registrando no Manager..."
    MSG_AGENT_RPM_PREP="Preparando download do pacote RPM..."
    MSG_AGENT_RPM_DOWN="Baixando pacote RPM de %s..."
    MSG_AGENT_OS_UNSUPPORTED="SO não suportado para a instalação automatizada do agente."
    MSG_AGENT_OSSEC_CONF_CFG="Ajustando endereço do Manager no arquivo ossec.conf..."
    MSG_AGENT_SERVICE_START="Ativando e iniciando o serviço wazuh-agent..."
    MSG_OVERCOMMIT_RESET="Revertendo vm.overcommit_memory para 0..."
    MSG_AGENT_BANNER_OK="Agente Wazuh Instalado e Configurado com Sucesso!"
    MSG_AGENT_BANNER_INFO="O agente '%s' está ativo e tentando se conectar com o Manager em %s."
    MSG_HEALTH_START="Verificando Saúde/Status do Wazuh neste sistema..."
    MSG_HEALTH_SERVER_HEADER="--- Status dos Containers do Servidor Wazuh ---"
    MSG_HEALTH_DASHBOARD_HEADER="--- Teste de Acesso ao Dashboard ---"
    MSG_HEALTH_DASHBOARD_OK="Painel Web respondendo em https://localhost:4443 (HTTP %s)"
    MSG_HEALTH_DASHBOARD_ERR="Painel Web não respondeu como esperado na porta 4443 (Código HTTP: %s)"
    MSG_HEALTH_AGENT_HEADER="--- Status do Agente Wazuh (Serviço) ---"
    MSG_HEALTH_AGENT_ACTIVE="Serviço wazuh-agent está EM EXECUÇÃO (active)."
    MSG_HEALTH_AGENT_INACTIVE="Serviço wazuh-agent está PARADO (inactive)."
    MSG_HEALTH_AGENT_MANAGER="Manager configurado no ossec.conf: %s"
    MSG_HEALTH_AGENT_LOGS_HEADER="--- Status de Conexão do Agente (Logs Recentes) ---"
    MSG_HEALTH_AGENT_NO_LOGS="Nenhuma mensagem de conexão detectada. Últimas 10 linhas do log:"
    MSG_HEALTH_NONE_DETECTED="Nenhuma instalação de Servidor (Docker) ou Agente Wazuh foi detectada neste sistema."
    MSG_ENTER_BACK="Pressione [ENTER] para voltar ao menu principal..."
    MSG_UN_SERVER_WARN="[ATENÇÃO] Isso removerá completamente a stack Docker do Wazuh, incluindo todos os dados do indexer!"
    MSG_UN_CONFIRM_PROMPT="Tem certeza que deseja continuar? [y/N]: "
    MSG_UN_CANCELLED="Desinstalação cancelada."
    MSG_UN_SERVER_STOPPING="Parando e deletando containers/volumes do Wazuh..."
    MSG_UN_SERVER_DIR_REM="Removendo diretório de trabalho /opt/docker/wazuh..."
    MSG_UN_SERVER_FW_CLEAN="Limpando regras de firewall abertas para o Servidor..."
    MSG_UN_SERVER_FW_UFW="Portas removidas do UFW."
    MSG_UN_SERVER_FW_FIREWALLD="Portas removidas do Firewalld."
    MSG_UN_SERVER_OK="Servidor Wazuh desinstalado com sucesso."
    MSG_UN_AGENT_CONFIRM_PROMPT="Tem certeza que deseja desinstalar o Agente Wazuh? [y/N]: "
    MSG_UN_AGENT_STOPPING="Parando e desativando o serviço wazuh-agent..."
    MSG_UN_AGENT_PKG_REM="Removendo o pacote wazuh-agent..."
    MSG_UN_AGENT_DIR_REM="Removendo arquivos residuais em /var/ossec..."
    MSG_UN_AGENT_SWAP_PROMPT="Detectado /swapfile. Deseja removê-lo completamente do sistema? [y/N]: "
    MSG_UN_AGENT_SWAP_STOPPING="Desabilitando e removendo arquivo swap..."
    MSG_UN_AGENT_SWAP_OK="Swapfile removido."
    MSG_UN_AGENT_OK="Agente Wazuh desinstalado com sucesso (regras de firewall de saída específicas devem ser removidas manualmente se aplicável)."
    MSG_UN_FLOW_HEADER="Desinstalação do Wazuh — Escolha a Opção"
    MSG_UN_FLOW_OPT1="1) Desinstalar Servidor Wazuh (Single-Node Docker)"
    MSG_UN_FLOW_OPT2="2) Desinstalar Agente Wazuh"
    MSG_UN_FLOW_OPT3="3) Voltar ao menu principal"
    MSG_UN_FLOW_PROMPT="Escolha uma opção [1-3]: "
    MSG_ENTER_CONTINUE="Pressione [ENTER] para continuar..."
    MSG_MENU_HEADER="   Script de Instalação e Configuração — Wazuh"
    MSG_MENU_AUTHOR="   Desenvolvido por: Percio Castelo (sr00t3d) - https://perciocastelo.com.br"
    MSG_MENU_OPT1="1) Instalar Servidor Wazuh (Single-Node via Docker)"
    MSG_MENU_OPT2="2) Instalar Agente Wazuh"
    MSG_MENU_OPT3="3) Verificar Saúde/Status (Server ou Agent)"
    MSG_MENU_OPT4="4) Desinstalar Servidor ou Agente Wazuh"
    MSG_MENU_OPT5="5) Sair"
    MSG_MENU_PROMPT="Escolha uma opção [1-5]: "
    MSG_EXIT="Encerrando script."
    MSG_INVALID_OPT="Opção inválida!"
    # Novos: preflight, unattended, log
    MSG_LOG_INIT="Log de instalação iniciado em: %s"
    MSG_UNATTENDED_ON="Modo não-interativo ativado. Lendo configurações das variáveis de ambiente."
    MSG_UNATTENDED_MODE_ERR="WAZUH_MODE deve ser 'server' ou 'agent' no modo não-interativo. Use --help para ver exemplos."
    MSG_UNATTENDED_MANAGER_ERR="WAZUH_MANAGER_IP é obrigatório no modo não-interativo para instalação do agente."
    MSG_UNATTENDED_PASS_GEN="Nenhuma senha fornecida. Gerando senha aleatória forte automaticamente..."
    MSG_UNATTENDED_SKIP_CLEAN="Diretório wazuh-docker existente encontrado. Modo não-interativo: mantendo versão atual."
    MSG_UNATTENDED_FORCE_RAM="Verificação de RAM ignorada (WAZUH_FORCE_RAM=true)."
    MSG_UNATTENDED_MEM_OPT="Opção de memória aplicada automaticamente (WAZUH_MEM_OPT=%s)."
    MSG_PREFLIGHT_START="Executando verificações de pré-instalação (pre-flight checks)..."
    MSG_PREFLIGHT_DISK_OK="Espaço em disco disponível: %sMB — OK."
    MSG_PREFLIGHT_DISK_WARN="Pouco espaço em disco: %sMB disponível. Mínimo recomendado: 10240MB para o servidor."
    MSG_PREFLIGHT_DISK_FAIL="Espaço em disco insuficiente: apenas %sMB disponível. Mínimo absoluto: 500MB."
    MSG_PREFLIGHT_PORT_BUSY="As seguintes portas já estão em uso neste sistema (pode causar conflitos):%s"
    MSG_PREFLIGHT_OK="Pré-verificações concluídas com sucesso."
    MSG_TRAP_ERR="Erro inesperado na linha %s. Consulte o log completo em: %s"
    MSG_LOG_FILE_HINT="Log completo disponível em: %s"
else
    MSG_ERR_ROOT="This script must be run as root (sudo)."
    MSG_CHECK_DEPS="Checking basic dependencies..."
    MSG_CURL_MISSING="curl is not installed. Installing..."
    MSG_CURL_FAIL="Could not install curl automatically."
    MSG_CURL_OK="curl installed successfully."
    MSG_DOCKER_CHECK="Checking if Docker is installed..."
    MSG_DOCKER_MISSING="Docker not detected. Starting installation..."
    MSG_DOCKER_UNSUPPORTED="OS not supported for automatic Docker installation."
    MSG_DOCKER_OK="Docker successfully installed and enabled."
    MSG_DOCKER_EXIST="Docker is already installed: %s"
    MSG_COMPOSE_CHECK="Checking if Docker Compose is installed..."
    MSG_COMPOSE_MISSING="Docker Compose not detected. Installing plugin..."
    MSG_COMPOSE_FAIL="Could not install Docker Compose automatically."
    MSG_COMPOSE_OK="Docker Compose plugin installed successfully."
    MSG_COMPOSE_EXIST="Docker Compose is available."
    MSG_FW_DETECTED="Active firewall detected: %s"
    MSG_FW_SERVER_CFG="Configuring inbound firewall rules for Wazuh Server..."
    MSG_FW_UFW_SERVER_OK="Ports opened in UFW: 1514/tcp, 1515/tcp, 514/udp, 55000/tcp, 4443/tcp."
    MSG_FW_FIREWALLD_SERVER_OK="Ports opened in Firewalld: 1514/tcp, 1515/tcp, 514/udp, 55000/tcp, 4443/tcp."
    MSG_FW_IPTABLES_SERVER_OK="Ports configured in iptables."
    MSG_FW_NONE_WARNING="No active managed firewall. Make sure to manually open:"
    MSG_FW_AGENT_CFG="Configuring outbound/connection rules for Manager (%s)..."
    MSG_FW_UFW_AGENT_OK="Outbound connections to Manager allowed in UFW."
    MSG_FW_FIREWALLD_AGENT_OK="Outbound rules to Manager configured in Firewalld."
    MSG_FW_IPTABLES_AGENT_OK="Outbound rules to Manager configured in iptables."
    MSG_FW_AGENT_NONE="Outbound firewall unrestricted or not detected. Make sure communication to %s on TCP ports 1514, 1515, 55000 is allowed."
    MSG_SWAP_CONFIG="Configuring 2GB Swap..."
    MSG_SWAP_EXIST="/swapfile already exists. Activating if disabled."
    MSG_SWAP_OK="2GB Swap created and added to /etc/fstab."
    MSG_ZRAM_CONFIG="Configuring ZRAM..."
    MSG_ZRAM_DEB_OK="ZRAM successfully installed and enabled via zram-config."
    MSG_ZRAM_RHEL_OK="2GB ZRAM temporarily enabled at /dev/zram0."
    MSG_ZRAM_FAIL="Could not enable ZRAM. Configuring default swapfile as fallback."
    MSG_ZRAM_UNSUPPORTED="OS does not support automated ZRAM in this script. Configuring swapfile as fallback."
    MSG_SERVER_START="Starting Wazuh Server installation flow..."
    MSG_RAM_DETECTED="Total RAM memory detected: %sMB"
    MSG_RAM_WARNING_1="Wazuh Server (especially the Indexer) requires at least 4GB of RAM to run stably."
    MSG_RAM_WARNING_2="This system only has %sMB of RAM available."
    MSG_RAM_FORCE_PROMPT="Do you want to force installation anyway? [y/N]: "
    MSG_SERVER_ABORT_RAM="Server installation aborted by user due to hardware limits."
    MSG_RAM_DOUBLE_CONFIRM="Do you really want to install on this system with low memory? [y/N]: "
    MSG_SERVER_ABORT_DOUBLE="Server installation aborted by user on double confirmation."
    MSG_SERVER_PROCEED_LOW_RAM="Proceeding with installation under risk of Out-Of-Memory (OOM) failures."
    MSG_IP_FALLBACK="SERVER_IP"
    MSG_CURL_CONN_ERR="Connection Error"
    MSG_GIT_MISSING="git not detected. Installing..."
    MSG_GIT_FAIL="Please install git manually before continuing."
    MSG_GIT_OK="git installed successfully."
    MSG_VM_MAX_MAP_CONFIG="Configuring vm.max_map_count memory limit..."
    MSG_VM_MAX_MAP_OK="Kernel tuning vm.max_map_count=262144 configured persistently."
    MSG_SERVER_DIR_PREP="Preparing working directory at: %s"
    MSG_SERVER_DIR_EXIST="The directory %s/wazuh-docker already exists."
    MSG_SERVER_CLEAN_PROMPT="Do you want to remove it and clone a clean version? [y/N]: "
    MSG_SERVER_STOPPING_EXISTING="Stopping existing instances..."
    MSG_SERVER_REPO_ERR="Error cloning wazuh-docker repository."
    MSG_SEC_HEADER="--- Security Configuration (Wazuh Admin) ---"
    MSG_SEC_INFO_1="For security reasons, you must define a custom password for the 'admin' user."
    MSG_SEC_INFO_2="Press [ENTER] without typing anything to generate a strong random password."
    MSG_SEC_PASS_PROMPT="Admin password (minimum 8 characters): "
    MSG_SEC_PASS_GEN="Generated strong random password: %s"
    MSG_SEC_PASS_MIN="Password must be at least 8 characters long. Try again."
    MSG_HASH_START="Generating BCrypt hash for admin password (using indexer container)..."
    MSG_HASH_ERR="Error generating admin password hash. Aborting."
    MSG_HASH_OK="Password hash generated successfully."
    MSG_CFG_WRITE_START="Saving new password and hash to configuration files..."
    MSG_CFG_WRITE_OK="Configuration files updated with the new password."
    MSG_CERTS_START="Generating certificates for indexer, dashboard, and server..."
    MSG_CERTS_OK="Certificates generated successfully."
    MSG_PORT_CHANGE_START="Changing default Dashboard HTTPS port to 4443 in docker-compose.yml..."
    MSG_PORT_CHANGE_OK="Port configuration updated."
    MSG_STACK_START="Starting Wazuh stack via Docker Compose..."
    MSG_STACK_OK="Services started in Docker."
    MSG_SERVER_BANNER_OK="Wazuh Single-Node Server Started Successfully!"
    MSG_SERVER_URL="Access the Web Dashboard: https://%s:4443"
    MSG_SERVER_USER="Default username: admin"
    MSG_SERVER_PASS="Configured password: %s"
    MSG_AGENT_START="Starting Wazuh Agent installation flow..."
    MSG_AGENT_MANAGER_PROMPT="Enter Manager IP or Domain (Wazuh Server): "
    MSG_AGENT_MANAGER_ERR="Manager IP/Domain is required."
    MSG_AGENT_NAME_PROMPT="Enter a name for this Agent (default: %s): "
    MSG_AGENT_GROUP_PROMPT="Enter a group for this Agent (default: default): "
    MSG_MEM_OPT_HEADER="--- Memory Optimization ---"
    MSG_MEM_OPT_DETECT="Detection: Active Swap/ZRAM already exists on system:"
    MSG_MEM_OPT_RECOMMEND="To avoid duplicate settings, keeping current configuration is recommended (Option 3)."
    MSG_MEM_OPT_NONE="Detection: No active Swap/ZRAM detected."
    MSG_MEM_OPT_QUESTION="Do you want to configure Swap or ZRAM to help stability (essential for VMs with <2GB RAM)?"
    MSG_MEM_OPT_OPT1="1) Create 2GB Swapfile (Recommended/Stable)"
    MSG_MEM_OPT_OPT2="2) Configure 2GB ZRAM"
    MSG_MEM_OPT_OPT3="3) Keep current configuration (No changes)"
    MSG_MEM_OPT_PROMPT="Choose an option [1-3, default: 3]: "
    MSG_MEM_OPT_NO_CHANGE="No changes to virtual memory."
    MSG_OVERCOMMIT_SET="Setting vm.overcommit_memory to 1 (Installation)..."
    MSG_AGENT_DEB_PREP="Preparing DEB package download..."
    MSG_ARCH_UNSUPPORTED="Architecture %s is not supported."
    MSG_AGENT_DEB_DOWN="Downloading Debian package from %s..."
    MSG_AGENT_INSTALL_START="Installing package and registering with Manager..."
    MSG_AGENT_RPM_PREP="Preparing RPM package download..."
    MSG_AGENT_RPM_DOWN="Downloading RPM package from %s..."
    MSG_AGENT_OS_UNSUPPORTED="OS not supported for automated agent installation."
    MSG_AGENT_OSSEC_CONF_CFG="Adjusting Manager address in ossec.conf..."
    MSG_AGENT_SERVICE_START="Enabling and starting wazuh-agent service..."
    MSG_OVERCOMMIT_RESET="Reverting vm.overcommit_memory to 0..."
    MSG_AGENT_BANNER_OK="Wazuh Agent Installed and Configured Successfully!"
    MSG_AGENT_BANNER_INFO="Agent '%s' is active and trying to connect to Manager at %s."
    MSG_HEALTH_START="Checking Wazuh Health/Status on this system..."
    MSG_HEALTH_SERVER_HEADER="--- Wazuh Server Container Status ---"
    MSG_HEALTH_DASHBOARD_HEADER="--- Dashboard Access Test ---"
    MSG_HEALTH_DASHBOARD_OK="Web Dashboard responding at https://localhost:4443 (HTTP %s)"
    MSG_HEALTH_DASHBOARD_ERR="Web Dashboard did not respond as expected on port 4443 (HTTP Code: %s)"
    MSG_HEALTH_AGENT_HEADER="--- Wazuh Agent Status (Service) ---"
    MSG_HEALTH_AGENT_ACTIVE="wazuh-agent service is RUNNING (active)."
    MSG_HEALTH_AGENT_INACTIVE="wazuh-agent service is STOPPED (inactive)."
    MSG_HEALTH_AGENT_MANAGER="Configured Manager in ossec.conf: %s"
    MSG_HEALTH_AGENT_LOGS_HEADER="--- Agent Connection Status (Recent Logs) ---"
    MSG_HEALTH_AGENT_NO_LOGS="No connection message detected. Last 10 log lines:"
    MSG_HEALTH_NONE_DETECTED="No Wazuh Server (Docker) or Agent installation detected on this system."
    MSG_ENTER_BACK="Press [ENTER] to return to the main menu..."
    MSG_UN_SERVER_WARN="[WARNING] This will completely remove the Wazuh Docker stack, including all indexer data!"
    MSG_UN_CONFIRM_PROMPT="Are you sure you want to continue? [y/N]: "
    MSG_UN_CANCELLED="Uninstall cancelled."
    MSG_UN_SERVER_STOPPING="Stopping and deleting Wazuh containers/volumes..."
    MSG_UN_SERVER_DIR_REM="Removing working directory /opt/docker/wazuh..."
    MSG_UN_SERVER_FW_CLEAN="Cleaning firewall rules opened for the Server..."
    MSG_UN_SERVER_FW_UFW="Ports removed from UFW."
    MSG_UN_SERVER_FW_FIREWALLD="Ports removed from Firewalld."
    MSG_UN_SERVER_OK="Wazuh Server uninstalled successfully."
    MSG_UN_AGENT_CONFIRM_PROMPT="Are you sure you want to uninstall Wazuh Agent? [y/N]: "
    MSG_UN_AGENT_STOPPING="Stopping and disabling wazuh-agent service..."
    MSG_UN_AGENT_PKG_REM="Removing wazuh-agent package..."
    MSG_UN_AGENT_DIR_REM="Removing residual files in /var/ossec..."
    MSG_UN_AGENT_SWAP_PROMPT="Detected /swapfile. Do you want to remove it completely from the system? [y/N]: "
    MSG_UN_AGENT_SWAP_STOPPING="Disabling and removing swap file..."
    MSG_UN_AGENT_SWAP_OK="Swapfile removed."
    MSG_UN_AGENT_OK="Wazuh Agent uninstalled successfully (specific outbound firewall rules must be removed manually if applicable)."
    MSG_UN_FLOW_HEADER="Wazuh Uninstallation — Choose Option"
    MSG_UN_FLOW_OPT1="1) Uninstall Wazuh Server (Single-Node Docker)"
    MSG_UN_FLOW_OPT2="2) Uninstall Wazuh Agent"
    MSG_UN_FLOW_OPT3="3) Back to main menu"
    MSG_UN_FLOW_PROMPT="Choose an option [1-3]: "
    MSG_ENTER_CONTINUE="Press [ENTER] to continue..."
    MSG_MENU_HEADER="   Installation and Configuration Script — Wazuh"
    MSG_MENU_AUTHOR="   Developed by: Percio Castelo (sr00t3d) - https://perciocastelo.com.br"
    MSG_MENU_OPT1="1) Install Wazuh Server (Single-Node via Docker)"
    MSG_MENU_OPT2="2) Install Wazuh Agent"
    MSG_MENU_OPT3="3) Check Health/Status (Server or Agent)"
    MSG_MENU_OPT4="4) Uninstall Server or Agent"
    MSG_MENU_OPT5="5) Exit"
    MSG_MENU_PROMPT="Choose an option [1-5]: "
    MSG_EXIT="Exiting script."
    MSG_INVALID_OPT="Invalid option!"
    # New: preflight, unattended, log
    MSG_LOG_INIT="Install log session started at: %s"
    MSG_UNATTENDED_ON="Unattended mode enabled. Reading configuration from environment variables."
    MSG_UNATTENDED_MODE_ERR="WAZUH_MODE must be 'server' or 'agent' in unattended mode. Use --help for examples."
    MSG_UNATTENDED_MANAGER_ERR="WAZUH_MANAGER_IP is required in unattended mode for agent installation."
    MSG_UNATTENDED_PASS_GEN="No password provided. Generating strong random password automatically..."
    MSG_UNATTENDED_SKIP_CLEAN="Existing wazuh-docker directory found. Unattended mode: keeping current version."
    MSG_UNATTENDED_FORCE_RAM="RAM check skipped (WAZUH_FORCE_RAM=true)."
    MSG_UNATTENDED_MEM_OPT="Memory option applied automatically (WAZUH_MEM_OPT=%s)."
    MSG_PREFLIGHT_START="Running pre-flight checks..."
    MSG_PREFLIGHT_DISK_OK="Available disk space: %sMB — OK."
    MSG_PREFLIGHT_DISK_WARN="Low disk space: %sMB available. Minimum 10240MB recommended for the server."
    MSG_PREFLIGHT_DISK_FAIL="Insufficient disk space: only %sMB available. Minimum absolute: 500MB."
    MSG_PREFLIGHT_PORT_BUSY="The following ports are already in use on this system (may cause conflicts):%s"
    MSG_PREFLIGHT_OK="Pre-flight checks completed successfully."
    MSG_TRAP_ERR="Unexpected error at line %s. Check the full log at: %s"
    MSG_LOG_FILE_HINT="Full log available at: %s"
fi

# ─── Root check ───────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    log_error "$MSG_ERR_ROOT"
    exit 1
fi

# ─── Log file initialization ──────────────────────────────────────────────────
touch "$LOG_FILE" 2>/dev/null || true
log_info "$MSG_LOG_INIT" "$LOG_FILE"
log_info "wazuh-install.sh v${SCRIPT_VERSION} | Wazuh ${WAZUH_VERSION} | lang=${LANG_PREF} | unattended=${UNATTENDED}"

# ─── ERR trap ─────────────────────────────────────────────────────────────────
_on_error() {
    local exit_code=$?
    local line_num=${1:-unknown}
    log_error "$MSG_TRAP_ERR" "$line_num" "$LOG_FILE"
    exit "$exit_code"
}
trap '_on_error $LINENO' ERR

# ─── Pre-flight checks ────────────────────────────────────────────────────────
preflight_check() {
    log_info "$MSG_PREFLIGHT_START"

    # Disk space check
    local free_disk_mb
    free_disk_mb=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$free_disk_mb" -lt 500 ]; then
        log_error "$MSG_PREFLIGHT_DISK_FAIL" "$free_disk_mb"
        exit 1
    elif [ "$free_disk_mb" -lt 10240 ]; then
        log_warning "$MSG_PREFLIGHT_DISK_WARN" "$free_disk_mb"
    else
        log_success "$MSG_PREFLIGHT_DISK_OK" "$free_disk_mb"
    fi

    # Port conflict check (server ports)
    local busy_ports=""
    for port in 1514 1515 55000 4443 9200; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} \|:${port}\t"; then
            busy_ports="$busy_ports $port"
        fi
    done
    if [ -n "$busy_ports" ]; then
        log_warning "$MSG_PREFLIGHT_PORT_BUSY" "$busy_ports"
    fi

    log_success "$MSG_PREFLIGHT_OK"
}

# ─── OS Detection ─────────────────────────────────────────────────────────────
OS_NAME=""
OS_VERSION_ID=""
OS_FAMILY="unknown"

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION_ID=${VERSION_ID:-""}
    else
        OS_NAME=$(uname -s)
        OS_VERSION_ID=""
    fi

    case "$OS_NAME" in
        ubuntu|debian|raspbian|pop|linuxmint)
            OS_FAMILY="debian"
            ;;
        rhel|centos|amzn|ol|rocky|alma)
            OS_FAMILY="rhel"
            ;;
        *)
            OS_FAMILY="unknown"
            ;;
    esac
}

# ─── Basic dependencies ───────────────────────────────────────────────────────
check_basic_dependencies() {
    detect_os
    log_info "$MSG_CHECK_DEPS"
    if ! command -v curl >/dev/null 2>&1; then
        log_warning "$MSG_CURL_MISSING"
        if [ "$OS_FAMILY" = "debian" ]; then
            apt-get update && apt-get install -y curl
        elif [ "$OS_FAMILY" = "rhel" ]; then
            yum install -y curl
        else
            log_error "$MSG_CURL_FAIL"
            exit 1
        fi
        log_success "$MSG_CURL_OK"
    fi
}

# ─── Docker & Compose ─────────────────────────────────────────────────────────
install_docker() {
    log_info "$MSG_DOCKER_CHECK"
    if ! command -v docker >/dev/null 2>&1; then
        log_warning "$MSG_DOCKER_MISSING"
        detect_os
        if [ "$OS_FAMILY" = "debian" ]; then
            apt-get update
            apt-get install -y ca-certificates gnupg lsb-release
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS_NAME/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_NAME $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        elif [ "$OS_FAMILY" = "rhel" ]; then
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
            if [ "$OS_NAME" = "ol" ]; then
                dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin --nobest --allowerasing || yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin --allowerasing
            else
                yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            fi
        else
            log_error "$MSG_DOCKER_UNSUPPORTED"
            exit 1
        fi
        systemctl enable docker
        systemctl start docker
        log_success "$MSG_DOCKER_OK"
    else
        log_success "$MSG_DOCKER_EXIST" "$(docker --version)"
    fi

    log_info "$MSG_COMPOSE_CHECK"
    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        log_warning "$MSG_COMPOSE_MISSING"
        detect_os
        if [ "$OS_FAMILY" = "debian" ]; then
            apt-get update && apt-get install -y docker-compose-plugin
        elif [ "$OS_FAMILY" = "rhel" ]; then
            yum install -y docker-compose-plugin
        else
            log_error "$MSG_COMPOSE_FAIL"
            exit 1
        fi
        log_success "$MSG_COMPOSE_OK"
    else
        log_success "$MSG_COMPOSE_EXIST"
    fi
}

# ─── Firewall ─────────────────────────────────────────────────────────────────
configure_firewall() {
    local mode=$1
    local manager_ip=${2:-""}

    local fw_type="none"
    if systemctl is-active --quiet ufw 2>/dev/null; then
        fw_type="ufw"
    elif systemctl is-active --quiet firewalld 2>/dev/null; then
        fw_type="firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        if iptables -L -n | grep -q "^Chain"; then
            fw_type="iptables"
        fi
    fi

    log_info "$MSG_FW_DETECTED" "$fw_type"

    if [ "$mode" = "server" ]; then
        log_info "$MSG_FW_SERVER_CFG"
        case "$fw_type" in
            ufw)
                ufw allow 1514/tcp comment "Wazuh Agent"
                ufw allow 1515/tcp comment "Wazuh Enrollment"
                ufw allow 514/udp comment "Wazuh Syslog"
                ufw allow 55000/tcp comment "Wazuh API"
                ufw allow 4443/tcp comment "Wazuh Dashboard"
                ufw reload
                log_success "$MSG_FW_UFW_SERVER_OK"
                ;;
            firewalld)
                firewall-cmd --permanent --add-port=1514/tcp
                firewall-cmd --permanent --add-port=1515/tcp
                firewall-cmd --permanent --add-port=514/udp
                firewall-cmd --permanent --add-port=55000/tcp
                firewall-cmd --permanent --add-port=4443/tcp
                firewall-cmd --reload
                log_success "$MSG_FW_FIREWALLD_SERVER_OK"
                ;;
            iptables)
                iptables -A INPUT -p tcp --dport 1514 -j ACCEPT -m comment --comment "Wazuh Agent"
                iptables -A INPUT -p tcp --dport 1515 -j ACCEPT -m comment --comment "Wazuh Enrollment"
                iptables -A INPUT -p udp --dport 514 -j ACCEPT -m comment --comment "Wazuh Syslog"
                iptables -A INPUT -p tcp --dport 55000 -j ACCEPT -m comment --comment "Wazuh API"
                iptables -A INPUT -p tcp --dport 4443 -j ACCEPT -m comment --comment "Wazuh Dashboard"
                if command -v iptables-save >/dev/null; then
                    if [ -f /etc/sysconfig/iptables ]; then
                        iptables-save > /etc/sysconfig/iptables
                    elif [ -f /etc/iptables/rules.v4 ]; then
                        iptables-save > /etc/iptables/rules.v4
                    fi
                fi
                log_success "$MSG_FW_IPTABLES_SERVER_OK"
                ;;
            *)
                log_warning "$MSG_FW_NONE_WARNING"
                log_warning "  - TCP: 1514 (Agent), 1515 (Enrollment), 55000 (API), 4443 (Dashboard)"
                log_warning "  - UDP: 514 (Syslog)"
                ;;
        esac
    elif [ "$mode" = "agent" ]; then
        if [ -n "$manager_ip" ]; then
            log_info "$MSG_FW_AGENT_CFG" "$manager_ip"
            case "$fw_type" in
                ufw)
                    ufw allow out to "$manager_ip" port 1514 proto tcp comment "Wazuh Agent Outbound"
                    ufw allow out to "$manager_ip" port 1515 proto tcp comment "Wazuh Enrollment Outbound"
                    ufw allow out to "$manager_ip" port 55000 proto tcp comment "Wazuh API Outbound"
                    ufw reload
                    log_success "$MSG_FW_UFW_AGENT_OK"
                    ;;
                firewalld)
                    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' destination address='$manager_ip' port port='1514' protocol='tcp' accept"
                    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' destination address='$manager_ip' port port='1515' protocol='tcp' accept"
                    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' destination address='$manager_ip' port port='55000' protocol='tcp' accept"
                    firewall-cmd --reload
                    log_success "$MSG_FW_FIREWALLD_AGENT_OK"
                    ;;
                iptables)
                    iptables -A OUTPUT -p tcp -d "$manager_ip" --dport 1514 -j ACCEPT -m comment --comment "Wazuh Agent Outbound"
                    iptables -A OUTPUT -p tcp -d "$manager_ip" --dport 1515 -j ACCEPT -m comment --comment "Wazuh Enrollment Outbound"
                    iptables -A OUTPUT -p tcp -d "$manager_ip" --dport 55000 -j ACCEPT -m comment --comment "Wazuh API Outbound"
                    if command -v iptables-save >/dev/null; then
                        if [ -f /etc/sysconfig/iptables ]; then
                            iptables-save > /etc/sysconfig/iptables
                        elif [ -f /etc/iptables/rules.v4 ]; then
                            iptables-save > /etc/iptables/rules.v4
                        fi
                    fi
                    log_success "$MSG_FW_IPTABLES_AGENT_OK"
                    ;;
                *)
                    log_info "$MSG_FW_AGENT_NONE" "$manager_ip"
                    ;;
            esac
        fi
    fi
}

# ─── Memory helpers ───────────────────────────────────────────────────────────
setup_swap() {
    log_info "$MSG_SWAP_CONFIG"
    if [ -f /swapfile ]; then
        log_warning "$MSG_SWAP_EXIST"
        swapon /swapfile 2>/dev/null || true
    else
        dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
        log_success "$MSG_SWAP_OK"
    fi
}

setup_zram() {
    log_info "$MSG_ZRAM_CONFIG"
    detect_os
    if [ "$OS_FAMILY" = "debian" ]; then
        apt-get update
        apt-get install -y zram-config
        log_success "$MSG_ZRAM_DEB_OK"
    elif [ "$OS_FAMILY" = "rhel" ]; then
        if ! command -v zramctl >/dev/null; then
            yum install -y util-linux
        fi
        if command -v zramctl >/dev/null; then
            modprobe zram num_devices=1 2>/dev/null || true
            zramctl --find --size 2G
            mkswap /dev/zram0
            swapon /dev/zram0
            log_success "$MSG_ZRAM_RHEL_OK"
        else
            log_warning "$MSG_ZRAM_FAIL"
            setup_swap
        fi
    else
        log_warning "$MSG_ZRAM_UNSUPPORTED"
        setup_swap
    fi
}

# ─── Server installation flow ─────────────────────────────────────────────────
install_server_flow() {
    log_info "$MSG_SERVER_START"

    # Hardware RAM check
    if [ -f /proc/meminfo ]; then
        local total_ram
        total_ram=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
        log_info "$MSG_RAM_DETECTED" "$total_ram"

        if [ "$total_ram" -lt 3200 ]; then
            log_warning "$MSG_RAM_WARNING_1"
            log_warning "$MSG_RAM_WARNING_2" "$total_ram"

            if [ "$UNATTENDED" = true ]; then
                if [ "$WAZUH_FORCE_RAM" = "true" ]; then
                    log_warning "$MSG_UNATTENDED_FORCE_RAM"
                else
                    log_error "$MSG_SERVER_ABORT_RAM"
                    log_error "  -> Set WAZUH_FORCE_RAM=true to skip this check."
                    exit 1
                fi
            else
                printf "%s" "$MSG_RAM_FORCE_PROMPT"
                read force_install < /dev/tty
                force_install=${force_install:-n}
                if [[ ! "$force_install" =~ ^[Ss]$ ]]; then
                    log_error "$MSG_SERVER_ABORT_RAM"
                    exit 1
                fi
                printf "%s" "$MSG_RAM_DOUBLE_CONFIRM"
                read double_confirm < /dev/tty
                double_confirm=${double_confirm:-n}
                if [[ ! "$double_confirm" =~ ^[Ss]$ ]]; then
                    log_error "$MSG_SERVER_ABORT_DOUBLE"
                    exit 1
                fi
            fi
            log_warning "$MSG_SERVER_PROCEED_LOW_RAM"
        fi
    fi

    check_basic_dependencies
    install_docker

    # git dependency
    if ! command -v git >/dev/null 2>&1; then
        log_warning "$MSG_GIT_MISSING"
        if [ "$OS_FAMILY" = "debian" ]; then
            apt-get update && apt-get install -y git
        elif [ "$OS_FAMILY" = "rhel" ]; then
            yum install -y git
        else
            log_error "$MSG_GIT_FAIL"
            exit 1
        fi
        log_success "$MSG_GIT_OK"
    fi

    # Kernel limits
    log_info "$MSG_VM_MAX_MAP_CONFIG"
    sysctl -w vm.max_map_count=262144
    if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
        echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    else
        sed -i 's/^vm.max_map_count.*/vm.max_map_count=262144/g' /etc/sysctl.conf
    fi
    log_success "$MSG_VM_MAX_MAP_OK"

    # Repo cloning
    local wazuh_dir="/opt/docker/wazuh"
    log_info "$MSG_SERVER_DIR_PREP" "$wazuh_dir"
    mkdir -p "$wazuh_dir"
    cd "$wazuh_dir"

    if [ -d "wazuh-docker" ]; then
        log_warning "$MSG_SERVER_DIR_EXIST" "$wazuh_dir"

        if [ "$UNATTENDED" = true ]; then
            log_info "$MSG_UNATTENDED_SKIP_CLEAN"
        else
            printf "%s" "$MSG_SERVER_CLEAN_PROMPT"
            read clean_repo < /dev/tty
            clean_repo=${clean_repo:-n}
            if [[ "$clean_repo" =~ ^[Ss]$ ]]; then
                if [ -f "wazuh-docker/single-node/docker-compose.yml" ]; then
                    log_info "$MSG_SERVER_STOPPING_EXISTING"
                    (cd wazuh-docker/single-node && docker compose down || true)
                fi
                rm -rf wazuh-docker
                git clone https://github.com/wazuh/wazuh-docker.git -b "v${WAZUH_VERSION}"
            fi
        fi
    else
        git clone https://github.com/wazuh/wazuh-docker.git -b "v${WAZUH_VERSION}"
    fi

    if [ ! -d "wazuh-docker/single-node" ]; then
        log_error "$MSG_SERVER_REPO_ERR"
        exit 1
    fi

    cd wazuh-docker/single-node/

    # Admin password
    echo -e "\n${YELLOW}$MSG_SEC_HEADER${NC}"
    echo "$MSG_SEC_INFO_1"

    local admin_pass=""
    if [ "$UNATTENDED" = true ]; then
        if [ -n "$WAZUH_ADMIN_PASS" ]; then
            if [ ${#WAZUH_ADMIN_PASS} -lt 8 ]; then
                log_error "$MSG_SEC_PASS_MIN"
                exit 1
            fi
            admin_pass="$WAZUH_ADMIN_PASS"
            log_info "$MSG_HASH_START"
        else
            log_info "$MSG_UNATTENDED_PASS_GEN"
            admin_pass=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 20 || true)
            log_success "$MSG_SEC_PASS_GEN" "$admin_pass"
        fi
    else
        echo "$MSG_SEC_INFO_2"
        while [ -z "$admin_pass" ]; do
            printf "%s" "$MSG_SEC_PASS_PROMPT"
            read -s admin_pass < /dev/tty
            echo ""
            if [ -z "$admin_pass" ]; then
                admin_pass=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 16 || true)
                log_info "$MSG_SEC_PASS_GEN" "$admin_pass"
                break
            elif [ ${#admin_pass} -lt 8 ]; then
                log_error "$MSG_SEC_PASS_MIN"
                admin_pass=""
            fi
        done
    fi

    # Hash generation
    log_info "$MSG_HASH_START"
    local hash_val=""
    docker pull "wazuh/wazuh-indexer:${WAZUH_VERSION}" >/dev/null 2>&1 || true
    hash_val=$(docker run --rm "wazuh/wazuh-indexer:${WAZUH_VERSION}" bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$admin_pass" | tail -n 1 | tr -d '\r\n')

    if [ -z "$hash_val" ] || [[ ! "$hash_val" =~ ^\$ ]]; then
        log_error "$MSG_HASH_ERR"
        exit 1
    fi
    log_success "$MSG_HASH_OK"

    # Write config
    log_info "$MSG_CFG_WRITE_START"
    if command -v python3 >/dev/null 2>&1; then
        export ADMIN_HASH="$hash_val"
        export ADMIN_PASS="$admin_pass"
        python3 -c '
import os, re
hash_val = os.environ.get("ADMIN_HASH", "")
pass_val = os.environ.get("ADMIN_PASS", "")
if hash_val and pass_val:
    users_path = "config/wazuh_indexer/internal_users.yml"
    if os.path.exists(users_path):
        with open(users_path, "r") as f:
            content = f.read()
        new_content = re.sub(r"(admin:\s*\n\s*hash:\s*\")[^\"]+(\")", r"\g<1>" + hash_val + r"\g<2>", content)
        with open(users_path, "w") as f:
            f.write(new_content)
    compose_path = "docker-compose.yml"
    if os.path.exists(compose_path):
        with open(compose_path, "r") as f:
            content = f.read()
        new_content = content.replace("INDEXER_PASSWORD=SecretPassword", f"INDEXER_PASSWORD={pass_val}")
        with open(compose_path, "w") as f:
            f.write(new_content)
'
    else
        local escaped_hash
        escaped_hash=$(echo "$hash_val" | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\&/g')
        local escaped_pass
        escaped_pass=$(echo "$admin_pass" | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\&/g')
        sed -i "s|hash: \"\$2y\$12\$K/SpwjtB.wOHJ/Nc6GVRDuc1h0rM1DfvziFRNPtk27P.c4yDr9njO\"|hash: \"$escaped_hash\"|g" config/wazuh_indexer/internal_users.yml
        sed -i "s|INDEXER_PASSWORD=SecretPassword|INDEXER_PASSWORD=$escaped_pass|g" docker-compose.yml
    fi
    log_success "$MSG_CFG_WRITE_OK"

    # Certificates
    log_info "$MSG_CERTS_START"
    rm -rf wazuh-certificates/
    docker compose -f generate-indexer-certs.yml run --rm generator
    log_success "$MSG_CERTS_OK"

    # Port remapping
    log_info "$MSG_PORT_CHANGE_START"
    if grep -q "443:5601" docker-compose.yml; then
        sed -i 's/443:5601/4443:5601/g' docker-compose.yml
    elif grep -q '"443:5601"' docker-compose.yml; then
        sed -i 's/"443:5601"/"4443:5601"/g' docker-compose.yml
    else
        sed -i 's/443/4443/g' docker-compose.yml
    fi
    log_success "$MSG_PORT_CHANGE_OK"

    # Start stack
    log_info "$MSG_STACK_START"
    docker compose up -d
    log_success "$MSG_STACK_OK"

    configure_firewall "server"

    local server_ip
    server_ip=$(curl -s https://api.ipify.org || echo "$MSG_IP_FALLBACK")

    echo -e "\n${GREEN}======================================================================${NC}"
    echo -e "${GREEN}             $MSG_SERVER_BANNER_OK${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    log_info "$MSG_SERVER_URL" "$server_ip"
    log_info "$MSG_SERVER_USER"
    log_info "$MSG_SERVER_PASS" "$admin_pass"
    log_info "$MSG_LOG_FILE_HINT" "$LOG_FILE"
    echo -e "${GREEN}======================================================================${NC}"
}

# ─── Agent installation flow ──────────────────────────────────────────────────
install_agent_flow() {
    log_info "$MSG_AGENT_START"
    check_basic_dependencies

    # Manager IP
    local manager_ip=""
    if [ "$UNATTENDED" = true ]; then
        if [ -z "$WAZUH_MANAGER_IP" ]; then
            log_error "$MSG_UNATTENDED_MANAGER_ERR"
            exit 1
        fi
        manager_ip="$WAZUH_MANAGER_IP"
    else
        while [ -z "$manager_ip" ]; do
            printf "%s" "$MSG_AGENT_MANAGER_PROMPT"
            read manager_ip < /dev/tty
            if [ -z "$manager_ip" ]; then
                log_error "$MSG_AGENT_MANAGER_ERR"
            fi
        done
    fi

    # Agent name
    local agent_name=""
    if [ "$UNATTENDED" = true ]; then
        agent_name="${WAZUH_AGENT_NAME:-$(hostname)}"
    else
        printf "$MSG_AGENT_NAME_PROMPT" "$(hostname)"
        read agent_name < /dev/tty
        agent_name=${agent_name:-$(hostname)}
    fi

    # Agent group
    local agent_group=""
    if [ "$UNATTENDED" = true ]; then
        agent_group="${WAZUH_AGENT_GROUP:-default}"
    else
        printf "%s" "$MSG_AGENT_GROUP_PROMPT"
        read agent_group < /dev/tty
        agent_group=${agent_group:-"default"}
    fi

    # Memory optimization
    local has_swap=false
    local active_swaps=""
    if [ -f /proc/swaps ]; then
        active_swaps=$(grep -v -E "^Filename" /proc/swaps | awk '{print $1 " (" $2 ")"}')
        if [ -n "$active_swaps" ]; then
            has_swap=true
        fi
    fi

    echo -e "\n${YELLOW}$MSG_MEM_OPT_HEADER${NC}"
    if [ "$has_swap" = true ]; then
        log_warning "$MSG_MEM_OPT_DETECT"
        echo "$active_swaps" | while read -r line; do
            echo -e "  -> $line"
        done
        echo -e "${YELLOW}$MSG_MEM_OPT_RECOMMEND${NC}"
    else
        log_info "$MSG_MEM_OPT_NONE"
    fi

    local mem_opt
    if [ "$UNATTENDED" = true ]; then
        mem_opt="${WAZUH_MEM_OPT:-3}"
        log_info "$MSG_UNATTENDED_MEM_OPT" "$mem_opt"
    else
        echo "$MSG_MEM_OPT_QUESTION"
        echo "$MSG_MEM_OPT_OPT1"
        echo "$MSG_MEM_OPT_OPT2"
        echo "$MSG_MEM_OPT_OPT3"
        printf "%s" "$MSG_MEM_OPT_PROMPT"
        read mem_opt < /dev/tty
        mem_opt=${mem_opt:-3}
    fi

    case "$mem_opt" in
        1) setup_swap ;;
        2) setup_zram ;;
        *) log_info "$MSG_MEM_OPT_NO_CHANGE" ;;
    esac

    log_info "$MSG_OVERCOMMIT_SET"
    sysctl -w vm.overcommit_memory=1

    detect_os
    local arch
    arch=$(uname -m)

    if [ "$OS_FAMILY" = "debian" ]; then
        log_info "$MSG_AGENT_DEB_PREP"
        local deb_url=""
        if [ "$arch" = "x86_64" ]; then
            deb_url="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}-1_amd64.deb"
        elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then
            deb_url="https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${WAZUH_VERSION}-1_arm64.deb"
        else
            log_error "$MSG_ARCH_UNSUPPORTED" "$arch"
            sysctl -w vm.overcommit_memory=0
            exit 1
        fi

        log_info "$MSG_AGENT_DEB_DOWN" "$deb_url"
        curl -L -o /tmp/wazuh-agent.deb "$deb_url"

        log_info "$MSG_AGENT_INSTALL_START"
        WAZUH_MANAGER="$manager_ip" WAZUH_AGENT_GROUP="$agent_group" WAZUH_AGENT_NAME="$agent_name" dpkg -i /tmp/wazuh-agent.deb
        rm -f /tmp/wazuh-agent.deb

    elif [ "$OS_FAMILY" = "rhel" ]; then
        log_info "$MSG_AGENT_RPM_PREP"
        local rpm_url=""
        if [ "$arch" = "x86_64" ]; then
            rpm_url="https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VERSION}-1.x86_64.rpm"
        elif [ "$arch" = "aarch64" ]; then
            rpm_url="https://packages.wazuh.com/4.x/yum/wazuh-agent-${WAZUH_VERSION}-1.aarch64.rpm"
        else
            log_error "$MSG_ARCH_UNSUPPORTED" "$arch"
            sysctl -w vm.overcommit_memory=0
            exit 1
        fi

        log_info "$MSG_AGENT_RPM_DOWN" "$rpm_url"
        curl -L -o /tmp/wazuh-agent.rpm "$rpm_url"

        log_info "$MSG_AGENT_INSTALL_START"
        WAZUH_MANAGER="$manager_ip" WAZUH_AGENT_GROUP="$agent_group" WAZUH_AGENT_NAME="$agent_name" rpm -ihv /tmp/wazuh-agent.rpm --force
        rm -f /tmp/wazuh-agent.rpm
    else
        log_error "$MSG_AGENT_OS_UNSUPPORTED"
        sysctl -w vm.overcommit_memory=0
        exit 1
    fi

    # Fallback address verification in ossec.conf
    if [ -f /var/ossec/etc/ossec.conf ]; then
        if ! grep -q "<address>$manager_ip</address>" /var/ossec/etc/ossec.conf; then
            log_info "$MSG_AGENT_OSSEC_CONF_CFG"
            sed -i "s/<address>MANAGER_IP<\/address>/<address>$manager_ip<\/address>/g" /var/ossec/etc/ossec.conf
        fi
    fi

    log_info "$MSG_AGENT_SERVICE_START"
    systemctl daemon-reload
    systemctl enable wazuh-agent
    systemctl start wazuh-agent

    log_info "$MSG_OVERCOMMIT_RESET"
    sysctl -w vm.overcommit_memory=0

    configure_firewall "agent" "$manager_ip"

    echo -e "\n${GREEN}======================================================================${NC}"
    echo -e "${GREEN}             $MSG_AGENT_BANNER_OK${NC}"
    echo -e "${GREEN}======================================================================${NC}"
    log_success "$MSG_AGENT_BANNER_INFO" "$agent_name" "$manager_ip"
    systemctl status wazuh-agent --no-pager || true
    log_info "$MSG_LOG_FILE_HINT" "$LOG_FILE"
    echo -e "${GREEN}======================================================================${NC}"
}

# ─── Health Check ─────────────────────────────────────────────────────────────
health_check_flow() {
    log_info "$MSG_HEALTH_START"
    local detected=false

    if command -v docker >/dev/null 2>&1; then
        local containers
        containers=$(docker ps -a --filter "name=single-node-wazuh" --format "{{.Names}}: {{.Status}}" || true)
        if [ -n "$containers" ]; then
            detected=true
            echo -e "\n${YELLOW}$MSG_HEALTH_SERVER_HEADER${NC}"
            echo "$containers"

            echo -e "\n${YELLOW}$MSG_HEALTH_DASHBOARD_HEADER${NC}"
            local response_code
            response_code=$(curl -k -s -o /dev/null -w "%{http_code}" https://localhost:4443 || echo "$MSG_CURL_CONN_ERR")
            if [ "$response_code" = "200" ] || [ "$response_code" = "302" ] || [ "$response_code" = "401" ] || [ "$response_code" = "403" ]; then
                log_success "$MSG_HEALTH_DASHBOARD_OK" "$response_code"
            else
                log_warning "$MSG_HEALTH_DASHBOARD_ERR" "$response_code"
            fi
        fi
    fi

    if systemctl list-unit-files | grep -q "^wazuh-agent.service" 2>/dev/null; then
        detected=true
        echo -e "\n${YELLOW}$MSG_HEALTH_AGENT_HEADER${NC}"
        if systemctl is-active --quiet wazuh-agent; then
            log_success "$MSG_HEALTH_AGENT_ACTIVE"
        else
            log_warning "$MSG_HEALTH_AGENT_INACTIVE"
        fi

        if [ -f /var/ossec/etc/ossec.conf ]; then
            local mgr_ip
            mgr_ip=$(grep -oP '<address>\K[^<]+' /var/ossec/etc/ossec.conf | head -n 1 || true)
            log_info "$MSG_HEALTH_AGENT_MANAGER" "${mgr_ip:-N/A}"
        fi

        if [ -f /var/ossec/logs/ossec.log ]; then
            echo -e "\n${YELLOW}$MSG_HEALTH_AGENT_LOGS_HEADER${NC}"
            local connection_log
            connection_log=$(grep -i "connected" /var/ossec/logs/ossec.log | tail -n 3 || true)
            if [ -n "$connection_log" ]; then
                echo "$connection_log"
            else
                local last_logs
                last_logs=$(tail -n 10 /var/ossec/logs/ossec.log || true)
                echo "$MSG_HEALTH_AGENT_NO_LOGS"
                echo "$last_logs"
            fi
        fi
    fi

    if [ "$detected" = false ]; then
        log_warning "$MSG_HEALTH_NONE_DETECTED"
    fi

    echo -e "\n${BLUE}======================================================================${NC}"
    log_info "$MSG_LOG_FILE_HINT" "$LOG_FILE"
    printf "%s" "$MSG_ENTER_BACK"
    read temp < /dev/tty
}

# ─── Uninstall flows ──────────────────────────────────────────────────────────
uninstall_server() {
    echo -e "${RED}$MSG_UN_SERVER_WARN${NC}"
    printf "%s" "$MSG_UN_CONFIRM_PROMPT"
    read confirm_un < /dev/tty
    confirm_un=${confirm_un:-n}
    if [[ ! "$confirm_un" =~ ^[Yy]$ ]]; then
        log_info "$MSG_UN_CANCELLED"
        return
    fi

    log_info "$MSG_UN_SERVER_STOPPING"
    local compose_dir="/opt/docker/wazuh/wazuh-docker/single-node"
    if [ -f "$compose_dir/docker-compose.yml" ]; then
        (cd "$compose_dir" && docker compose down -v || true)
    fi

    log_info "$MSG_UN_SERVER_DIR_REM"
    rm -rf /opt/docker/wazuh

    log_info "$MSG_UN_SERVER_FW_CLEAN"
    if systemctl is-active --quiet ufw 2>/dev/null; then
        ufw delete allow 1514/tcp 2>/dev/null || true
        ufw delete allow 1515/tcp 2>/dev/null || true
        ufw delete allow 514/udp 2>/dev/null || true
        ufw delete allow 55000/tcp 2>/dev/null || true
        ufw delete allow 4443/tcp 2>/dev/null || true
        ufw reload
        log_success "$MSG_UN_SERVER_FW_UFW"
    elif systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --remove-port=1514/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=1515/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=514/udp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=55000/tcp 2>/dev/null || true
        firewall-cmd --permanent --remove-port=4443/tcp 2>/dev/null || true
        firewall-cmd --reload
        log_success "$MSG_UN_SERVER_FW_FIREWALLD"
    fi

    log_success "$MSG_UN_SERVER_OK"
}

uninstall_agent() {
    printf "%s" "$MSG_UN_AGENT_CONFIRM_PROMPT"
    read confirm_un < /dev/tty
    confirm_un=${confirm_un:-n}
    if [[ ! "$confirm_un" =~ ^[Yy]$ ]]; then
        log_info "$MSG_UN_CANCELLED"
        return
    fi

    log_info "$MSG_UN_AGENT_STOPPING"
    systemctl stop wazuh-agent 2>/dev/null || true
    systemctl disable wazuh-agent 2>/dev/null || true

    detect_os
    log_info "$MSG_UN_AGENT_PKG_REM"
    if [ "$OS_FAMILY" = "debian" ]; then
        apt-get purge -y wazuh-agent || dpkg -P wazuh-agent || true
    elif [ "$OS_FAMILY" = "rhel" ]; then
        yum remove -y wazuh-agent || rpm -e wazuh-agent || true
    fi

    log_info "$MSG_UN_AGENT_DIR_REM"
    rm -rf /var/ossec

    if [ -f /swapfile ]; then
        printf "%s" "$MSG_UN_AGENT_SWAP_PROMPT"
        read remove_swap < /dev/tty
        remove_swap=${remove_swap:-n}
        if [[ "$remove_swap" =~ ^[Yy]$ ]]; then
            log_info "$MSG_UN_AGENT_SWAP_STOPPING"
            swapoff /swapfile 2>/dev/null || true
            rm -f /swapfile
            sed -i '/\/swapfile swap swap defaults/d' /etc/fstab
            log_success "$MSG_UN_AGENT_SWAP_OK"
        fi
    fi

    log_success "$MSG_UN_AGENT_OK"
}

uninstall_flow() {
    clear
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${RED}             $MSG_UN_FLOW_HEADER${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo "$MSG_UN_FLOW_OPT1"
    echo "$MSG_UN_FLOW_OPT2"
    echo "$MSG_UN_FLOW_OPT3"
    echo -e "${BLUE}======================================================================${NC}"
    printf "%s" "$MSG_UN_FLOW_PROMPT"
    read opt_un < /dev/tty
    opt_un=${opt_un:-3}

    case "$opt_un" in
        1) uninstall_server ;;
        2) uninstall_agent ;;
        *) return ;;
    esac

    echo -e "\n${BLUE}======================================================================${NC}"
    printf "%s" "$MSG_ENTER_CONTINUE"
    read temp < /dev/tty
}

# ─── Banner ───────────────────────────────────────────────────────────────────
banner_sr00t3d() {
    echo -e "${YELLOW}"
    echo "██╗    ██╗ █████╗ ███████╗██╗   ██╗██╗  ██╗"
    echo "██║    ██║██╔══██╗╚══███╔╝██║   ██║██║  ██║"
    echo "██║ █╗ ██║███████║  ███╔╝ ██║   ██║███████║"
    echo "██║███╗██║██╔══██║ ███╔╝  ██║   ██║██╔══██║"
    echo "╚███╔███╔╝██║  ██║███████╗╚██████╔╝██║  ██║"
    echo " ╚══╝╚══╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝"
    echo -e "${BLUE}             [ Automated Installer v${SCRIPT_VERSION} ]${NC}"
    echo -e "${CYAN}             [ Wazuh ${WAZUH_VERSION} ]${NC}"
    echo ""
}

# ─── Main menu ────────────────────────────────────────────────────────────────
show_menu() {
    # Unattended mode: bypass menu and dispatch directly
    if [ "$UNATTENDED" = true ]; then
        log_info "$MSG_UNATTENDED_ON"
        case "$WAZUH_MODE" in
            server) install_server_flow ;;
            agent)  install_agent_flow ;;
            *)
                log_error "$MSG_UNATTENDED_MODE_ERR"
                exit 1
                ;;
        esac
        exit 0
    fi

    clear
    banner_sr00t3d
    echo -e "${BLUE}======================================================================${NC}"
    echo -e "${GREEN}$MSG_MENU_HEADER${NC}"
    echo -e "${YELLOW}$MSG_MENU_AUTHOR${NC}"
    echo -e "${BLUE}======================================================================${NC}"
    echo "$MSG_MENU_OPT1"
    echo "$MSG_MENU_OPT2"
    echo "$MSG_MENU_OPT3"
    echo "$MSG_MENU_OPT4"
    echo "$MSG_MENU_OPT5"
    echo -e "${BLUE}======================================================================${NC}"
    printf "%s" "$MSG_MENU_PROMPT"
    read opt < /dev/tty
    opt=${opt:-5}

    case "$opt" in
        1) install_server_flow ;;
        2) install_agent_flow ;;
        3)
            health_check_flow
            show_menu
            ;;
        4)
            uninstall_flow
            show_menu
            ;;
        5)
            log_info "$MSG_EXIT"
            exit 0
            ;;
        *)
            log_error "$MSG_INVALID_OPT"
            sleep 1
            show_menu
            ;;
    esac
}

# ─── Entry point ──────────────────────────────────────────────────────────────
preflight_check
show_menu