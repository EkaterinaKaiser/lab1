# Автоматизация сбора и формирования правил Suricata из внешних источников

## Описание проекта

Проект реализует автоматизированный pipeline для сбора Threat Intelligence данных из внешних источников и генерации правил Suricata для блокировки вредоносных IP-адресов, облачных провайдеров и ресурсов, запрещенных в РФ.

### Основные возможности

- Автоматическая загрузка правил от Positive Technologies и Emerging Threats Open
- Сбор IoC (Indicators of Compromise) из множества источников
- Генерация правил Suricata для блокировки IP-адресов
- Автоматическое тестирование и деплой в облако
- Блокировка ICMP трафика при разрешении HTTP

## Структура проекта

```
.
├── fetch_feeds.sh              # Загрузка IoC-фидов из внешних источников
├── generate_custom_ioc_rules.py # Генерация правил Suricata из IoC
├── update_rules.sh             # Полный pipeline обновления правил
├── Makefile                    # Автоматизация всех этапов
├── suricata.yaml               # Конфигурация Suricata
├── docker-compose.yml          # Конфигурация Docker контейнеров
├── rules/
│   └── custom.rules            # Базовые правила (блокировка ICMP)
└── .github/workflows/
    └── deploy.yml              # GitHub Actions workflow для деплоя
```

## Порядок загрузки правил Suricata

Правила Suricata загружаются в строгом порядке, определенном в `suricata.yaml`:

```yaml
rule-files:
  - custom_ioc.rules    # 1. Кастомные правила (с правилами pass для HTTP)
  - custom.rules        # 2. Базовые правила (блокировка ICMP)
  - suricata.rules     # 3. Официальные правила (ET Open, PT Security)
```

### 1. custom_ioc.rules (первый приоритет)

**Содержимое:**
- Правила `pass` для HTTP/HTTPS трафика (SID: 8000001-8000006)
- Правила `pass` для TCP/UDP трафика к HOME_NET
- Правила `drop` для заблокированных IP из IoC-источников (SID: 9000000+)

**Источники данных:**
- Feodo Tracker (botnet C&C серверы)
- URLhaus (malware IPs)
- Botvrij.eu (IoC список)
- Google Cloud, AWS, Azure, Cloudflare, DigitalOcean (облачные провайдеры)
- Antifilter, Zapret-info, Роскомсвобода (ресурсы, запрещенные в РФ)

**Почему первый:** Правила `pass` должны обрабатываться первыми, чтобы разрешить легитимный трафик до применения блокирующих правил.

### 2. custom.rules (второй приоритет)

**Содержимое:**
- Правило `drop icmp any any -> any any` (SID: 1000001)

**Назначение:** Блокировка всего ICMP трафика для демонстрации работы IPS.

### 3. suricata.rules (третий приоритет)

**Содержимое:**
- Официальные правила от ET Open (Emerging Threats)
- Правила от PT Security (Positive Technologies), если включены
- Десятки тысяч правил для детектирования различных атак

**Генерация:** Создается автоматически через `suricata-update` при деплое.

## Процесс обновления правил

### Локально (через Makefile)

```bash
make all
```

Выполняет следующие этапы:

1. **fetch** - Загрузка IoC-фидов из внешних источников
2. **generate** - Генерация `custom_ioc.rules` из загруженных фидов
3. **test** - Проверка конфигурации Suricata
4. **deploy** - Перезагрузка Suricata для применения правил
5. **status** - Проверка статуса Suricata

### В облаке (через GitHub Actions)

При push в ветку `main` автоматически выполняется:

1. **Cleanup** - Очистка предыдущего деплоя
2. **Copy files** - Копирование файлов на сервер
3. **Install Suricata** - Установка Suricata и зависимостей
4. **Update Rules** - Обновление правил:
   - Обновление индекса источников (`suricata-update update-sources`)
   - Включение ET Open rules
   - Попытка включения PT Security rules
   - Загрузка официальных правил (`suricata-update`)
   - Загрузка IoC-фидов (`fetch_feeds.sh`)
   - Генерация кастомных правил (`generate_custom_ioc_rules.py`)
   - Проверка конфигурации
5. **Start Suricata** - Запуск Suricata в IPS-режиме (NFQUEUE)
6. **Deploy Containers** - Запуск Docker контейнеров (attacker, victim)
7. **Configure iptables** - Настройка iptables для интеграции с Suricata
8. **Verify Deployment** - Проверка статуса всех компонентов
9. **Test Protection** - Тестирование блокировки ICMP и разрешения HTTP
10. **Test IoC Rules** - Тестирование блокировки по IoC правилам

## Тестирование

### Тест 1: Блокировка ICMP

**Ожидаемый результат:** ICMP пакеты должны блокироваться

**Процесс:**
1. Проверка наличия правила в `custom.rules`
2. Отправка ICMP пакета от `attacker` к `victim`
3. Проверка, что пакет не прошел
4. Анализ событий в логах Suricata

