# Настройка для пользователя vboxuser

## ✅ Проблема решена!

SSH подключение работает с пользователем `vboxuser` вместо `root`.

## 🔧 Что нужно сделать

### 1. Обновите GitHub Secrets

В настройках репозитория (`Settings` → `Secrets and variables` → `Actions`):

- `SERVER_USERNAME` = `vboxuser` (вместо `root`)
- `SERVER_HOST` = `192.168.0.111`
- `SERVER_SSH_KEY` = ваш приватный ключ (уже настроен)
- `SERVER_PORT` = `22`

### 2. Настройка на сервере (уже выполнена)

```bash
# Публичный ключ уже добавлен для vboxuser
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBB71TSJiLtIQjwzsHb2Jm1DmPH15Bc/1Gq+/3AlSZQ3 nikitakaiser@yandex.ru" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3. Права Docker (выполните на сервере)

```bash
# Добавьте vboxuser в группу docker
sudo usermod -aG docker vboxuser

# Перезапустите сессию или выполните
newgrp docker

# Проверьте, что Docker работает без sudo
docker --version
```

### 4. Создание директории приложения

```bash
# Создайте директорию с правильными правами
sudo mkdir -p /opt/university-app
sudo chown vboxuser:vboxuser /opt/university-app
```

## 🚀 Теперь можно деплоить!

После обновления `SERVER_USERNAME` в GitHub Secrets:

1. Сделайте push в main ветку
2. GitHub Actions автоматически запустится
3. Приложение будет доступно по адресу: http://192.168.0.111:8080

## 🔍 Проверка

```bash
# Локальная проверка SSH
ssh vboxuser@192.168.0.111 "echo 'SSH работает!'"

# Проверка Docker
ssh vboxuser@192.168.0.111 "docker --version"

# Проверка директории
ssh vboxuser@192.168.0.111 "ls -la /opt/university-app"
```

## ⚠️ Важно

- Все команды в workflow теперь выполняются от имени `vboxuser`
- Docker команды будут работать без `sudo` после добавления в группу
- Директория `/opt/university-app` принадлежит `vboxuser`
