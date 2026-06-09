# Wazuh Automated Installer — Server & Agent

[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.14.3-00b4d8.svg)](https://wazuh.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20RHEL-orange.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20aarch64-purple.svg)](https://github.com/sr00t3d/wazuh-installer)

Script Shell interativo e robusto para automatizar a instalação, configuração, otimização e gerenciamento do **Wazuh** (servidor Single-Node via Docker e agente Wazuh) em distribuições Linux populares.

Desenvolvido por **[Percio Castelo (sr00t3d)](https://perciocastelo.com.br)**.

---

## 🚀 Execução Rápida

```bash
# Interativo (menu completo):
curl -sSL https://raw.githubusercontent.com/sr00t3d/wazuh-installer/refs/heads/main/wazuh-install.sh | sudo bash

# Modo não-interativo — Servidor:
sudo WAZUH_MODE=server WAZUH_ADMIN_PASS='MinhaS3nha!' ./wazuh-install.sh --unattended

# Modo não-interativo — Agente:
sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.10 WAZUH_AGENT_NAME=webserver01 ./wazuh-install.sh --unattended

# Ver ajuda completa:
sudo ./wazuh-install.sh --help

# Ver versão:
sudo ./wazuh-install.sh --version
```

---

## 📋 Funcionalidades

### 🖥️ 1. Servidor Wazuh (Single-Node)
* **Instalação do Docker e Docker Compose**: Instala automaticamente o Docker Engine e o plugin Compose caso não estejam presentes.
* **Tuning de Kernel**: Habilita persistentemente `vm.max_map_count=262144` exigido pelo Wazuh Indexer.
* **Geração Automática de Certificados**: Executa o gerador oficial TLS do Wazuh via Docker.
* **Senha Segura Customizada**:
  * Solicita uma senha personalizada para o usuário `admin` antes do deploy.
  * Gera senha aleatória forte (20 chars) automaticamente se o campo for deixado vazio.
  * Gera o hash BCrypt correspondente usando o container `wazuh-indexer` e atualiza `internal_users.yml` e `docker-compose.yml`.
* **Redirecionamento de Portas**: Dashboard rodando na porta HTTPS `4443` para evitar conflito com servidores web na `443`.
* **Liberação de Firewall**: Abre as portas de entrada (`1514/tcp`, `1515/tcp`, `514/udp`, `55000/tcp`, `4443/tcp`) em UFW, firewalld ou iptables.

### 📦 2. Agente Wazuh
* **Registro Interativo**: IP/Domínio do Manager, nome customizado (padrão: hostname) e grupo (padrão: default).
* **Otimização de Memória (Swap / ZRAM)**:
  * Detecta configurações existentes para evitar duplicações.
  * Cria Swap de 2GB ou configura ZRAM para evitar OOM em instâncias com < 2GB RAM.
  * Habilita temporariamente `vm.overcommit_memory=1` durante instalação.
* **Instalação Automática**: Baixa pacote `.deb` ou `.rpm` oficial para a arquitetura e SO detectados.
* **Liberação de Firewall (Saída)**: Configura regras de saída apontadas para o IP do Servidor.

### 🔍 3. Verificação de Saúde (Health Check)
* Analisa containers Docker do servidor e testa conectividade HTTP na porta `4443`.
* Verifica status do serviço `wazuh-agent`, exibe Manager configurado e logs recentes do `ossec.log`.

### 🗑️ 4. Desinstalador Completo
* **Servidor**: Para containers e volumes, limpa `/opt/docker/wazuh` e revoga regras de firewall.
* **Agente**: Para serviço, desinstala pacote, limpa `/var/ossec` e oferece remoção do swapfile.

### 🌐 5. Internacionalização (i18n)
* **Detecção Automática**: Detecta a localidade do sistema e renderiza em **Português** ou **Inglês**.
* **Flags manuais**: `--lang=pt` ou `--lang=en` para forçar o idioma.

### ⚙️ 6. Modo Não-Interativo (Unattended)
* Flag `--unattended` + variáveis de ambiente para uso em CI/CD, Ansible, cloud-init.
* Ver seção completa de variáveis abaixo.

### 🛡️ 7. Verificações de Pré-Instalação
* Verifica espaço em disco disponível (mínimo 500MB, alerta abaixo de 10GB).
* Detecta portas já em uso que possam causar conflitos.

### 📄 8. Log Completo
* Todo o output é salvo em `/var/log/wazuh-install.log` com timestamps.

---

## 🛠️ Requisitos de Sistema

| Requisito | Detalhes |
|-----------|----------|
| **OS Suportados** | Família Debian (Ubuntu, Debian, Mint...) e Família RHEL (RHEL, CentOS, OL, Rocky, AlmaLinux) |
| **Arquiteturas** | `x86_64` (AMD64) e `aarch64` (ARM64) |
| **Servidor RAM** | Mínimo recomendado: **4GB** (alerta abaixo de 3.2GB) |
| **Agente RAM** | A partir de **1GB** com Swap/ZRAM habilitado |
| **Disco** | Mínimo 500MB; recomendado 20GB para o servidor |
| **Permissões** | Execução como `root` ou `sudo` |

---

## 💾 Como Executar

### Modo Interativo

```bash
# Opção A: Download e execução
curl -O https://raw.githubusercontent.com/sr00t3d/wazuh-installer/refs/heads/main/wazuh-install.sh
chmod +x wazuh-install.sh
sudo ./wazuh-install.sh

# Opção B: Execução direta por URL
curl -sSL https://raw.githubusercontent.com/sr00t3d/wazuh-installer/refs/heads/main/wazuh-install.sh | sudo bash
```

### Forçar Idioma Específico

```bash
# Inglês via URL
curl -sSL https://raw.githubusercontent.com/sr00t3d/wazuh-installer/refs/heads/main/wazuh-install.sh | sudo bash -s -- --lang=en

# Português local
sudo ./wazuh-install.sh --lang=pt
```

### Modo Não-Interativo (Unattended)

```bash
# Servidor com senha customizada
sudo WAZUH_MODE=server WAZUH_ADMIN_PASS='Str0ngP@ss!' ./wazuh-install.sh --unattended

# Servidor com senha auto-gerada
sudo WAZUH_MODE=server ./wazuh-install.sh --unattended

# Servidor em host com pouca RAM (pula checagem)
sudo WAZUH_MODE=server WAZUH_FORCE_RAM=true ./wazuh-install.sh --unattended

# Agente simples
sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=192.168.1.10 ./wazuh-install.sh --unattended

# Agente com swap e nome customizado
sudo WAZUH_MODE=agent \
  WAZUH_MANAGER_IP=10.0.0.1 \
  WAZUH_AGENT_NAME=prod-webserver-01 \
  WAZUH_AGENT_GROUP=webservers \
  WAZUH_MEM_OPT=1 \
  ./wazuh-install.sh --unattended

# Via curl (ex: cloud-init)
curl -sSL https://raw.githubusercontent.com/sr00t3d/wazuh-installer/refs/heads/main/wazuh-install.sh | \
  sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.1 bash -s -- --unattended
```

### Variáveis de Ambiente (Modo Unattended)

| Variável | Valores | Descrição |
|----------|---------|-----------|
| `WAZUH_MODE` | `server` \| `agent` | **Obrigatório.** Define o que instalar. |
| `WAZUH_VERSION` | string | Versão alvo do Wazuh (padrão: `4.14.3`) |
| `WAZUH_ADMIN_PASS` | string | [Servidor] Senha admin (mín. 8 chars). Vazio = auto-gerada. |
| `WAZUH_FORCE_RAM` | `true` \| `false` | [Servidor] Pula checagem de RAM baixa. |
| `WAZUH_MANAGER_IP` | IP/domínio | [Agente] **Obrigatório.** IP do Manager. |
| `WAZUH_AGENT_NAME` | string | [Agente] Nome do agente (padrão: hostname). |
| `WAZUH_AGENT_GROUP` | string | [Agente] Grupo do agente (padrão: `default`). |
| `WAZUH_MEM_OPT` | `1` \| `2` \| `3` | [Agente] `1`=swap, `2`=zram, `3`=nenhum (padrão: `3`). |

---

## 📂 Log de Instalação

Todos os outputs são automaticamente salvos com timestamp em:

```
/var/log/wazuh-install.log
```

---

## 🛡️ Licença

Este projeto é distribuído sob a licença **MIT**. Consulte o cabeçalho do script para mais detalhes.