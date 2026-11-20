# Wazuh Automated Installer — Servidor y Agente (`wazuh-install.sh`)

🇺🇸 [English](README.md) | 🇧🇷 [Português (BR)](README-ptbr.md) | 🇪🇸 **Español**

![Portada Wazuh Installer](wazuh-installer-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Wazuh](https://img.shields.io/badge/Wazuh-4.14.3-00b4d8.svg)](https://wazuh.com)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![OS](https://img.shields.io/badge/OS-Debian%20%7C%20RHEL-orange.svg)](https://github.com/sr00t3d/wazuh-installer)
[![Arch](https://img.shields.io/badge/arch-x86__64%20%7C%20aarch64-purple.svg)](https://github.com/sr00t3d/wazuh-installer)

CLI en Bash interactiva y desatendida para auditar requisitos previos, instalar, optimizar y gestionar un **Servidor Wazuh Single-Node (Docker)** y el **Agente Wazuh** en distribuciones Debian/Ubuntu y RHEL/AlmaLinux/Rocky Linux.

## Características Principales

- **Auditoría Preflight sin root (`--preflight` / `--status`):** inspecciona SO/arquitectura, RAM, espacio libre en disco, `vm.max_map_count`, Docker Engine y Compose, estado del servidor/agente Wazuh y puertos objetivo (`1514`, `1515`, `514`, `55000`, `4443`) en formato `table`, `json` o `csv`.
- **Modo Desatendido y Dry-Run (`--unattended`, `--dry-run`):** previsualiza o ejecuta despliegues automatizados de servidor/agente en CI/CD, Ansible o cloud-init mediante variables de entorno `WAZUH_*`.
- **Servidor Wazuh Single-Node (Docker):** instala Docker Engine + Compose, persiste `vm.max_map_count=262144`, genera certificados TLS oficiales, configura una contraseña `admin` segura con hash BCrypt (personalizada o autogenerada de 20 caracteres), expone el Dashboard HTTPS en el puerto `4443` y abre las reglas de firewall (`UFW`, `firewalld` o `iptables`).
- **Agente Wazuh:** detecta la distribución y arquitectura (`x86_64` / `aarch64`), instala los paquetes oficiales `.deb` / `.rpm`, configura la IP del Manager, nombre/grupo del agente, optimización opcional de memoria (Swap de 2GB o ZRAM) y reglas de salida en el firewall.
- **Health Check, Desinstalador e i18n:** verificación de salud de contenedores y agente, eliminación limpia de componentes, detección automática de idioma (`--lang=pt|en`) y registro con marcas de tiempo en `/var/log/wazuh-install.log`.

## Inicio Rápido

```bash
git clone https://github.com/sr00t3d/wazuh-installer.git
cd wazuh-installer
chmod +x wazuh-install.sh

# Auditar la preparación del host sin root (table, json o csv)
./wazuh-install.sh --preflight
./wazuh-install.sh --preflight -o json

# Menú interactivo (servidor, agente, health check, desinstalación)
sudo ./wazuh-install.sh

# Previsualizar despliegue desatendido del servidor (--dry-run)
WAZUH_MODE=server ./wazuh-install.sh --unattended --dry-run

# Despliegue desatendido del servidor con contraseña personalizada
sudo WAZUH_MODE=server WAZUH_ADMIN_PASS='Str0ngP@ss!' ./wazuh-install.sh --unattended

# Despliegue desatendido del agente con Swap de 2GB
sudo WAZUH_MODE=agent WAZUH_MANAGER_IP=10.0.0.10 WAZUH_AGENT_NAME=web-prod-01 WAZUH_AGENT_GROUP=webservers WAZUH_MEM_OPT=1 ./wazuh-install.sh --unattended
```

## Opciones de CLI y Variables de Entorno

| Opción | Descripción |
|---|---|
| `--preflight`, `--status` | Audita SO, RAM, disco, `vm.max_map_count`, Docker, puertos y estado de Wazuh (sin root) |
| `--dry-run` | Simula el plan de despliegue desatendido sin modificar el host |
| `-o`, `--output <fmt>` | Formato de salida para `--preflight` / `--dry-run`: `table` (predeterminado), `json`, `csv` |
| `--unattended` | Ejecución desatendida guiada por variables `WAZUH_*` |
| `--lang=pt\|en` | Fuerza el idioma de la interfaz (detectado automáticamente por defecto) |
| `-q`, `--quiet` | Omite el encabezado en modos estructurados |
| `--no-color` | Desactiva colores ANSI |
| `-V`, `--version` | Muestra la versión del script y de Wazuh objetivo |
| `-h`, `--help` | Muestra la ayuda y sale |

| Variable | Valores | Descripción |
|---|---|---|
| `WAZUH_MODE` | `server` \| `agent` | Rol de despliegue objetivo (obligatorio en `--unattended`) |
| `WAZUH_VERSION` | string | Versión objetivo de Wazuh (predeterminada: `4.14.3`) |
| `WAZUH_ADMIN_PASS` | string | Contraseña del usuario admin (mín. 8 chars; vacío = autogenerada) |
| `WAZUH_FORCE_RAM` | `true` \| `false` | Omite la verificación de RAM baja en el servidor |
| `WAZUH_MANAGER_IP` | IP / FQDN | Dirección del Wazuh Manager (obligatoria para agente) |
| `WAZUH_AGENT_NAME` | string | Nombre del agente (predeterminado: hostname) |
| `WAZUH_AGENT_GROUP` | string | Grupo del agente (predeterminado: `default`) |
| `WAZUH_MEM_OPT` | `1` \| `2` \| `3` | Memoria del agente: `1`=swap, `2`=zram, `3`=ninguna |

## Ejemplo de Salida Real

### Auditoría Preflight (`./wazuh-install.sh --preflight --no-color`)

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

### Salida Estructurada en JSON (`./wazuh-install.sh --preflight -o json`)

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

### Dry-Run de Agente Desatendido (`WAZUH_MODE=agent ... ./wazuh-install.sh --unattended --dry-run -o json`)

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

## Licencia

Licenciado bajo la [Apache License 2.0](LICENSE).
