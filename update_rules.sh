#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/suricata/update_rules.log"
DATE_NOW=$(date -Iseconds)

log() {
  echo "[$DATE_NOW] $*" | tee -a "$LOG_FILE"
}

log "=== Starting FULL Suricata rules update (official + custom IoC) ==="

# Этап 1: Обновить индекс источников правил
log "[1/5] Updating suricata-update sources index..."
if ! suricata-update update-sources >>"$LOG_FILE" 2>&1; then
  log "WARNING: Failed to update sources index, continuing..."
fi

# Этап 2: Включить и обновить официальные правила (ET Open + PT Security)
log "[2/5] Enabling and updating official rules sources..."

# Включить ET Open (если еще не включен)
if ! suricata-update list-enabled-sources 2>/dev/null | grep -q "et/open"; then
  log "Enabling ET Open rules..."
  suricata-update enable-source et/open >>"$LOG_FILE" 2>&1 || log "WARNING: Failed to enable ET Open"
fi

# Включить Positive Technologies rules (если доступен)
if suricata-update list-sources 2>/dev/null | grep -qi "pt"; then
  PT_SOURCE=$(suricata-update list-sources 2>/dev/null | grep -i "pt" | head -1 | awk '{print $1}')
  if [ -n "$PT_SOURCE" ] && ! suricata-update list-enabled-sources 2>/dev/null | grep -q "$PT_SOURCE"; then
    log "Enabling Positive Technologies rules: $PT_SOURCE"
    suricata-update enable-source "$PT_SOURCE" >>"$LOG_FILE" 2>&1 || log "WARNING: Failed to enable PT rules"
  fi
else
  log "INFO: Positive Technologies source not found in available sources"
  log "INFO: You may need to add it manually: suricata-update enable-source pt/open"
fi

# Загрузить официальные правила
log "Downloading official rules..."
if ! suricata-update >>"$LOG_FILE" 2>&1; then
  log "ERROR: suricata-update failed"
  exit 1
fi

# Этап 3: Обновить кастомные IoC-фиды и сгенерировать правила
log "[3/5] Fetching and generating custom IoC rules..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { log "ERROR: Cannot change to script directory"; exit 1; }

if ! ./fetch_feeds.sh >>"$LOG_FILE" 2>&1; then
  log "ERROR: Failed to fetch IoC feeds"
  exit 1
fi

if ! python3 generate_custom_ioc_rules.py >>"$LOG_FILE" 2>&1; then
  log "ERROR: Failed to generate custom IoC rules"
  exit 1
fi

# Этап 4: Проверить конфигурацию
log "[4/5] Testing Suricata config..."
SURICATA_CONFIG="${SURICATA_CONFIG:-/etc/suricata/suricata.yaml}"
if [ ! -f "$SURICATA_CONFIG" ]; then
  SURICATA_CONFIG="suricata.yaml"
fi

if ! suricata -T -c "$SURICATA_CONFIG" >>"$LOG_FILE" 2>&1; then
  log "ERROR: Suricata config test failed — NOT reloading!"
  exit 1
fi

# Этап 5: Перезагрузить службу (если запущена как сервис)
log "[5/5] Reloading Suricata..."
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet suricata 2>/dev/null; then
  if systemctl reload suricata 2>>"$LOG_FILE"; then
    log "SUCCESS: Suricata reloaded with updated official + custom rules"
  else
    log "WARNING: reload failed, trying restart..."
    systemctl restart suricata 2>>"$LOG_FILE" || log "WARNING: Failed to restart Suricata"
    log "INFO: Suricata restarted"
  fi
else
  log "INFO: Suricata service not running or systemctl not available"
  log "INFO: Rules updated successfully. Restart Suricata manually to apply changes."
fi

log "=== Rules update completed successfully ==="