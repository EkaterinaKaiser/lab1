#!/bin/bash

# Скрипт для диагностики проблем с деплоем на виртуальной машине
# Запустите этот скрипт на ВМ для выявления проблем

echo "=== Диагностика проблем с деплоем ==="
echo "Дата: $(date)"
echo ""

# 1. Проверка системных ресурсов
echo "=== 1. Системные ресурсы ==="
echo "Память:"
free -h
echo ""
echo "Дисковое пространство:"
df -h
echo ""
echo "Загрузка системы:"
uptime
echo ""

# 2. Проверка Docker
echo "=== 2. Docker ==="
echo "Версия Docker:"
docker --version
echo ""
echo "Версия Docker Compose:"
docker compose version
echo ""
echo "Статус Docker:"
systemctl is-active docker || echo "Docker не активен"
echo ""
echo "Использование Docker:"
docker system df
echo ""

# 3. Проверка запущенных контейнеров
echo "=== 3. Контейнеры ==="
echo "Все контейнеры:"
docker ps -a
echo ""
echo "Используемые порты:"
ss -tlnp | grep -E ':(5432|27017|8080)'
echo ""

# 4. Проверка сетевых настроек
echo "=== 4. Сеть ==="
echo "IP адреса:"
hostname -I
echo ""
echo "Статус firewall:"
ufw status 2>/dev/null || echo "ufw не установлен"
echo ""
echo "Docker сети:"
docker network ls
echo ""

# 5. Проверка логов
echo "=== 5. Логи ==="
echo "Логи Docker:"
journalctl -u docker --no-pager --lines=10
echo ""

# 6. Проверка файловой системы
echo "=== 6. Файловая система ==="
echo "Права на директории:"
ls -la /home/
echo ""
echo "Права на проект:"
ls -la /home/nikita/Desktop/DEV/ITMO/lab1/
echo ""

# 7. Проверка переменных окружения
echo "=== 7. Переменные окружения ==="
echo "Docker переменные:"
env | grep -i docker
echo ""

# 8. Тест запуска контейнеров
echo "=== 8. Тест запуска ==="
echo "Попытка запуска тестового контейнера:"
if docker run --rm hello-world > /dev/null 2>&1; then
    echo "✅ Docker работает корректно"
else
    echo "❌ Проблема с Docker"
fi
echo ""

# 9. Проверка docker-compose
echo "=== 9. Docker Compose тест ==="
cd /home/nikita/Desktop/DEV/ITMO/lab1/ || echo "❌ Не удалось перейти в директорию проекта"
echo "Проверка синтаксиса docker-compose.yml:"
if docker compose config > /dev/null 2>&1; then
    echo "✅ docker-compose.yml корректен"
else
    echo "❌ Ошибка в docker-compose.yml"
    docker compose config
fi
echo ""

# 10. Рекомендации
echo "=== 10. Рекомендации ==="
echo "Если контейнеры не запускаются, проверьте:"
echo "1. Достаточно ли памяти (минимум 2GB)"
echo "2. Открыты ли порты 5432, 27017, 8080"
echo "3. Работает ли Docker daemon"
echo "4. Есть ли права на запуск контейнеров"
echo "5. Не заняты ли порты другими процессами"
echo ""
echo "Для исправления проблем выполните:"
echo "sudo systemctl start docker"
echo "sudo usermod -aG docker \$USER"
echo "sudo ufw allow 8080"
echo "sudo ufw allow 5432"
echo "sudo ufw allow 27017"
echo ""

echo "=== Диагностика завершена ==="
