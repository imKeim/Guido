```bash
# === НА ЦЕЛЕВОЙ МАШИНЕ ===

# --- ЭТАП 1: Подготовка окружения ---
# (Выполняется один раз в начале. Скопируйте и вставьте ВЕСЬ этот блок целиком, от начала до конца)

# --- НАЧАЛО БЛОКА ДЛЯ КОПИРОВАНИЯ ---
 clear
 # Включаем функцию игнорирования команд с пробелом для чистоты истории
 export HISTCONTROL=ignorespace
 
 export TMP_B64_ASSEMBLY_FILE=$(mktemp --tmpdir=/dev/shm guido_payload.XXXXXX.b64 2>/dev/null) || export TMP_B64_ASSEMBLY_FILE=$(mktemp /tmp/guido_payload.XXXXXX.b64)

# Определяем вспомогательную функцию для удобного добавления частей
add_part() {
    local part_num="$1"
    if [[ -z "$part_num" ]]; then echo "ОШИБКА: Укажите номер части, например: add_part 1"; return 1; fi
    
    echo ""
    echo "--- Добавление ЧАСТИ $part_num ---"
    echo "1. На машине СБОРКИ скопируйте содержимое файла части $part_num."
    echo "2. Вставьте скопированный текст ниже и нажмите Enter."
    echo "3. На новой строке введите маркер 'END_OF_PART' и снова нажмите Enter."
    
    cat >> "$TMP_B64_ASSEMBLY_FILE"
    
    touch "$TMP_B64_ASSEMBLY_FILE.part${part_num}.done" # Создаем маркер
    echo "OK. Часть $part_num добавлена. Готово к следующей части."
}

# Определяем функцию для финального запуска, распаковки и очистки
run_guido() {
    local total_parts="$1"
    if [[ -z "$total_parts" ]]; then echo "ОШИБКА: Укажите общее количество частей, например: run_guido 2"; return 1; fi

    local parts_added
    parts_added=$(ls "$TMP_B64_ASSEMBLY_FILE".part*.done 2>/dev/null | wc -l)

    if [[ "$parts_added" -ne "$total_parts" ]]; then
        echo "!!! ОШИБКА ПРОВЕРКИ !!!"
        echo "Ожидалось $total_parts частей, но было добавлено только $parts_added."
        echo "Пожалуйста, добавьте недостающие части с помощью 'add_part N' и попробуйте снова."
        return 1
    fi

    echo ""
    echo "======================================================================"
    echo "Все $total_parts части переданы. Распаковываю и запускаю скрипт..."
    echo "======================================================================"
    echo ""

    local SCRIPT_EXEC_DIR
    SCRIPT_EXEC_DIR=$(mktemp -d /var/tmp/guido_exec.XXXXXX)
    
    # Цепочка команд: декодировать, распаковать, запустить, а затем очистить
    (base64 -d "$TMP_B64_ASSEMBLY_FILE" | xz -d | tar -x -C "$SCRIPT_EXEC_DIR" && \
     bash "${SCRIPT_EXEC_DIR}/guido.sh" -p -c de24) && \
      (echo -e '\n\033[1;32m[SUCCESS]\033[0m Скрипт Guido завершен УСПЕШНО.') || \
      (echo -e '\n\033[1;31m[ERROR]\033[0m !!! ОШИБКА !!! Скрипт Guido завершился с ошибкой (возможно, части были скопированы неверно).')
    
    echo "Произвожу полную очистку временных данных и функций..."
    rm -f "$TMP_B64_ASSEMBLY_FILE"
    rm -f "$TMP_B64_ASSEMBLY_FILE".part*.done
    rm -rf "$SCRIPT_EXEC_DIR"
    unset TMP_B64_ASSEMBLY_FILE
    unset -f add_part
    unset -f run_guido
    echo "Очистка завершена."
}

echo "======================================================================"
echo "Окружение подготовлено. Временный файл: $TMP_B64_ASSEMBLY_FILE"
echo "Теперь для каждой части используйте команду 'add_part [НОМЕР]'"
echo "Когда все части будут добавлены, используйте 'run_guido [КОЛ-ВО_ЧАСТЕЙ]'"
echo "======================================================================"
echo ""
# --- КОНЕЦ БЛОКА ДЛЯ КОПИРОВАНИЯ ---


# --- ЭТАП 2: Передача частей ---
# Для каждой части выполняйте ДВЕ операции:
# 1. На машине СБОРКИ: cat "build_output/oneliner_part_XXX.b64part" (и скопируйте вывод)
# 2. На ЦЕЛЕВОЙ машине: выполните команду 'add_part N', вставьте скопированное и завершите маркером 'END_OF_PART'.

# <<< Передача ЧАСТИ 1 >>>
 add_part 1
# (СЮДА ВСТАВИТЬ СОДЕРЖИМОЕ oneliner_part_000.b64part)
END_OF_PART

# <<< Передача ЧАСТИ 2 >>>
 add_part 2
# (СЮДА ВСТАВИТЬ СОДЕРЖИМОЕ oneliner_part_001.b64part)
END_OF_PART

# (Повторите для ЧАСТИ 3, 4 и т.д., если они есть, используя add_part 3, add_part 4, ...)


# --- ЭТАП 3: Запуск и очистка ---
# (Выполняется один раз после передачи ВСЕХ частей)

# Укажите в команде общее количество частей (в данном случае 2)
 run_guido 2
```