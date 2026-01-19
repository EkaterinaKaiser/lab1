#!/bin/bash
# Скрипт для настройки iptables для перенаправления трафика через NFQUEUE к Suricata
# ВНИМАНИЕ: Этот скрипт требует прав root и должен выполняться на хосте

set -e

echo "=== Настройка iptables для режима IPS с NFQUEUE ==="

# Получаем IP адреса контейнеров
VICTIM_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' victim 2>/dev/null || echo "")
ATTACKER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' attacker 2>/dev/null || echo "")

if [ -z "$VICTIM_IP" ] || [ -z "$ATTACKER_IP" ]; then
    echo "Ошибка: Контейнеры victim или attacker не найдены. Убедитесь, что контейнеры запущены."
    exit 1
fi

echo "IP адрес victim: $VICTIM_IP"
echo "IP адрес attacker: $ATTACKER_IP"

# Получаем имя Docker сети
NETWORK_NAME=$(docker inspect victim --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null || echo "labnet")
echo "Имя Docker сети: $NETWORK_NAME"

# Получаем имя bridge интерфейса
BRIDGE_NAME=$(docker network inspect "$NETWORK_NAME" --format='{{range $k, $v := .Options}}{{if eq $k "com.docker.network.bridge.name"}}{{$v}}{{end}}{{end}}' 2>/dev/null || echo "")
if [ -z "$BRIDGE_NAME" ]; then
    NETWORK_ID=$(docker network inspect "$NETWORK_NAME" --format='{{.Id}}' 2>/dev/null || echo "")
    if [ ! -z "$NETWORK_ID" ]; then
        BRIDGE_NAME="br-$(echo "$NETWORK_ID" | cut -c1-12)"
    fi
fi

if [ -z "$BRIDGE_NAME" ]; then
    BRIDGE_NAME=$(ip link show | grep -E "^[0-9]+: br-" | grep "state UP" | head -1 | cut -d: -f2 | tr -d ' ' || echo "docker0")
fi

echo "Bridge интерфейс: $BRIDGE_NAME"

# Удаляем старые правила NFQUEUE, если они есть
echo ""
echo "Удаление старых правил NFQUEUE..."
iptables -D FORWARD -i "$BRIDGE_NAME" -j NFQUEUE --queue-num 0 2>/dev/null || true
iptables -D FORWARD -i "$BRIDGE_NAME" -j NFQUEUE --queue-num 1 2>/dev/null || true
iptables -D FORWARD -i "$BRIDGE_NAME" -j NFQUEUE --queue-num 2 2>/dev/null || true
iptables -D FORWARD -i "$BRIDGE_NAME" -j NFQUEUE --queue-num 3 2>/dev/null || true
iptables -D FORWARD -o "$BRIDGE_NAME" -j NFQUEUE --queue-num 0 2>/dev/null || true
iptables -D FORWARD -o "$BRIDGE_NAME" -j NFQUEUE --queue-num 1 2>/dev/null || true
iptables -D FORWARD -o "$BRIDGE_NAME" -j NFQUEUE --queue-num 2 2>/dev/null || true
iptables -D FORWARD -o "$BRIDGE_NAME" -j NFQUEUE --queue-num 3 2>/dev/null || true

# Добавляем правила для перенаправления трафика через NFQUEUE
echo ""
echo "Добавление правил NFQUEUE для трафика через bridge $BRIDGE_NAME..."

# Перенаправляем входящий трафик к victim через NFQUEUE (балансировка по очередям 0-3)
iptables -I FORWARD 1 -i "$BRIDGE_NAME" -d "$VICTIM_IP" -j NFQUEUE --queue-balance 0:3
echo "✓ Правило добавлено: трафик к victim -> NFQUEUE (0-3)"

# Перенаправляем исходящий трафик от victim через NFQUEUE
iptables -I FORWARD 1 -o "$BRIDGE_NAME" -s "$VICTIM_IP" -j NFQUEUE --queue-balance 0:3
echo "✓ Правило добавлено: трафик от victim -> NFQUEUE (0-3)"

# Перенаправляем трафик от attacker к victim через NFQUEUE
iptables -I FORWARD 1 -i "$BRIDGE_NAME" -s "$ATTACKER_IP" -d "$VICTIM_IP" -j NFQUEUE --queue-balance 0:3
echo "✓ Правило добавлено: трафик attacker -> victim -> NFQUEUE (0-3)"

# Проверяем правила
echo ""
echo "Проверка добавленных правил NFQUEUE:"
iptables -L FORWARD -n -v | grep -E "(NFQUEUE|$VICTIM_IP|$ATTACKER_IP)" | head -10 || echo "Правила не найдены"

echo ""
echo "=== Настройка NFQUEUE завершена ==="
echo ""
echo "ВАЖНО: Suricata должна быть запущена в режиме IPS с NFQUEUE:"
echo "  suricata -c /etc/suricata/suricata.yaml -q 0 -q 1 -q 2 -q 3"
echo ""
echo "Или с указанием интерфейса:"
echo "  suricata -c /etc/suricata/suricata.yaml -i $BRIDGE_NAME -q 0 -q 1 -q 2 -q 3"
echo ""
echo "Для удаления правил выполните:"
echo "  iptables -D FORWARD -i $BRIDGE_NAME -d $VICTIM_IP -j NFQUEUE --queue-balance 0:3"
echo "  iptables -D FORWARD -o $BRIDGE_NAME -s $VICTIM_IP -j NFQUEUE --queue-balance 0:3"
echo "  iptables -D FORWARD -i $BRIDGE_NAME -s $ATTACKER_IP -d $VICTIM_IP -j NFQUEUE --queue-balance 0:3"
