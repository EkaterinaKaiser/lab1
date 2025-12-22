#!/bin/bash
# Скрипт для настройки iptables для блокировки ICMP через Suricata
# ВНИМАНИЕ: Этот скрипт требует прав root и должен выполняться на хосте

set -e

echo "Настройка iptables для блокировки ICMP через Suricata..."

# Получаем IP адрес контейнера victim
VICTIM_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' victim 2>/dev/null || echo "")

if [ -z "$VICTIM_IP" ]; then
    echo "Ошибка: Контейнер victim не найден. Убедитесь, что контейнеры запущены."
    exit 1
fi

echo "IP адрес victim: $VICTIM_IP"

# Получаем имя Docker сети из контейнера victim
NETWORK_NAME=$(docker inspect victim --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || echo "labnet")

echo "Имя Docker сети: $NETWORK_NAME"

# Блокируем ICMP пакеты к victim через iptables
# Трафик между контейнерами в одной Docker сети проходит через bridge
# Нужно блокировать на уровне FORWARD цепочки
echo "Добавление правил iptables для блокировки ICMP к $VICTIM_IP..."

# Удаляем старые правила, если они есть
iptables -D DOCKER-USER -p icmp -d $VICTIM_IP -j DROP 2>/dev/null || true
iptables -D FORWARD -p icmp -d $VICTIM_IP -j DROP 2>/dev/null || true

# Получаем имя bridge интерфейса Docker сети
BRIDGE_NAME=$(docker network inspect $NETWORK_NAME --format='{{range $k, $v := .Options}}{{if eq $k "com.docker.network.bridge.name"}}{{$v}}{{end}}{{end}}' 2>/dev/null || echo "")
if [ -z "$BRIDGE_NAME" ]; then
  # Если имя bridge не задано, используем стандартное имя
  BRIDGE_NAME="br-$(docker network inspect $NETWORK_NAME --format='{{.Id}}' 2>/dev/null | cut -c1-12)"
fi

echo "Bridge интерфейс: $BRIDGE_NAME"

# Блокируем ICMP на уровне FORWARD (трафик между контейнерами)
# Используем несколько правил для надежности
RULE_ADDED=0

# Правило 1: блокируем ICMP к victim в цепочке FORWARD
if iptables -I FORWARD 1 -p icmp -d $VICTIM_IP -j DROP 2>/dev/null; then
  echo "✓ Правило добавлено в цепочку FORWARD (ICMP -> $VICTIM_IP)"
  RULE_ADDED=1
fi

# Правило 2: блокируем ICMP через bridge интерфейс (если существует)
if [ ! -z "$BRIDGE_NAME" ] && ip link show $BRIDGE_NAME >/dev/null 2>&1; then
  if iptables -I FORWARD 1 -i $BRIDGE_NAME -p icmp -d $VICTIM_IP -j DROP 2>/dev/null; then
    echo "✓ Правило добавлено для bridge $BRIDGE_NAME"
    RULE_ADDED=1
  fi
fi

# Правило 3: блокируем в цепочке DOCKER-USER (если существует)
if iptables -L DOCKER-USER >/dev/null 2>&1; then
  if iptables -I DOCKER-USER 1 -p icmp -d $VICTIM_IP -j DROP 2>/dev/null; then
    echo "✓ Правило добавлено в цепочку DOCKER-USER"
    RULE_ADDED=1
  fi
fi

if [ $RULE_ADDED -eq 0 ]; then
  echo "✗ Не удалось добавить правило iptables"
  exit 1
fi

# Проверяем, что правило добавлено
echo ""
echo "Проверка добавленных правил:"
echo "Правила в цепочке FORWARD:"
iptables -L FORWARD -n -v 2>/dev/null | grep -E "(icmp|$VICTIM_IP)" | head -5 || echo "Правила не найдены"
echo ""
if iptables -L DOCKER-USER >/dev/null 2>&1; then
  echo "Правила в цепочке DOCKER-USER:"
  iptables -L DOCKER-USER -n -v 2>/dev/null | grep -E "(icmp|$VICTIM_IP)" | head -5 || echo "Правила не найдены"
fi

echo ""
echo "Для удаления правил выполните:"
echo "  iptables -D FORWARD -p icmp -d $VICTIM_IP -j DROP"
if [ ! -z "$BRIDGE_NAME" ]; then
  echo "  iptables -D FORWARD -i $BRIDGE_NAME -p icmp -d $VICTIM_IP -j DROP"
fi
echo "  iptables -D DOCKER-USER -p icmp -d $VICTIM_IP -j DROP"

