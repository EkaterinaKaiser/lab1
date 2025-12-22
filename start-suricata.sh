#!/bin/sh
# Скрипт запуска Suricata для мониторинга bridge интерфейса Docker сети

# Ждем запуска контейнеров
sleep 5

# Определяем имя Docker сети
NETWORK_NAME="lab-infrastructure_labnet"

# Получаем имя bridge интерфейса
BRIDGE=$(docker network inspect $NETWORK_NAME --format='{{range $k, $v := .Options}}{{if eq $k "com.docker.network.bridge.name"}}{{$v}}{{end}}{{end}}' 2>/dev/null || echo "")

# Если имя не задано, используем стандартное имя
if [ -z "$BRIDGE" ] || [ "$BRIDGE" = "br-" ]; then
  BRIDGE="br-$(docker network inspect $NETWORK_NAME --format='{{.Id}}' 2>/dev/null | cut -c1-12)"
fi

# Проверяем существование интерфейса
if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  echo "Bridge интерфейс $BRIDGE не найден, пробуем docker0..."
  BRIDGE="docker0"
fi

# Если docker0 тоже не существует, используем первый доступный bridge
if ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  BRIDGE=$(ip link show | grep -E "^[0-9]+: br-" | head -1 | cut -d: -f2 | tr -d ' ' || echo "docker0")
fi

echo "Suricata будет мониторить bridge интерфейс: $BRIDGE"
echo "Доступные интерфейсы:"
ip link show | grep -E "^[0-9]+:" | head -10

# Запускаем Suricata с указанием bridge интерфейса
exec suricata -c /etc/suricata/suricata.yaml -i "$BRIDGE" --af-packet -l /var/log/suricata

