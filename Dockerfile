FROM python:3.11-slim

WORKDIR /app

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Копирование файлов проекта
COPY . .

# Установка Python зависимостей
RUN pip install --no-cache-dir -r requirements.txt

# Открытие порта
EXPOSE 8080

# Запуск приложения
CMD ["python", "web_server.py"]
