#!/bin/bash

# Guido Installer v1.0
# Этот скрипт распаковывает и запускает основной скрипт Guido.

# Функция для вывода сообщений
_installer_log() {
    echo "[Guido Installer] $1" >&2
}

# Проверка на root
if [[ $EUID -ne 0 ]]; then
   _installer_log "ERROR: Этот скрипт должен быть запущен от имени суперпользователя (root)."
   exit 1
fi

_installer_log "Инициализация установщика Guido..."

# Создание временного каталога
GUIDO_TEMP_DEPLOY_DIR=$(mktemp -d /var/tmp/guido_deploy_XXXXXX)
if [[ ! -d "$GUIDO_TEMP_DEPLOY_DIR" ]]; then
    _installer_log "ERROR: Не удалось создать временный каталог $GUIDO_TEMP_DEPLOY_DIR."
    exit 1
fi
_installer_log "Временный каталог создан: $GUIDO_TEMP_DEPLOY_DIR"

# Установка прав на временный каталог
chmod 700 "$GUIDO_TEMP_DEPLOY_DIR"

# Base64 закодированный tar.gz архив с полезной нагрузкой
# ЗАМЕНИТЕ ЭТУ СТРОКУ НА СОДЕРЖИМОЕ ВАШЕГО guido_payload_b64.txt
PAYLOAD_BASE64="%%PAYLOAD_BASE64_CONTENT%%"

if [[ -z "$PAYLOAD_BASE64" || "$PAYLOAD_BASE64" == "PLACEHOLDER_FOR_BASE64_PAYLOAD" ]]; then
    _installer_log "ERROR: Полезная нагрузка (PAYLOAD_BASE64) не определена в скрипте установщика!"
    rm -rf "$GUIDO_TEMP_DEPLOY_DIR"
    exit 1
fi

_installer_log "Декодирование и распаковка полезной нагрузки..."
if echo "$PAYLOAD_BASE64" | base64 -d | tar -xzvf - -C "$GUIDO_TEMP_DEPLOY_DIR"; then
    _installer_log "Полезная нагрузка успешно распакована в $GUIDO_TEMP_DEPLOY_DIR."
else
    _installer_log "ERROR: Ошибка при декодировании или распаковке полезной нагрузки."
    rm -rf "$GUIDO_TEMP_DEPLOY_DIR"
    exit 1
fi

# Создание маркерного файла внутри распакованного каталога
touch "${GUIDO_TEMP_DEPLOY_DIR}/.guido_payload_marker"

# Путь к основному скрипту Guido внутри временного каталога
MAIN_GUIDO_SCRIPT="${GUIDO_TEMP_DEPLOY_DIR}/guido.sh"

if [[ ! -f "$MAIN_GUIDO_SCRIPT" ]]; then
    _installer_log "ERROR: Основной скрипт $MAIN_GUIDO_SCRIPT не найден после распаковки."
    rm -rf "$GUIDO_TEMP_DEPLOY_DIR"
    exit 1
fi

_installer_log "Запуск основного скрипта Guido из $MAIN_GUIDO_SCRIPT..."
_installer_log "Все аргументы будут переданы: $@"

# Экспортируем переменную, чтобы основной скрипт Guido знал, откуда он запущен
export GUIDO_TEMP_DEPLOY_DIR

# Запускаем основной скрипт, передавая ему все аргументы, полученные установщиком
exec "$MAIN_GUIDO_SCRIPT" "$@"

# Этот код не должен выполниться, если exec сработал
_installer_log "ERROR: Не удалось выполнить exec для $MAIN_GUIDO_SCRIPT."
rm -rf "$GUIDO_TEMP_DEPLOY_DIR"
exit 1