**Правило:**
```
drop icmp any any -> any any (msg:"ICMP blocked"; sid:1000001; rev:1;)
```

### Тест 2: Разрешение HTTP

**Ожидаемый результат:** HTTP трафик должен проходить

**Процесс:**
1. Ожидание запуска HTTP сервера в контейнере `victim`
2. Отправка HTTP запроса от `attacker` к `victim`
3. Проверка успешного подключения
4. Анализ событий в логах Suricata

**Правила (в custom_ioc.rules):**
```
pass http any any -> $HOME_NET any (msg:"Allow HTTP traffic to HOME_NET"; sid:8000001; rev:1;)
pass tcp any any -> $HOME_NET 80 (msg:"Allow HTTP on port 80"; sid:8000002; rev:1;)
pass tcp any any -> $HOME_NET any (msg:"Allow TCP traffic to HOME_NET"; sid:8000005; rev:1;)
```

### Тест 3: Блокировка по IoC правилам

**Ожидаемый результат:** Трафик от заблокированных IP должен блокироваться

**Процесс:**
1. Выбор тестового IP из заблокированных источников (например, Google Cloud)
2. Попытка отправки трафика к заблокированному IP
3. Проверка событий блокировки в логах Suricata
4. Проверка статистики правил

**Правила (пример):**
```
drop ip 8.8.8.8 any -> $HOME_NET any (msg:"[IPS] Google Cloud IP 8.8.8.8 -> HOME_NET"; classtype:policy-violation; sid:9300001; rev:1;)
```

## Источники IoC данных

### Вредоносные IP-адреса
- **Feodo Tracker** - botnet C&C серверы (Dridex, Emotet, TrickBot, QakBot)
- **URLhaus** - IP-адреса для распространения malware
- **Botvrij.eu** - IoC список от голландской инициативы

### Облачные провайдеры
- **Google Cloud** - официальные IP-диапазоны
- **AWS** - официальные IP-диапазоны
- **Azure** - официальные IP-диапазоны
- **Cloudflare** - официальные IP-диапазоны
- **DigitalOcean** - официальные IP-диапазоны

### Ресурсы, запрещенные в РФ
- **Antifilter** - списки IP из реестра РКН
- **Zapret-info** - реестр запрещенных ресурсов РФ
- **Роскомсвобода** - API реестра заблокированных ресурсов

## Диапазоны SID (Signature ID)

- `8000001-8000006`: Правила pass для HTTP/TCP/UDP
- `9000000-9099999`: Feodo Tracker
- `9100000-9199999`: URLhaus
- `9200000-9299999`: Botvrij.eu
- `9300000-9399999`: Google Cloud
- `9400000-9499999`: AWS
- `9500000-9599999`: Azure
- `9600000-9699999`: Cloudflare
- `9700000-9799999`: DigitalOcean
- `9800000-9899999`: Antifilter
- `9900000-9909999`: Zapret-info
- `9910000-9919999`: Роскомсвобода
- `1000001`: ICMP блокировка (custom.rules)

## Конфигурация

### HOME_NET

Определяет защищаемую сеть:
```yaml
HOME_NET: "[172.16.0.0/12]"
```

Этот диапазон покрывает стандартные Docker сети, включая:
- `172.16.0.0/12` - стандартный диапазон Docker
- `172.20.0.0/16` - сеть контейнеров (labnet)

### NFQUEUE

Suricata работает в IPS-режиме через NFQUEUE:
```yaml
nfq:
  mode: accept
```

Трафик направляется через iptables цепочку `PRE-SURICATA` в очередь NFQUEUE 0.

## Использование

### Локальная разработка

```bash
# Загрузка фидов
./fetch_feeds.sh

# Генерация правил
python3 generate_custom_ioc_rules.py

# Тестирование конфигурации
suricata -T -c suricata.yaml
```

### Полный цикл через Makefile

```bash
# Все этапы
make all

# Отдельные этапы
make fetch        # Загрузка фидов
make generate     # Генерация правил
make test         # Тестирование
make deploy       # Применение правил
make status       # Проверка статуса
```

### Обновление правил

```bash
# Полное обновление (официальные + кастомные)
./update_rules.sh

# Или через Makefile
make all
```

## Деплой в облако

Проект настроен для автоматического деплоя через GitHub Actions. При push в `main`:

1. Автоматически устанавливается Suricata
2. Загружаются и обновляются правила
3. Запускается Suricata в IPS-режиме
4. Разворачиваются тестовые контейнеры
5. Выполняются автоматические тесты

Подробнее см. `DEPLOY.md`.

## Логирование

События Suricata сохраняются в:
- `/var/log/suricata/eve.json` - события в формате JSON
- `/var/log/suricata/suricata.log` - текстовый лог
- `/var/log/suricata/update_rules.log` - лог обновления правил

## Требования

- Python 3.6+
- Suricata 8.x
- suricata-update
- curl
- jq (опционально, для лучшей поддержки JSON-источников)
- Docker и Docker Compose
