#!/bin/bash
set -e

echo "=== Настройка iptables для Suricata IPS (NFQUEUE) ==="

# Удаляем потенциально существующие старые правила (без ошибок, если их нет)
sudo iptables -D DOCKER-USER -p icmp -d 172.20.0.2 -j DROP 2>/dev/null || true
sudo iptables -D FORWARD -p icmp -d 172.20.0.2 -j DROP 2>/dev/null || true

# Удаляем дубликаты NFQUEUE-правил (если остались от прошлых запусков)
while sudo iptables -C DOCKER-USER -j NFQUEUE --queue-balance 0:3 --queue-bypass 2>/dev/null; do
  echo "Удаление дублирующегося NFQUEUE-правила..."
  sudo iptables -D DOCKER-USER -j NFQUEUE --queue-balance 0:3 --queue-bypass
done

# Добавляем ЕДИНСТВЕННОЕ правило: весь трафик между контейнерами → Suricata через NFQUEUE
echo "Добавление NFQUEUE-правила для цепочки DOCKER-USER..."
sudo iptables -I DOCKER-USER -j NFQUEUE --queue-balance 0:3 --queue-bypass

echo "Правила iptables успешно настроены для Suricata IPS"
echo "Теперь Suricata будет получать все пакеты и принимать решение о блокировке."