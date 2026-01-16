# Инструкция по деплою в облако

## Обзор

Проект настроен для автоматического деплоя в облако через GitHub Actions. При каждом push в ветку `main` или `master` автоматически выполняется:

1. Установка Suricata и зависимостей
2. Загрузка и обновление правил (ET Open, PT Security)
3. Загрузка IoC-фидов из внешних источников
4. Генерация кастомных правил из IoC
5. Запуск Suricata в IPS-режиме
6. Развертывание контейнеров (attacker, victim)
7. Настройка iptables для интеграции с Suricata

## Настройка GitHub Secrets

Перед первым деплоем необходимо настроить следующие secrets в репозитории GitHub:

1. Перейдите в **Settings → Secrets and variables → Actions**
2. Добавьте следующие secrets:

### SSH_PRIVATE_KEY
Приватный SSH ключ для подключения к серверу в облаке.

```bash
# Сгенерируйте ключ, если его нет
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_deploy

# Скопируйте приватный ключ
cat ~/.ssh/github_deploy
```

### SSH_HOST
IP-адрес или доменное имя сервера в облаке.

Пример: `178.72.153.208` или `suricata.example.com`

### SSH_USER
Имя пользователя для SSH подключения.

Обычно: `root`, `ubuntu`, `debian` или другое в зависимости от дистрибутива.

## Структура деплоя

### Файлы, копируемые на сервер

- `docker-compose.yml` - конфигурация Docker контейнеров
- `suricata.yaml` - конфигурация Suricata
- `fetch_feeds.sh` - скрипт загрузки IoC-фидов
- `generate_custom_ioc_rules.py` - генератор правил из IoC
- `update_rules.sh` - полный pipeline обновления правил
- `Makefile` - автоматизация всех этапов
- `rules/` - директория с базовыми правилами

### Этапы деплоя

#### 1. Cleanup
- Остановка предыдущих контейнеров
- Очистка Suricata процессов
- Очистка iptables правил

#### 2. Copy files
- Копирование всех необходимых файлов на сервер
- Создание необходимых директорий

#### 3. Install Suricata
- Установка Suricata из официального PPA
- Установка зависимостей:
  - `suricata-update` - для обновления правил
  - `python3` - для генератора правил
  - `jq` - для парсинга JSON (опционально)
  - `curl` - для загрузки фидов

#### 4. Update Rules
- Обновление индекса источников правил
- Включение ET Open rules
- Попытка включения PT Security rules
- Загрузка официальных правил
- Загрузка IoC-фидов из внешних источников
- Генерация кастомных правил из IoC
- Проверка конфигурации Suricata

#### 5. Start Suricata
- Запуск Suricata в IPS-режиме (NFQUEUE)
- Проверка успешного запуска

#### 6. Deploy Containers
- Создание Docker сети
- Запуск контейнеров (attacker, victim)

#### 7. Configure iptables
- Настройка iptables для интеграции с Suricata
- Создание цепочки PRE-SURICATA
- Направление трафика через NFQUEUE

#### 8. Verify Deployment
- Проверка статуса контейнеров
- Проверка работы Suricata
- Проверка правил iptables

#### 9. Test Protection
- Тестирование блокировки ICMP
- Тестирование разрешения HTTP

## Ручной деплой

Если нужно выполнить деплой вручную:

```bash
# 1. Подключитесь к серверу
ssh user@your-server

# 2. Клонируйте репозиторий
git clone <your-repo-url> ~/lab-infrastructure
cd ~/lab-infrastructure

# 3. Установите зависимости
sudo apt-get update
sudo apt-get install -y software-properties-common curl python3 python3-pip jq
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt-get update
sudo apt-get install -y suricata suricata-update

# 4. Установите права на выполнение
chmod +x fetch_feeds.sh generate_custom_ioc_rules.py update_rules.sh

# 5. Обновите правила
./update_rules.sh

# 6. Запустите контейнеры
docker compose up -d

# 7. Настройте iptables (см. setup-iptables.sh или workflow)
```

## Мониторинг

### Проверка статуса Suricata

```bash
# Проверка процесса
sudo systemctl status suricata

# Проверка PID
cat /var/run/suricata.pid

# Проверка логов
sudo tail -f /var/log/suricata/suricata.log
sudo tail -f /var/log/suricata/eve.json | jq .
```

### Проверка правил

```bash
# Количество правил
sudo wc -l /var/lib/suricata/rules/suricata.rules
sudo wc -l /etc/suricata/rules/custom_ioc.rules

# Проверка включенных источников
sudo suricata-update list-enabled-sources
```

### Проверка контейнеров

```bash
cd ~/lab-infrastructure
docker compose ps
docker compose logs
```

## Обновление правил

Правила можно обновить вручную:

```bash
cd ~/lab-infrastructure
./update_rules.sh
```

Или использовать Makefile:

```bash
make all
```

## Устранение неполадок

### Suricata не запускается

```bash
# Проверьте конфигурацию
sudo suricata -T -c /etc/suricata/suricata.yaml

# Проверьте логи
sudo tail -50 /var/log/suricata/suricata.log
```

### Правила не загружаются

```bash
# Проверьте наличие файлов правил
ls -lh /var/lib/suricata/rules/suricata.rules
ls -lh /etc/suricata/rules/custom_ioc.rules

# Проверьте конфигурацию
grep -A 10 "rule-files:" /etc/suricata/suricata.yaml
```

### Контейнеры не запускаются

```bash
# Проверьте логи Docker
docker compose logs
docker compose ps

# Проверьте сеть
docker network ls
docker network inspect labnet
```

### iptables не работает

```bash
# Проверьте правила
sudo iptables -L DOCKER-USER -n -v
sudo iptables -L PRE-SURICATA -n -v

# Проверьте NFQUEUE
sudo iptables -L PRE-SURICATA -n -v | grep NFQUEUE
```

## Безопасность

⚠️ **Важно**: При деплое в облако убедитесь, что:

1. SSH ключи защищены и не хранятся в открытом виде
2. Сервер имеет настроенный firewall
3. Suricata работает в режиме IPS только для тестовой сети
4. Правила iptables не блокируют административный доступ

## Дополнительные ресурсы

- [Документация Suricata](https://suricata.readthedocs.io/)
- [suricata-update документация](https://suricata.readthedocs.io/en/suricata-6.0.0/rule-management/suricata-update.html)
- [GitHub Actions документация](https://docs.github.com/en/actions)
