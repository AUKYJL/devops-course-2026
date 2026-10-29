#!/usr/bin/env bash
set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"

    if [[ "$actual" == "$expected" ]]; then
        echo "[OK] $desc"
        ((PASS++))
    else
        echo "[FAIL] $desc (ожидалось: $expected, получено: $actual)"
        ((FAIL++))
    fi
}

echo "Аудит: $(hostname -f), $(date)"

echo "[1] SSH"

SSH_CONFIG="$(sudo sshd -T)"

check "Root запрещён" "no" \
    "$(awk '/^permitrootlogin /{print $2}' <<< "$SSH_CONFIG")"

check "Пароль отключён" "no" \
    "$(awk '/^passwordauthentication /{print $2}' <<< "$SSH_CONFIG")"

check "Порт SSH" "2222" \
    "$(awk '/^port /{print $2}' <<< "$SSH_CONFIG")"

check "MaxAuthTries" "3" \
    "$(awk '/^maxauthtries /{print $2}' <<< "$SSH_CONFIG")"

echo "[2] Межсетевой экран"

check "UFW активен" "active" \
    "$(sudo ufw status | awk '/^Status:/{print $2}')"

check "Входящий трафик запрещён" "deny" \
    "$(sudo ufw status verbose | awk '/^Default:/ {print $2}')"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {
    printf "%s (uid=%s)\n",$1,$3
}' /etc/passwd

echo "[4] Веб-сервер"

check "Nginx активен" "active" \
    "$(systemctl is-active nginx)"

NGINX_OK=no
if sudo nginx -t >/dev/null 2>&1; then
    NGINX_OK=yes
fi
check "Конфигурация Nginx" "yes" "$NGINX_OK"

CERT_THRESHOLD_DAYS="${CERT_THRESHOLD_DAYS:-30}"
CERT_OK=no

if openssl x509 \
    -in /etc/ssl/certs/devops.crt \
    -noout -checkend "$((CERT_THRESHOLD_DAYS * 86400))" \
    >/dev/null 2>&1; then
    CERT_OK=yes
fi

check "Срок сертификата" "yes" "$CERT_OK"

WRITABLE_FILES="$(find /var/www/devops-site -perm -o+w -print)"

check "Нет файлов с правом записи для всех" \
    "" "$WRITABLE_FILES"

check "Права закрытого ключа" "600" \
    "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "[5] Контейнеризация"

check "Docker активен" "active" \
    "$(systemctl is-active docker)"

DB_CONTAINER="$(docker compose \
    --project-directory "$HOME/app" \
    ps -q db)"

DB_HEALTH="missing"

if [[ -n "$DB_CONTAINER" ]]; then
    DB_HEALTH="$(docker inspect \
        -f '{{.State.Health.Status}}' \
        "$DB_CONTAINER")"
fi

check "PostgreSQL healthy" "healthy" "$DB_HEALTH"

UNSAFE_PORTS="$(sudo ss -H -tln | awk '
    $4 ~ /:(5000|5432)$/ &&
    $4 !~ /^127\.0\.0\.1:/ &&
    $4 !~ /^\[::1\]:/ {
        print $4
    }'
)"

check "Порты 5000 и 5432 не открыты извне" \
    "" "$UNSAFE_PORTS"

check "Права .env" "600" \
    "$(stat -c '%a' "$HOME/app/.env")"

echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
