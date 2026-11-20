# Wazuh Automated Installer — Servidor & Agente (`wazuh-install.sh`)

![Capa Wazuh Installer](wazuh-installer-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.14.3-00b4d8.svg)](https://wazuh.com)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20RHEL-orange.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20aarch64-purple.svg)](https://github.com/sr00t3d/wazuh-installer)

CLI em Bash interativa e automatizada para auditar pré-requisitos, instalar, otimizar e gerenciar o **Wazuh Single-Node Server (via Docker)** e o **Wazuh Agent** em distribuições Debian/Ubuntu e RHEL/AlmaLinux/Rocky Linux.

## Principais Recursos

- **Auditoria Preflight sem root (`--preflight` / `--status`):** verifica SO/arquitetura, RAM, disco livre, `vm.max_map_count`, Docker Engine e Compose, status de servidor/agente Wazuh e portas alvo (`1514`, `1515`, `514`, `55000`, `4443`) nos formatos `table`, `json` e `csv`.
- **Modo Não-Interativo & Dry-Run (`--unattended`, `--dry-run`):** permite simular ou executar deploys automatizados de servidor/agente em CI/CD, Ansible e cloud-init via variáveis `WAZUH_*`.
- **Servidor Wazuh Single-Node (Docker):** instala Docker Engine + Compose, persiste `vm.max_map_count=262144`, gera certificados TLS oficiais, configura senha `admin` com hash BCrypt (customizada ou aleatória de 20 caracteres), expõe o Dashboard HTTPS na porta `4443` e abre portas no firewall (`UFW`, `firewalld` ou `iptables`).
- **Agente Wazuh:** detecta distro/arquitetura (`x86_64` / `aarch64`), instala pacotes oficiais `.deb` / `.rpm`, configura IP do Manager, nome/grupo do agente, otimização opcional de memória (Swap 2GB ou ZRAM) e regras de saída no firewall.
- **Health Check, Desinstalador & i18n:** checagem de saúde de containers e agente, desinstalação limpa, detecção automática de idioma PT-BR / EN (`--lang=pt|en`) e log completo em `/var/log/wazuh-install.log`.

## Uso Rápido

```bash
git clone https://github.com/sr00t3d/wazuh-installer.git
cd wazuh-installer
chmod +x wazuh-install.sh

# Auditar prontidão do host sem precisar de root (table, json ou csv)
./wazuh-install.sh --preflight
./wazuh-install.sh --preflight -o json

# Menu interativo (servidor, agente, health check, desinstalação)
sudo ./wazuh-install.sh

# Simular deploy não-interativo do servidor (--dry-run)
WAZUH_MODE=server ./wazuh-install.sh --unattended --dry-run

# Deploy não-interativo do servidor com senha customizada
sudo WAZUH_MODE=server WAZUH_ADMIN_PASS='Str0ngP@ss!' ./wazuh-install.sh --unattended

# Deploy não-interativo do agente com Swap de 2GB
sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.10 WAZUH_AGENT_NAME=web-prod-01 WAZUH_AGENT_GROUP=webservers WAZUH_MEM_OPT=1 ./wazuh-install.sh --unattended
```

## Opções da CLI e Variáveis de Ambiente

| Opção | Descrição |
|---|---|
| `--preflight`, `--status` | Audita SO, RAM, disco, `vm.max_map_count`, Docker, portas e estado do Wazuh (sem exigir root) |
| `--dry-run` | Simula o plano de deploy não-interativo sem alterar o host |
| `-o`, `--output <fmt>` | Formato de saída para `--preflight` / `--dry-run`: `table` (padrão), `json`, `csv` |
| `--unattended` | Execução não-interativa guiada por variáveis `WAZUH_*` |
| `--lang=pt\|en` | Força o idioma da interface (auto-detectado pelo locale por padrão) |
| `-q`, `--quiet` | Suprime cabeçalhos nos modos estruturados |
| `--no-color` | Desativa cores ANSI |
| `-V`, `--version` | Exibe versão do script e versão alvo do Wazuh |
| `-h`, `--help` | Exibe ajuda e encerra |

| Variável | Valores | Descrição |
|---|---|---|
| `WAZUH_MODE` | `server` \| `agent` | Perfil alvo (obrigatório em `--unattended`) |
| `WAZUH_VERSION` | string | Versão alvo do Wazuh (padrão: `4.14.3`) |
| `WAZUH_ADMIN_PASS` | string | Senha do admin do servidor (mín. 8 chars; vazio = auto-gerada) |
| `WAZUH_FORCE_RAM` | `true` \| `false` | Pula validação de RAM baixa no servidor |
| `WAZUH_MANAGER_IP` | IP / FQDN | Endereço do Wazuh Manager (obrigatório no agente) |
| `WAZUH_AGENT_NAME` | string | Nome do agente (padrão: hostname) |
| `WAZUH_AGENT_GROUP` | string | Grupo do agente (padrão: `default`) |
| `WAZUH_MEM_OPT` | `1` \| `2` \| `3` | Memória do agente: `1`=swap, `2`=zram, `3`=nenhum |

## Exemplo de Saída Real

### Auditoria Preflight (`./wazuh-install.sh --preflight --no-color`)

```text
=====================================================================
 wazuh-install.sh v2.0.0 | Preflight & Readiness Audit | 2026-11-20T22:57:32Z
=====================================================================
  Wazuh Target     : 4.14.3
  OS / Arch        : AlmaLinux 8.10 (Cerulean Leopard) (x86_64)
  RAM / Disk Free  : 11688 MB / 20 GB (server readiness: yes)
  vm.max_map_count : 262144 (required >= 262144 for Indexer)
  Docker / Compose : not-installed / not-installed
  Wazuh Server Dir : absent (/opt/docker/wazuh)
  Wazuh Agent      : not-installed
  Target Ports Busy: none (checked: 1514,1515,514,55000,4443)
```

### Saída Estruturada em JSON (`./wazuh-install.sh --preflight -o json`)

```json
{
  "tool": "wazuh-install.sh",
  "version": "2.0.0",
  "wazuh_target": "4.14.3",
  "timestamp": "2026-11-20T22:57:33Z",
  "os": "AlmaLinux 8.10 (Cerulean Leopard)",
  "arch": "x86_64",
  "ram_mb": 11688,
  "disk_free_gb": 20,
  "vm_max_map_count": 262144,
  "docker": "not-installed",
  "docker_compose": "not-installed",
  "wazuh_server_dir": "absent",
  "wazuh_agent": "not-installed",
  "ports_in_use": "none",
  "server_readiness": "yes"
}
```

### Dry-Run de Agente Não-Interativo (`WAZUH_MODE=agent ... ./wazuh-install.sh --unattended --dry-run -o json`)

```json
{
  "tool": "wazuh-install.sh",
  "version": "2.0.0",
  "dry_run": true,
  "mode": "agent",
  "wazuh_version": "4.14.3",
  "timestamp": "2026-11-20T22:57:34Z",
  "manager_ip": "10.0.0.10",
  "agent_name": "web-prod-01",
  "agent_group": "webservers",
  "memory_opt": "1"
}
```

## Licença

Licenciado sob a [Apache License 2.0](LICENSE).

English: [README.md](README.md)
