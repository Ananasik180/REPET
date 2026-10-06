#!/bin/bash
# Бэкап папки с учебными материалами + логирование + ротация

set -euo pipefail

# --- Настройки ---
SOURCE_DIR="$HOME/study_materials"
BACKUP_DIR="$HOME/backups"
LOG_FILE="$BACKUP_DIR/backup.log"
DAYS_TO_KEEP=30
MIN_FREE_MB=500

# --- Telegram (опционально) ---
TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# --- Функции ---
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

send_telegram() {
    if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        return
    fi
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$1" > /dev/null || log "Не удалось отправить сообщение в Telegram"
}

# --- Подготовка ---
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"
log "=== Запуск бэкапа ==="

# --- Проверка источника ---
if [[ ! -d "$SOURCE_DIR" ]]; then
    log "ОШИБКА: папка $SOURCE_DIR не найдена"
    send_telegram "Ошибка бэкапа: папка $SOURCE_DIR не найдена"
    exit 1
fi

# --- Проверка свободного места ---
FREE_MB=$(df -m "$BACKUP_DIR" | awk 'NR==2 {print $4}')
log "Свободно места: ${FREE_MB} МБ"
if (( FREE_MB < MIN_FREE_MB )); then
    log "ОШИБКА: мало места (нужно минимум ${MIN_FREE_MB} МБ)"
    send_telegram "Ошибка бэкапа: мало места на диске"
    exit 1
fi

# --- Создание архива ---
ARCHIVE_NAME="study_materials_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
ARCHIVE_PATH="$BACKUP_DIR/$ARCHIVE_NAME"
log "Создаю архив: $ARCHIVE_NAME"

if tar -czf "$ARCHIVE_PATH" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")"; then
    SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    log "Архив создан. Размер: $SIZE"
else
    log "ОШИБКА при создании архива"
    send_telegram "Ошибка бэкапа: не удалось создать архив"
    exit 1
fi

# --- Ротация старых архивов ---
DELETED=$(find "$BACKUP_DIR" -name "study_materials_*.tar.gz" -type f -mtime +$DAYS_TO_KEEP -print -delete | wc -l)
log "Удалено старых архивов: $DELETED"

# --- Итог ---
TOTAL_ARCHIVES=$(ls -1 "$BACKUP_DIR"/study_materials_*.tar.gz 2>/dev/null | wc -l)
log "Всего архивов в хранилище: $TOTAL_ARCHIVES"
log "=== Бэкап завершён ==="

send_telegram "Бэкап завершён. Архив: $ARCHIVE_NAME ($SIZE). Удалено старых: $DELETED"
