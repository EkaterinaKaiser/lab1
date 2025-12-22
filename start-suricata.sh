#!/bin/sh
# Скрипт запуска Suricata для мониторинга bridge интерфейса Docker сети

# Ждем запуска контейнеров
sleep 5

# Определяем имя Docker сети - пробуем разные варианты
NETWORK_NAME=""
for name in "lab-infrastructure_labnet" "lr1_labnet" "labnet"; do
  if docker network inspect "$name" >/dev/null 2>&1; then
    NETWORK_NAME="$name"
    echo "Найдена Docker сеть: $NETWORK_NAME"
    break
  fi
done

if [ -z "$NETWORK_NAME" ]; then
  echo "Не удалось найти Docker сеть, пробуем первую доступную..."
  NETWORK_NAME=$(docker network ls --format '{{.Name}}' | grep -E "(labnet|bridge)" | head -1 || echo "")
fi

if [ -z "$NETWORK_NAME" ]; then
  echo "ОШИБКА: Не удалось определить Docker сеть!"
  echo "Доступные сети:"
  docker network ls
  NETWORK_NAME="docker0"
fi

echo "Используем сеть: $NETWORK_NAME"

# Получаем имя bridge интерфейса
BRIDGE=$(docker network inspect "$NETWORK_NAME" --format='{{range $k, $v := .Options}}{{if eq $k "com.docker.network.bridge.name"}}{{$v}}{{end}}{{end}}' 2>/dev/null || echo "")

# Если имя не задано, используем стандартное имя
if [ -z "$BRIDGE" ] || [ "$BRIDGE" = "br-" ]; then
  NETWORK_ID=$(docker network inspect "$NETWORK_NAME" --format='{{.Id}}' 2>/dev/null || echo "")
  if [ ! -z "$NETWORK_ID" ]; then
    BRIDGE="br-$(echo "$NETWORK_ID" | cut -c1-12)"
  fi
fi

# Проверяем существование интерфейса
if [ -z "$BRIDGE" ] || ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  echo "Bridge интерфейс $BRIDGE не найден, ищем доступные bridge интерфейсы..."
  # Ищем все bridge интерфейсы
  BRIDGE=$(ip link show | grep -E "^[0-9]+: (br-|docker)" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
  
  if [ -z "$BRIDGE" ]; then
    echo "Не найден bridge интерфейс, используем docker0..."
    BRIDGE="docker0"
  fi
fi

echo "=========================================="
echo "Suricata будет мониторить bridge интерфейс: $BRIDGE"
echo "=========================================="
echo "Доступные интерфейсы на хосте:"
ip link show | grep -E "^[0-9]+:" | head -15
echo ""
echo "Проверка интерфейса $BRIDGE:"
if ip link show "$BRIDGE" >/dev/null 2>&1; then
  ip link show "$BRIDGE"
  echo "✓ Интерфейс $BRIDGE существует"
else
  echo "✗ Интерфейс $BRIDGE не найден!"
  echo "Используем первый доступный bridge..."
  BRIDGE=$(ip link show | grep -E "^[0-9]+: br-" | head -1 | cut -d: -f2 | tr -d ' ' || echo "eth0")
fi
echo "=========================================="
echo ""

# Запускаем Suricata с указанием bridge интерфейса
echo "Запуск Suricata с интерфейсом: $BRIDGE"
exec suricata -c /etc/suricata/suricata.yaml -i "$BRIDGE" --af-packet -l /var/log/suricata

