FROM python:3.9-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Установка Python зависимостей
RUN pip install psycopg2-binary

# Создание рабочей директории
WORKDIR /app

# Копирование файлов приложения
COPY web_server.py .
COPY query_generator.py .

# Создание пользователя для безопасности
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Открытие порта
EXPOSE 8080

# Команда запуска
CMD ["python", "web_server.py"]

