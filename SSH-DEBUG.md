# Диагностика SSH подключения

## 🔍 Проблема: `dial tcp ***:***: i/o timeout`

Эта ошибка означает, что GitHub Actions не может подключиться к вашему серверу по SSH.

## 🚀 Пошаговая диагностика

### 1. Проверьте SSH ключи

**На вашем локальном компьютере:**
```bash
# Проверьте, что у вас есть SSH ключи
ls -la ~/.ssh/

# Должны быть файлы:
# id_rsa (приватный ключ)
# id_rsa.pub (публичный ключ)
```

**Проверьте содержимое приватного ключа:**
```bash
cat ~/.ssh/id_rsa
```

**Проверьте содержимое публичного ключа:**
```bash
cat ~/.ssh/id_rsa.pub
```

### 2. Проверьте настройку на сервере

**На сервере (192.168.0.111):**
```bash
# Проверьте, что публичный ключ добавлен в authorized_keys
cat ~/.ssh/authorized_keys

# Проверьте права доступа
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
```

### 3. Проверьте SSH подключение локально

```bash
# Тест подключения с подробным выводом
ssh -v root@192.168.0.111

# Если не работает, попробуйте:
ssh -v -o ConnectTimeout=30 root@192.168.0.111
```

### 4. Проверьте сетевую доступность

```bash
# Ping сервера
ping -c 3 192.168.0.111

# Проверка SSH порта
telnet 192.168.0.111 22
# или
nc -zv 192.168.0.111 22
```

### 5. Проверьте настройки SSH на сервере

**На сервере:**
```bash
# Проверьте статус SSH
sudo systemctl status ssh

# Проверьте конфигурацию SSH
sudo cat /etc/ssh/sshd_config | grep -E "(Port|PasswordAuthentication|PubkeyAuthentication)"

# Перезапустите SSH если нужно
sudo systemctl restart ssh
```

## 🔧 Решения

### Решение 1: Пересоздайте SSH ключи

```bash
# Удалите старые ключи
rm ~/.ssh/id_rsa*

# Создайте новые ключи
ssh-keygen -t rsa -b 4096 -C "github-actions-$(date +%Y%m%d)"

# Скопируйте публичный ключ на сервер
ssh-copy-id root@192.168.0.111

# Проверьте подключение
ssh root@192.168.0.111 "echo 'SSH работает!'"
```

### Решение 2: Используйте пароль вместо ключей

Добавьте в GitHub Secrets:
- `SERVER_PASSWORD` - пароль пользователя root

И обновите workflow:
```yaml
- name: Test server connection
  uses: appleboy/ssh-action@v1.0.3
  with:
    host: ${{ secrets.SERVER_HOST }}
    username: ${{ secrets.SERVER_USERNAME }}
    password: ${{ secrets.SERVER_PASSWORD }}  # Вместо key
    port: ${{ secrets.SERVER_PORT }}
```

### Решение 3: Проверьте файрвол

**На сервере:**
```bash
# Проверьте UFW
sudo ufw status

# Если активен, разрешите SSH
sudo ufw allow ssh
sudo ufw allow 22

# Или временно отключите
sudo ufw disable
```

### Решение 4: Используйте другой SSH порт

Если SSH работает на другом порту:
```bash
# Проверьте, на каком порту работает SSH
sudo netstat -tlnp | grep sshd

# Обновите SERVER_PORT в GitHub Secrets
```

## 🧪 Тестовые workflows

Я создал два тестовых workflow:

1. **`.github/workflows/test-ssh.yml`** - тестирует SSH с ключами и паролем
2. **`.github/workflows/debug-connection.yml`** - диагностирует сетевое подключение

Запустите их вручную через GitHub Actions для диагностики.

## ✅ Проверочный список

- [ ] SSH ключи сгенерированы правильно
- [ ] Публичный ключ добавлен в `~/.ssh/authorized_keys` на сервере
- [ ] Права доступа к файлам SSH настроены правильно
- [ ] SSH сервис запущен на сервере
- [ ] Файрвол не блокирует SSH порт
- [ ] Сервер доступен по сети
- [ ] GitHub Secrets настроены правильно

## 🆘 Если ничего не помогает

1. Попробуйте подключиться с другого компьютера
2. Проверьте логи SSH на сервере: `sudo journalctl -u ssh`
3. Временно отключите файрвол: `sudo ufw disable`
4. Используйте пароль вместо ключей для тестирования
