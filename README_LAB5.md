# Лабораторная работа №5: Автоматизация сбора и формирования правил Suricata

## Описание

Этот проект реализует автоматизированный pipeline для сбора и формирования правил Suricata из внешних источников Threat Intelligence.

## Выполненные задачи

### 1. Автоматизация загрузки правил Positive Technologies

Поддержка правил PT Security реализована через `suricata-update`:

```bash
# Обновить индекс источников
sudo suricata-update update-sources

# Включить правила PT Security
sudo suricata-update enable-source pt/open

# Или использовать Makefile
make update-sources
make enable-pt
```

Правила PT автоматически загружаются при выполнении `make all` или `./update_rules.sh`.

### 2. Блокировка публичных сервисов

Реализована блокировка IP-адресов следующих облачных провайдеров:
- Google Cloud
- AWS (Amazon Web Services)
- Microsoft Azure
- Cloudflare
- DigitalOcean

IP-адреса загружаются автоматически через `fetch_feeds.sh` и преобразуются в правила Suricata.

### 3. Блокировка ресурсов, запрещенных в РФ

Реализована поддержка следующих источников:
- **Antifilter** (https://antifilter.download, https://antifilter.network) — списки IP из реестра РКН
- **Zapret-info** (https://github.com/zapret-info/z-i) — реестр запрещенных ресурсов РФ
- **Роскомсвобода** (https://reestr.rublacklist.net/) — API реестра заблокированных ресурсов

## Структура проекта

```
.
├── fetch_feeds.sh              # Скрипт загрузки IoC-фидов
├── generate_custom_ioc_rules.py # Генератор правил из IoC
├── update_rules.sh              # Полный pipeline обновления правил
├── Makefile                     # Автоматизация всех этапов
├── suricata.yaml                # Конфигурация Suricata
└── feeds/                       # Директория с загруженными фидами
    ├── feodo_ips.txt
    ├── urlhaus_ips.txt
    ├── botvrij_ips.txt
    ├── google_cloud_ips.txt
    ├── aws_ips.txt
    ├── azure_ips.txt
    ├── cloudflare_ips.txt
    ├── digitalocean_ips.txt
    ├── antifilter_ips.txt
    ├── zapret_ips.txt
    └── rublacklist_ips.txt
```

## Использование

### Быстрый старт

```bash
# Выполнить полный цикл: загрузка фидов → генерация правил → тест → деплой
make all
```

### Пошаговое выполнение

```bash
# 1. Обновить индекс источников правил
make update-sources

# 2. Включить правила Positive Technologies
make enable-pt

# 3. Загрузить IoC-фиды
make fetch

# 4. Сгенерировать правила
make generate

# 5. Протестировать конфигурацию
make test

# 6. Применить правила
make deploy

# 7. Проверить статус
make status
```

### Использование скрипта update_rules.sh

```bash
# Запустить полный pipeline обновления
sudo ./update_rules.sh
```

Скрипт выполняет:
1. Обновление индекса источников
2. Включение ET Open и PT Security правил
3. Загрузку официальных правил через suricata-update
4. Загрузку кастомных IoC-фидов
5. Генерацию правил из IoC
6. Тестирование конфигурации
7. Перезагрузку Suricata

## Источники данных

### Вредоносные IP-адреса
- **Feodo Tracker** (abuse.ch) — botnet C&C серверы
- **URLhaus** (abuse.ch) — IP-адреса для распространения malware
- **Botvrij.eu** — IoC список от голландской инициативы

### Облачные провайдеры
- **Google Cloud** — официальные IP-диапазоны
- **AWS** — официальные IP-диапазоны
- **Azure** — официальные IP-диапазоны
- **Cloudflare** — официальные IP-диапазоны
- **DigitalOcean** — официальные IP-диапазоны

### Ресурсы, запрещенные в РФ
- **Antifilter** — списки IP из реестра РКН
- **Zapret-info** — реестр запрещенных ресурсов РФ
- **Роскомсвобода** — API реестра заблокированных ресурсов

## Генерация правил

Правила генерируются с использованием следующих диапазонов SID:

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

## Конфигурация Suricata

Файл `suricata.yaml` настроен для использования:
- Официальных правил (`suricata.rules`) — ET Open, PT Security и др.
- Кастомных правил (`custom_ioc.rules`) — правила из IoC-источников

## Очистка

```bash
# Удалить загруженные фиды и сгенерированные правила
make clean
```

## Логирование

Логи обновления правил сохраняются в `/var/log/suricata/update_rules.log`.

## Примечания

- Для работы некоторых источников может потребоваться установка `jq` (для парсинга JSON)
- Скрипты автоматически определяют наличие `jq` и используют альтернативные методы при его отсутствии
- Максимальное количество правил на источник ограничено 1000 для предотвращения перегрузки
- Правила генерируются в формате `drop`, что означает блокировку трафика

## Требования

- Python 3.6+
- curl
- suricata-update
- jq (опционально, для лучшей поддержки JSON-источников)
