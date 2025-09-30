#!/bin/bash

# Скрипт для настройки GitHub Self-Hosted Runner
# Запустите этот скрипт на машине с виртуалкой

echo "=== Настройка GitHub Self-Hosted Runner ==="

# Проверка наличия Docker
if ! command -v docker &> /dev/null; then
    echo "Ошибка: Docker не установлен!"
    exit 1
fi

# Проверка наличия Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Ошибка: Docker Compose не установлен!"
    exit 1
fi

# Создание директории для runner
mkdir -p ~/actions-runner
cd ~/actions-runner

# Скачивание последней версии runner
echo "Скачивание GitHub Actions Runner..."
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# Проверка целостности
echo "Проверка целостности файла..."
echo "29a8d908dce52e7f7cfcb4a413a9e0a3fa1bd5e2 *actions-runner-linux-x64-2.311.0.tar.gz" | shasum -a 256 -c

# Распаковка
echo "Распаковка runner..."
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Установка зависимостей
echo "Установка зависимостей..."
sudo ./bin/installdependencies.sh

echo "=== Настройка завершена ==="
echo ""
echo "Теперь выполните следующие шаги:"
echo "1. Перейдите в настройки репозитория: Settings > Actions > Runners"
echo "2. Нажмите 'New self-hosted runner'"
echo "3. Выберите 'Linux' и 'x64'"
echo "4. Скопируйте команды конфигурации и выполните их в этой директории"
echo "5. Запустите runner: ./run.sh"
echo ""
echo "Директория runner: $(pwd)"
