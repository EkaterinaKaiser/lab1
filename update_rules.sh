#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/suricata/update_rules.log"
DATE_NOW=$(date -Iseconds)

log() {
  echo "[$DATE_NOW] $*" | tee -a "$LOG_FILE"
}

log "=== Starting FULL Suricata rules update (official + custom IoC) ==="

# Этап 1: Обновить официальные правила
log "[1/4] Running suricata-update for official rules..."
if ! suricata-update >>"$LOG_FILE" 2>&1; then
  log "ERROR: suricata-update failed"
  exit 1
fi

# Этап 2: Обновить кастомные IoC-фиды и сгенерировать правила
log "[2/4] Fetching and generating custom IoC rules..."
cd /opt/suricata-ioc || { log "ERROR: Project dir not found"; exit 1; }

if ! make fetch generate >>"$LOG_FILE" 2>&1; then
  log "ERROR: Failed to fetch or generate custom IoC rules"
  exit 1
fi

# Этап 3: Проверить конфигурацию
log "[3/4] Testing Suricata config..."
if ! suricata -T -c /etc/suricata/suricata.yaml >>"$LOG_FILE" 2>&1; then
  log "ERROR: Suricata config test failed — NOT reloading!"
  exit 1
fi

# Этап 4: Перезагрузить службу
log "[4/4] Reloading Suricata..."
if systemctl reload suricata 2>>"$LOG_FILE"; then
  log "SUCCESS: Suricata reloaded with updated official + custom rules"
else
  log "WARNING: reload failed, trying restart..."
  systemctl restart suricata
  log "INFO: Suricata restarted"
fi