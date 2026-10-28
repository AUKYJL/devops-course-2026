#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
LOCAL_DIR="$ROOT/site/"
SITE_URL="https://devops.local"
CA_CERT="$HOME/devops.crt"

DRY_RUN=false

if [[ $# -gt 1 ]]; then
    echo "Использование: $0 [--dry-run]" >&2
    exit 1
fi

if [[ $# -eq 1 ]]; then
    if [[ "$1" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        echo "Неизвестный аргумент: $1" >&2
        exit 1
    fi
fi

if [[ ! -f "$LOCAL_DIR/index.html" ]]; then
    echo "Ошибка: site/index.html отсутствует" >&2
    exit 1
fi

if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
    echo "Ошибка: есть незафиксированные изменения Git" >&2
    exit 1
fi

RSYNC_ARGS=(
    -avz
    --delete
    --chmod=D755,F644
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5"
)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
fi

if ! rsync "${RSYNC_ARGS[@]}" \
    "$LOCAL_DIR" "$REMOTE:$REMOTE_DIR/"; then
    echo "Ошибка доставки" >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Пробный запуск завершён"
    exit 0
fi

if ! curl -fsS \
    --cacert "$CA_CERT" \
    -o /dev/null \
    "$SITE_URL"; then
    echo "Ошибка: HTTPS недоступен" >&2
    exit 1
fi

echo "Деплой успешен"
echo "Commit: $(git -C "$ROOT" rev-parse --short HEAD)"
