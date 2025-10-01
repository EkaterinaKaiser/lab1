#!/bin/bash

# Упрощенный скрипт деплоя для виртуальной машины
# Использует docker-compose для более надежного развертывания

echo "=== Деплой на виртуальную машину ==="
echo "Дата: $(date)"
echo ""

# Переход в директорию проекта
cd /home/nikita/Desktop/DEV/ITMO/lab1/ || {
    echo "❌ Ошибка: Не удалось перейти в директорию проекта"
    exit 1
}

# 1. Остановка и очистка старых контейнеров
echo "=== 1. Очистка старых контейнеров ==="
docker compose down -v --remove-orphans || true
docker system prune -f
echo "✅ Очистка завершена"
echo ""

# 2. Проверка доступности портов
echo "=== 2. Проверка портов ==="
for port in 5432 27017 8080; do
    if ss -tlnp | grep ":$port " > /dev/null; then
        echo "⚠️  Порт $port уже занят"
        echo "Занявшие процессы:"
        ss -tlnp | grep ":$port "
    else
        echo "✅ Порт $port свободен"
    fi
done
echo ""

# 3. Открытие портов в firewall
echo "=== 3. Настройка firewall ==="
for port in 5432 27017 8080; do
    if ufw status | grep "$port" > /dev/null; then
        echo "✅ Порт $port уже открыт в firewall"
    else
        echo "Открытие порта $port в firewall..."
        sudo ufw allow $port 2>/dev/null || echo "⚠️  Не удалось открыть порт $port"
    fi
done
echo ""

# 4. Сборка и запуск через docker-compose
echo "=== 4. Сборка и запуск сервисов ==="
echo "Сборка образов..."
docker compose build --no-cache
echo ""

echo "Запуск сервисов..."
docker compose up -d
echo ""

# 5. Ожидание готовности сервисов
echo "=== 5. Ожидание готовности сервисов ==="
echo "Ожидание PostgreSQL..."
for i in {1..30}; do
    if docker compose exec -T postgres pg_isready -U postgres -d university > /dev/null 2>&1; then
        echo "✅ PostgreSQL готов"
        break
    fi
    echo "Ожидание PostgreSQL... ($i/30)"
    sleep 2
done
echo ""

echo "Ожидание MongoDB..."
for i in {1..30}; do
    if docker compose exec -T mongodb mongosh --eval "print('test')" > /dev/null 2>&1; then
        echo "✅ MongoDB готов"
        break
    fi
    echo "Ожидание MongoDB... ($i/30)"
    sleep 2
done
echo ""

# 6. Проверка статуса
echo "=== 6. Статус сервисов ==="
docker compose ps
echo ""

# 7. Проверка приложения
echo "=== 7. Проверка приложения ==="
echo "Ожидание запуска приложения..."
sleep 10

echo "Проверка доступности приложения..."
if curl -f http://localhost:8080/ > /dev/null 2>&1; then
    echo "✅ Приложение доступно на http://localhost:8080/"
    echo "🌐 Внешний доступ: http://$(hostname -I | awk '{print $1}'):8080"
else
    echo "❌ Приложение недоступно"
    echo "Логи приложения:"
    docker compose logs app --tail 20
fi
echo ""

# 8. Финальная диагностика
echo "=== 8. Финальная диагностика ==="
echo "Используемые порты:"
ss -tlnp | grep -E ':(5432|27017|8080)'
echo ""

echo "Статус контейнеров:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "=== Деплой завершен ==="
echo "Если приложение недоступно, запустите:"
echo "  ./debug-deployment.sh"
echo "  docker compose logs"
