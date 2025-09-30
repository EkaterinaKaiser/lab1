# Настройка Self-Hosted Runner для локального деплоя

## Шаги настройки:

### 1. Подготовка машины с виртуалкой
```bash
# Установка Docker (если не установлен)
sudo apt update
sudo apt install docker.io docker-compose

# Добавление пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Проверка установки
docker --version
docker compose version
```

### 2. Создание Self-Hosted Runner

1. **Перейдите в настройки репозитория:**
   - GitHub → Settings → Actions → Runners
   - Нажмите "New self-hosted runner"

2. **Выберите конфигурацию:**
   - Operating System: Linux
   - Architecture: x64

3. **Скачайте и настройте runner:**
   ```bash
   # Создайте директорию
   mkdir actions-runner && cd actions-runner
   
   # Скачайте runner (замените на актуальную версию)
   curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
   
   # Распакуйте
   tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
   
   # Установите зависимости
   sudo ./bin/installdependencies.sh
   ```

4. **Настройте runner:**
   ```bash
   # Выполните команду из GitHub (будет выглядеть примерно так):
   ./config.sh --url https://github.com/username/repository --token YOUR_TOKEN
   ```

5. **Запустите runner:**
   ```bash
   # Для тестирования
   ./run.sh
   
   # Для постоянной работы (в фоне)
   nohup ./run.sh > runner.log 2>&1 &
   ```

### 3. Настройка автозапуска (опционально)

Создайте systemd сервис для автозапуска runner:

```bash
sudo nano /etc/systemd/system/github-runner.service
```

Содержимое файла:
```ini
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/home/your-username/actions-runner
ExecStart=/home/your-username/actions-runner/run.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Активация сервиса:
```bash
sudo systemctl enable github-runner
sudo systemctl start github-runner
```

## Использование:

### Вариант 1: Локальный деплой (рекомендуется)
- Используйте файл `.github/workflows/deploy-local.yml`
- Не требует SSH ключей и внешних серверов
- Все выполняется локально на машине с runner

### Вариант 2: Удаленный деплой
- Используйте файл `.github/workflows/deploy.yml`
- Требует настройки SSH ключей
- Подходит для деплоя на внешние серверы

## Проверка работы:

1. Сделайте push в main ветку
2. Перейдите в Actions в GitHub
3. Убедитесь, что workflow запустился на self-hosted runner
4. Проверьте логи выполнения

## Доступ к приложению:

После успешного деплоя приложение будет доступно по адресу:
- `http://localhost:8080` - на машине с runner
- `http://IP_МАШИНЫ:8080` - с других машин в сети

## Устранение проблем:

1. **Runner не запускается:**
   - Проверьте права доступа к файлам
   - Убедитесь, что Docker запущен
   - Проверьте логи: `tail -f runner.log`

2. **Workflow не запускается:**
   - Убедитесь, что runner активен в GitHub
   - Проверьте, что runner имеет права на репозиторий

3. **Ошибки Docker:**
   - Проверьте, что пользователь в группе docker
   - Перезапустите Docker: `sudo systemctl restart docker`
