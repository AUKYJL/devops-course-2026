# Конфигурация devops-vm

## 1. Параметры машины
UTM, Ubuntu Server 24.04, 2 CPU, 2048 MB RAM, 25 GB.

## 2. Сетевые интерфейсы
UTM Shared Network.
IP Ubuntu: 192.168.64.5 (заменить на фактический).
Режим обеспечивает интернет и доступ с Mac.

## 3. Подключение
Mac -> IP Ubuntu:2222.
SSH-псевдоним: devops.
Проброс портов UTM не используется.

## 4. Учётные записи
student — начальная учётная запись.
devops — sudo, SSH-ключ Ed25519.

## 5. SSH
Порт 2222.
Конфигурация: /etc/ssh/sshd_config.d/99-hardening.conf.
Вход root и аутентификация паролем отключены.
MaxAuthTries 3, AllowUsers devops.

## 6. UFW
Входящие deny, исходящие allow.
2222/tcp LIMIT, 80/tcp ALLOW, 443/tcp ALLOW.

## 7. Снимки состояния
01-clean-install — после установки Ubuntu.
02-keys-configured — после SSH-ключей.
03-ssh-hardened — после усиления SSH.

## 8. Веб-сервер

Пакет: nginx.
Конфигурация: /etc/nginx/sites-available/devops-site.
Активная ссылка: /etc/nginx/sites-enabled/devops-site.

Каталог: /var/www/devops-site.
Владелец: devops.
Права файлов 644, каталогов 755.

Сертификат: /etc/ssl/certs/devops.crt (644).
Закрытый ключ: /etc/ssl/private/devops.key (600).
Срок сертификата: 365 дней, самоподписанный, SAN: devops.local.

HTTP-порт: 80 с перенаправлением 301 на HTTPS.
HTTPS-порт: 443.

Проверка: sudo nginx -t.
Применение: sudo systemctl reload nginx.

Доставка: scripts/deploy.sh через rsync.
Проверка HTTPS: curl --cacert ~/devops.crt.
