# Wazuh Automated Installer — Server & Agent (`wazuh-install.sh`)

🇺🇸 **English** | 🇧🇷 [Português (BR)](README-ptbr.md) | 🇪🇸 [Español](README-es.md)

![Wazuh Installer Cover](wazuh-installer-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.14.3-00b4d8.svg)](https://wazuh.com)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20RHEL-orange.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20aarch64-purple.svg)](https://github.com/sr00t3d/wazuh-installer)

Interactive and unattended Bash CLI to audit readiness, install, optimize, and manage a **Wazuh Single-Node Server (Docker)** and **Wazuh Agent** on Debian/Ubuntu and RHEL/AlmaLinux/Rocky Linux distributions.

## Key Features

- **Read-Only Preflight & Readiness Audit (`--preflight` / `--status`):** inspects OS/architecture, RAM, free disk space, `vm.max_map_count`, Docker Engine & Compose plugin, Wazuh server/agent status, and target ports (`1514`, `1515`, `514`, `55000`, `4443`) in `table`, `json`, or `csv` — no root required.
- **Unattended & Dry-Run Mode (`--unattended`, `--dry-run`):** preview or execute automated server/agent deployments in CI/CD, Ansible, or cloud-init via `WAZUH_*` environment variables.
- **Wazuh Single-Node Server (Docker):** installs Docker Engine + Compose, persists `vm.max_map_count=262144`, generates official TLS certificates, sets a strong BCrypt-hashed `admin` password (custom or auto-generated 20-char), exposes Dashboard HTTPS on port `4443`, and opens firewall ports (`UFW`, `firewalld`, or `iptables`).
- **Wazuh Agent:** detects distro/arch (`x86_64` / `aarch64`), installs official `.deb` / `.rpm` packages, configures Manager IP, agent name/group, optional 2GB Swap or ZRAM memory optimization, and outbound firewall rules.
- **Health Check, Uninstaller & Bilingual i18n:** interactive health checks, clean removal of server/agent components, automatic PT-BR / EN language detection (`--lang=pt|en`), and timestamped logging to `/var/log/wazuh-install.log`.

## Quick Start

```bash
git clone https://github.com/sr00t3d/wazuh-installer.git
cd wazuh-installer
chmod +x wazuh-install.sh

# Audit host readiness without root (table, json, or csv)
./wazuh-install.sh --preflight
./wazuh-install.sh --preflight -o json

# Interactive menu (server, agent, health check, uninstall)
sudo ./wazuh-install.sh

# Preview unattended server deployment (--dry-run)
WAZUH_MODE=server ./wazuh-install.sh --unattended --dry-run

# Unattended server deployment (auto-generated or custom password)
sudo WAZUH_MODE=server WAZUH_ADMIN_PASS='Str0ngP@ss!' ./wazuh-install.sh --unattended

# Unattended agent deployment with 2GB swap
sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.10 WAZUH_AGENT_NAME=web-prod-01 WAZUH_AGENT_GROUP=webservers WAZUH_MEM_OPT=1 ./wazuh-install.sh --unattended
```

## CLI Options & Environment Variables

| Option | Description |
|---|---|
| `--preflight`, `--status` | Audit OS, RAM, disk, `vm.max_map_count`, Docker, ports, and Wazuh state (no root required) |
| `--dry-run` | Preview unattended server/agent deployment plan without modifying the host |
| `-o`, `--output <fmt>` | Output format for `--preflight` / `--dry-run`: `table` (default), `json`, `csv` |
| `--unattended` | Non-interactive deployment driven by `WAZUH_*` environment variables |
| `--lang=pt\|en` | Force UI language (auto-detected from locale by default) |
| `-q`, `--quiet` | Suppress banner header in structured modes |
| `--no-color` | Disable ANSI colors |
| `-V`, `--version` | Show script and Wazuh target version |
| `-h`, `--help` | Show help and exit |

| Variable | Values | Description |
|---|---|---|
| `WAZUH_MODE` | `server` \| `agent` | Target deployment role (required for `--unattended`) |
| `WAZUH_VERSION` | string | Target Wazuh version (default: `4.14.3`) |
| `WAZUH_ADMIN_PASS` | string | Server admin password (min 8 chars; empty = auto-generated) |
| `WAZUH_FORCE_RAM` | `true` \| `false` | Skip low-RAM safety check on server install |
| `WAZUH_MANAGER_IP` | IP / FQDN | Wazuh Manager address (required for agent) |
| `WAZUH_AGENT_NAME` | string | Custom agent name (default: hostname) |
| `WAZUH_AGENT_GROUP` | string | Agent group (default: `default`) |
| `WAZUH_MEM_OPT` | `1` \| `2` \| `3` | Agent memory optimization: `1`=swap, `2`=zram, `3`=none |

## Real Output Example

### Host Preflight Audit (`./wazuh-install.sh --preflight --no-color`)

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

### Structured JSON Preflight (`./wazuh-install.sh --preflight -o json`)

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

### Unattended Agent Dry-Run (`WAZUH_MODE=agent ... ./wazuh-install.sh --unattended --dry-run -o json`)

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

## License

Licensed under the [Apache License 2.0](LICENSE).
