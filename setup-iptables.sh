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

# Получаем имя сетевого интерфейса Docker сети
NETWORK_NAME="lr1_labnet"
BRIDGE_NAME=$(docker network inspect $NETWORK_NAME -f '{{range .Options}}{{if eq (index (split . "=") 0) "com.docker.network.bridge.name"}}{{index (split . "=") 1}}{{end}}{{end}}' 2>/dev/null || echo "br-$(docker network inspect $NETWORK_NAME -f '{{.Id}}' | cut -c1-12)")

echo "Имя bridge интерфейса: $BRIDGE_NAME"

# Блокируем ICMP пакеты к victim через iptables
# Это альтернативный способ блокировки, если Suricata не может блокировать напрямую
iptables -I DOCKER-USER -p icmp -d $VICTIM_IP -j DROP 2>/dev/null || \
iptables -I FORWARD -p icmp -d $VICTIM_IP -j DROP

echo "Правило iptables добавлено для блокировки ICMP к $VICTIM_IP"
echo "Для удаления правила выполните:"
echo "  iptables -D DOCKER-USER -p icmp -d $VICTIM_IP -j DROP"
echo "или"
echo "  iptables -D FORWARD -p icmp -d $VICTIM_IP -j DROP"

