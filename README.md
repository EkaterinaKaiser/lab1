# Лабораторный стенд с Suricata

Этот проект содержит docker-compose конфигурацию для развертывания лабораторного стенда с тремя контейнерами:
- **attacker** - Kali Linux контейнер для атак
- **victim** - Alpine Linux контейнер с HTTP сервером
- **suricata** - IDS/IPS система для мониторинга и блокировки трафика

## Структура проекта

```
.
├── docker-compose.yml      # Конфигурация Docker Compose
├── suricata.yaml           # Конфигурация Suricata
├── rules/
│   └── custom.rules        # Правила Suricata для блокировки ICMP
├── logs/                   # Логи Suricata (создается автоматически)
├── setup-iptables.sh       # Скрипт для настройки iptables (опционально)
└── .github/
    └── workflows/
        └── deploy.yml      # GitHub Actions workflow для деплоя
```

## Локальный запуск

1. Убедитесь, что установлены Docker и Docker Compose
2. Запустите стенд:
```bash
docker-compose up -d
```

3. Проверьте статус контейнеров:
```bash
docker-compose ps
```

4. Проверьте логи Suricata:
```bash
docker-compose logs suricata
```

## Тестирование

1. Подключитесь к контейнеру attacker:
```bash
docker exec -it attacker bash
```

2. Попробуйте выполнить ping на victim (должен быть заблокирован):
```bash
ping victim
```

3. Попробуйте выполнить HTTP запрос (должен работать):
```bash
curl http://victim
```

## Деплой через GitHub Actions

Для автоматического деплоя на виртуальную машину через GitHub Actions необходимо настроить следующие secrets в репозитории:

1. `SSH_PRIVATE_KEY` - приватный SSH ключ для подключения к серверу
2. `SSH_HOST` - IP адрес сервера (178.72.153.208)
3. `SSH_USER` - пользователь для SSH подключения (обычно `root` или `ubuntu`)

### Настройка secrets в GitHub:

1. Перейдите в Settings → Secrets and variables → Actions
2. Добавьте новые secrets:
   - `SSH_PRIVATE_KEY`: ваш приватный SSH ключ
   - `SSH_HOST`: `178.72.153.208`
   - `SSH_USER`: имя пользователя на сервере

После настройки secrets, при каждом push в main/master ветку будет автоматически выполняться деплой на виртуальную машину.

## Конфигурация Suricata

Suricata настроена для блокировки ICMP пакетов к контейнеру victim. Правила находятся в файле `rules/custom.rules`.

Логи Suricata сохраняются в директории `logs/` в формате JSON (eve.json) и текстовом формате (suricata.log).

### Блокировка ICMP

Для блокировки ICMP пакетов используется два подхода:

1. **Правила Suricata** - Suricata обнаруживает и логирует ICMP пакеты согласно правилам в `rules/custom.rules`
2. **iptables (опционально)** - Для реальной блокировки ICMP на уровне хоста можно использовать скрипт `setup-iptables.sh`:
   ```bash
   sudo ./setup-iptables.sh
   ```

   Этот скрипт автоматически определяет IP адрес контейнера victim и добавляет правило iptables для блокировки ICMP пакетов.

## Примечания

- Контейнер victim запускает простой HTTP сервер на порту 80
- ICMP трафик к victim блокируется правилами Suricata
- HTTP трафик разрешен и должен работать нормально
- Все контейнеры находятся в одной Docker сети `labnet`

