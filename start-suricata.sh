#!/bin/sh
# Скрипт запуска Suricata для мониторинга bridge интерфейса Docker сети

# Ждем запуска контейнеров
sleep 5

# Определяем имя Docker сети - пробуем разные варианты
NETWORK_NAME=""
echo "Поиск Docker сети..."
echo "Доступные сети:"
docker network ls

# Пробуем найти сеть по имени контейнера victim
VICTIM_NETWORK=$(docker inspect victim --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || echo "")
if [ ! -z "$VICTIM_NETWORK" ]; then
  NETWORK_NAME="$VICTIM_NETWORK"
  echo "Найдена сеть через контейнер victim: $NETWORK_NAME"
else
  # Пробуем разные варианты имен
  for name in "lab-infrastructure_labnet" "lr1_labnet" "labnet"; do
    if docker network inspect "$name" >/dev/null 2>&1; then
      NETWORK_NAME="$name"
      echo "Найдена Docker сеть: $NETWORK_NAME"
      break
    fi
  done
  
  if [ -z "$NETWORK_NAME" ]; then
    echo "Поиск сети по паттерну..."
    NETWORK_NAME=$(docker network ls --format '{{.Name}}' | grep -E "(labnet|lab-infrastructure)" | head -1 || echo "")
  fi
fi

if [ -z "$NETWORK_NAME" ]; then
  echo "ОШИБКА: Не удалось определить Docker сеть!"
  echo "Доступные сети:"
  docker network ls
  # Используем первую доступную bridge сеть
  NETWORK_NAME=$(docker network ls --format '{{.Name}}' | grep -v "bridge" | head -1 || echo "")
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

# Проверяем существование интерфейса и его состояние
if [ -z "$BRIDGE" ] || ! ip link show "$BRIDGE" >/dev/null 2>&1; then
  echo "Bridge интерфейс $BRIDGE не найден, ищем доступные bridge интерфейсы..."
  # Ищем все активные bridge интерфейсы (состояние UP)
  BRIDGE=$(ip link show | grep -E "^[0-9]+: br-" | grep -v "state DOWN" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
  
  if [ -z "$BRIDGE" ]; then
    echo "Не найден активный bridge интерфейс, используем первый доступный br-..."
    BRIDGE=$(ip link show | grep -E "^[0-9]+: br-" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
  fi
  
  if [ -z "$BRIDGE" ]; then
    echo "Не найден bridge интерфейс, используем docker0..."
    BRIDGE="docker0"
  fi
fi

# Проверяем состояние интерфейса - используем только активные (UP)
if ip link show "$BRIDGE" 2>/dev/null | grep -q "state DOWN\|NO-CARRIER"; then
  echo "ВНИМАНИЕ: Интерфейс $BRIDGE находится в состоянии DOWN!"
  echo "Ищем активный bridge интерфейс..."
  ACTIVE_BRIDGE=$(ip link show | grep -E "^[0-9]+: br-" | grep "state UP" | head -1 | cut -d: -f2 | tr -d ' ' || echo "")
  if [ ! -z "$ACTIVE_BRIDGE" ]; then
    echo "Найден активный bridge: $ACTIVE_BRIDGE"
    BRIDGE="$ACTIVE_BRIDGE"
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
  ip link show "$BRIDGE" | head -5
  echo "✓ Интерфейс $BRIDGE существует"
  INTERFACE="$BRIDGE"
else
  echo "✗ Интерфейс $BRIDGE не найден!"
  echo "Ищем все bridge интерфейсы..."
  ALL_BRIDGES=$(ip link show | grep -E "^[0-9]+: (br-|docker)" | cut -d: -f2 | tr -d ' ')
  if [ ! -z "$ALL_BRIDGES" ]; then
    INTERFACE=$(echo "$ALL_BRIDGES" | head -1)
    echo "Используем первый найденный bridge: $INTERFACE"
  else
    echo "Bridge интерфейсы не найдены, используем docker0..."
    INTERFACE="docker0"
  fi
fi

# Финальная проверка
if ! ip link show "$INTERFACE" >/dev/null 2>&1; then
  echo "ОШИБКА: Интерфейс $INTERFACE не существует!"
  echo "Список всех интерфейсов:"
  ip link show
  echo "Используем eth0 как fallback..."
  INTERFACE="eth0"
fi

echo "=========================================="
echo "ФИНАЛЬНЫЙ ВЫБОР: Suricata будет мониторить интерфейс: $INTERFACE"
echo "=========================================="
echo ""

# Запускаем Suricata с указанием bridge интерфейса
echo "Запуск Suricata с интерфейсом: $INTERFACE"
echo "Команда: suricata -c /etc/suricata/suricata.yaml -i $INTERFACE --af-packet -l /var/log/suricata"
exec suricata -c /etc/suricata/suricata.yaml -i "$INTERFACE" --af-packet -l /var/log/suricata

