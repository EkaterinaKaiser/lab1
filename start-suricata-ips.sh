#!/bin/sh
# Скрипт запуска Suricata в режиме IPS с NFQUEUE

# Ждем запуска контейнеров и настройки NFQUEUE
sleep 10

# Определяем имя Docker сети через контейнер victim
NETWORK_NAME=$(docker inspect victim --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || echo "")

if [ -z "$NETWORK_NAME" ]; then
  # Пробуем разные варианты имен
  for name in "lab-infrastructure_labnet" "lr1_labnet" "labnet"; do
    if docker network inspect "$name" >/dev/null 2>&1; then
      NETWORK_NAME="$name"
      break
    fi
  done
fi

echo "=========================================="
echo "Запуск Suricata в режиме IPS с NFQUEUE"
echo "=========================================="
echo "Docker сеть: $NETWORK_NAME"
echo ""

# Получаем bridge интерфейс
BRIDGE=$(docker network inspect "$NETWORK_NAME" --format='{{range $k, $v := .Options}}{{if eq $k "com.docker.network.bridge.name"}}{{$v}}{{end}}{{end}}' 2>/dev/null || echo "")

if [ -z "$BRIDGE" ] || [ "$BRIDGE" = "br-" ]; then
  NETWORK_ID=$(docker network inspect "$NETWORK_NAME" --format='{{.Id}}' 2>/dev/null || echo "")
  if [ ! -z "$NETWORK_ID" ]; then
    BRIDGE="br-$(echo "$NETWORK_ID" | cut -c1-12)"
  fi
fi

# Проверяем активные bridge интерфейсы
if [ -z "$BRIDGE" ] || ! ip link show "$BRIDGE" 2>/dev/null | grep -q "state UP"; then
  BRIDGE=$(ip link show | grep -E "^[0-9]+: br-" | grep "state UP" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
fi

echo "Bridge интерфейс: $BRIDGE"
echo ""

# Проверяем, что NFQUEUE настроен
echo "Проверка правил NFQUEUE в iptables:"
if iptables -L FORWARD -n -v 2>/dev/null | grep -q "NFQUEUE"; then
  echo "✓ Правила NFQUEUE найдены"
  iptables -L FORWARD -n -v 2>/dev/null | grep "NFQUEUE" | head -5
else
  echo "⚠ ВНИМАНИЕ: Правила NFQUEUE не найдены!"
  echo "Запустите скрипт setup-nfqueue.sh для настройки NFQUEUE"
  echo "Продолжаем запуск Suricata, но блокировка может не работать..."
fi
echo ""

# Запускаем Suricata в режиме IPS с NFQUEUE
# -q 0 -q 1 -q 2 -q 3: очереди NFQUEUE для балансировки нагрузки
echo "Запуск Suricata в режиме IPS с NFQUEUE (очереди 0-3)..."
echo "Команда: suricata -c /etc/suricata/suricata.yaml -q 0 -q 1 -q 2 -q 3 -l /var/log/suricata"
echo ""

exec suricata -c /etc/suricata/suricata.yaml -q 0 -q 1 -q 2 -q 3 -l /var/log/suricata
