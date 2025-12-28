{
  echo "=== 1. Версия Suricata ==="
  suricata -V

  echo -e "\n=== 2. Запущенные процессы Suricata ==="
  ps aux | grep -v grep | grep -E 'suricata'

  echo -e "\n=== 3. Состояние nfqueue ==="
  if [ -f /proc/net/netfilter/nfnetlink_queue ]; then
    echo "Очереди:"
    cat /proc/net/netfilter/nfnetlink_queue
  else
    echo "/proc/net/netfilter/nfnetlink_queue — отсутствует (модуль не загружен)"
  fi

  echo -e "\n=== 4. iptables: DOCKER-USER и PRE-SURICATA ==="
  sudo iptables -L DOCKER-USER -n -v
  echo "---"
  sudo iptables -L PRE-SURICATA -n -v 2>/dev/null || echo "Цепочка PRE-SURICATA не существует"

  echo -e "\n=== 5. Список bridge-интерфейсов ==="
  ip -br link show type bridge

  echo -e "\n=== 6. Сеть labnet ==="
  docker network inspect labnet --format='ID: {{.Id}}\nSubnet: {{(index .IPAM.Config 0).Subnet}}\nGateway: {{(index .IPAM.Config 0).Gateway}}'

  echo -e "\n=== 7. IP-адреса контейнеров ==="
  docker inspect attacker victim --format='{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'

  echo -e "\n=== 8. Правила Suricata (custom.rules) ==="
  echo "[custom.rules]"
  cat /etc/suricata/rules/custom.rules 2>/dev/null || echo "❌ Файл не найден"

  echo -e "\n=== 9. HOME_NET из suricata.yaml ==="
  grep -A2 -B2 'HOME_NET\|home-net' /etc/suricata/suricata.yaml 2>/dev/null || echo "Не найдено"

  echo -e "\n=== 10. Последние 5 событий eve.json (drop/alert) ==="
  sudo tail -n 100 /var/log/suricata/eve.json | jq -r 'select(.event_type=="drop" or .event_type=="alert") | .timestamp, .alert?.signature // .[], "---"' 2>/dev/null | head -20

  echo -e "\n=== 11. Статистика Suricata (decoder, detect) ==="
  sudo tail -n 100 /var/log/suricata/eve.json | grep -A1 -B1 '"decoder":\|\"detect\":' | tail -5

  echo -e "\n=== 12. Тест: отправляем 1 ICMP-пакет и смотрим, попадает ли он в очередь ==="
  echo "→ Запуск ping в фоне..."
  timeout 2 docker exec attacker ping -c 1 -W 1 victim >/dev/null 2>&1 &
  sleep 1
  echo "→ Состояние очереди ДО и ПОСЛЕ:"
  echo "BEFORE:" && sudo cat /proc/net/netfilter/nfnetlink_queue 2>/dev/null || echo "пусто"
  sleep 2
  echo "AFTER:" && sudo cat /proc/net/netfilter/nflink_queue 2>/dev/null || echo "пусто"

  echo -e "\n=== 13. Проверка: может, Suricata в IDS-режиме? ==="
  sudo grep -i "engine mode\|IPS mode\|NFQ" /var/log/suricata/suricata.log | tail -5

  echo -e "\n=== 14. Проверка: правила загружены? ==="
  sudo grep -i "rules.*loaded" /var/log/suricata/suricata.log | tail -3

} 2>&1 | tee /tmp/suricata-diag.txt && echo -e "\n✅ Диагностика сохранена в /tmp/suricata-diag.txt"