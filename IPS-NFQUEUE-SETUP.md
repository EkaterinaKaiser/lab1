# Настройка Suricata в режиме IPS с NFQUEUE

## Ответы на вопросы

### 1. Используются ли правила Emerging Threats Open?

**Да, правила Emerging Threats Open используются в проекте!**

Правила ET Open загружаются автоматически через `suricata-update` в GitHub Actions workflow (этап "Update Suricata rules"). 

В конфигурации `suricata.yaml` они указаны как:
```yaml
rule-files:
  - custom_ioc.rules    # Кастомные правила (первый приоритет)
  - custom.rules        # Базовые правила (блокировка ICMP)
  - suricata.rules     # Правила ET Open и PT Security (загружаются через suricata-update)
```

Правила ET Open сохраняются в `/var/lib/suricata/rules/suricata.rules` и копируются в `/etc/suricata/rules/suricata.rules`.

### 2. Как запустить Suricata в режиме IPS с NFQUEUE?

## Настройка Suricata в режиме IPS с NFQUEUE

### Шаг 1: Обновить конфигурацию Suricata

Конфигурация уже обновлена в `suricata.yaml`:
```yaml
nfq:
  mode: accept
  repeat-mark: 1
  repeat-mask: 1
  bypass-mark: 2
  bypass-mask: 2
  queue-balance: [0, 1, 2, 3]
  queue-max-len: 1024
```

### Шаг 2: Настроить iptables для перенаправления трафика через NFQUEUE

Используйте скрипт `setup-nfqueue.sh`:
```bash
sudo ./setup-nfqueue.sh
```

Скрипт:
- Определяет IP адреса контейнеров attacker и victim
- Определяет bridge интерфейс Docker сети
- Добавляет правила iptables для перенаправления трафика через NFQUEUE (очереди 0-3)

### Шаг 3: Запустить Suricata в режиме IPS

**Вариант 1: Через docker-compose (рекомендуется)**
```bash
docker-compose up -d suricata
```

Контейнер Suricata автоматически запустится в режиме IPS с NFQUEUE.

**Вариант 2: Вручную на хосте**
```bash
suricata -c /etc/suricata/suricata.yaml -q 0 -q 1 -q 2 -q 3 -l /var/log/suricata
```

Где:
- `-q 0 -q 1 -q 2 -q 3` - очереди NFQUEUE для балансировки нагрузки
- `-l /var/log/suricata` - директория для логов

### Шаг 4: Проверить работу

1. Проверьте, что Suricata запущена:
```bash
ps aux | grep suricata
```

2. Проверьте правила iptables:
```bash
sudo iptables -L FORWARD -n -v | grep NFQUEUE
```

3. Проверьте логи Suricata:
```bash
tail -f /var/log/suricata/suricata.log
```

4. Проверьте события в eve.json:
```bash
tail -f /var/log/suricata/eve.json | jq '.'
```

## Как это работает

1. **iptables** перехватывает трафик между контейнерами и перенаправляет его в NFQUEUE (очереди 0-3)
2. **Suricata** читает пакеты из NFQUEUE и анализирует их по правилам
3. Если правило с действием `drop` срабатывает, Suricata блокирует пакет
4. Если правило с действием `pass` срабатывает или правило не найдено, пакет пропускается

## Важные замечания

- Suricata должна работать в режиме `network_mode: host` для доступа к NFQUEUE
- Правила iptables должны быть настроены ДО запуска Suricata
- Для блокировки ICMP правило `drop icmp` должно быть в файле правил
- HTTP трафик должен иметь правило `pass http` для разрешения

## Порядок запуска

1. Запустить контейнеры: `docker-compose up -d victim attacker`
2. Настроить NFQUEUE: `sudo ./setup-nfqueue.sh`
3. Запустить Suricata: `docker-compose up -d suricata`
4. Проверить логи: `tail -f /var/log/suricata/eve.json`
