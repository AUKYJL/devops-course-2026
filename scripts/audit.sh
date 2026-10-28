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
    "$(sudo ufw status verbose | sed -n 's/.*Default: \\([^ ]*\\) (incoming).*/\\1/p')"

echo "[3] Учётные записи"

awk -F: '$3>=1000 && $3<65534 {
    printf "%s (uid=%s)\n",$1,$3
}' /etc/passwd

echo "Пройдено: $PASS, не пройдено: $FAIL"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
