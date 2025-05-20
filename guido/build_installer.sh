#!/bin/bash

# === Блок: Определение путей и констант для сборки ===
PAYLOAD_DIR="guido_payload"
INSTALLER_TEMPLATE_SH="guido_installer.template.sh"
INSTALLER_SH_BASENAME="guido_installer.sh"
ARCHIVE_NAME_BASENAME="guido_payload.tar.gz"
BASE64_FILE_BASENAME="guido_payload_base64.txt"
FINAL_BASE64_ONELINER_FILE_BASENAME="guido_installer.oneliner.txt"
BUILD_OUTPUT_DIR="build_output"
PLACEHOLDER_STRING="%%PAYLOAD_BASE64_CONTENT%%"

# === Блок: Обработка аргументов командной строки ===
COMPRESSOR_TYPE="gzip" # По умолчанию
SPLIT_ONELINER_BYTES="" # По умолчанию не разбивать

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --compressor)
      COMPRESSOR_TYPE="$2"
      shift 2
      ;;
    --split-oneliner)
      SPLIT_ONELINER_BYTES="$2"
      if ! [[ "$SPLIT_ONELINER_BYTES" =~ ^[0-9]+$ ]] || [[ "$SPLIT_ONELINER_BYTES" -le 0 ]]; then
        echo "ОШИБКА: Значение для --split-oneliner должно быть положительным числом (байты)."
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Неизвестный параметр: $1"
      exit 1
      ;;
  esac
done

# === Блок: Настройка компрессора ===
COMPRESSOR_CMD=""
DECOMPRESSOR_CMD_ONELINER=""
COMPRESSED_EXT=""

if [[ "$COMPRESSOR_TYPE" == "gzip" ]]; then
    COMPRESSOR_CMD="gzip -9 -c"
    DECOMPRESSOR_CMD_ONELINER="gunzip -c"
    COMPRESSED_EXT=".gz"
    echo "Используется компрессор: gzip (максимальное сжатие)"
elif [[ "$COMPRESSOR_TYPE" == "xz" ]]; then
    if ! command -v xz &> /dev/null; then
        echo "ОШИБКА: Компрессор 'xz' выбран, но команда 'xz' не найдена в системе."
        exit 1
    fi
    COMPRESSOR_CMD="xz -9 -c -T0"
    DECOMPRESSOR_CMD_ONELINER="unxz -c"
    COMPRESSED_EXT=".xz"
    echo "Используется компрессор: xz (максимальное сжатие, все ядра)"
else
    echo "ОШИБКА: Неподдерживаемый тип компрессора '$COMPRESSOR_TYPE'. Доступные: gzip, xz."
    exit 1
fi

FINAL_INSTALLER_COMPRESSED_BASENAME="${INSTALLER_SH_BASENAME}${COMPRESSED_EXT}"

generate_split_instructions() {
    local oneliner_file_path="$1"
    local split_bytes="$2"
    local decompressor_cmd="$3"
    # local oneliner_filename_no_path # Не используется в этой версии функции
    # oneliner_filename_no_path=$(basename "$oneliner_file_path")

    local part_files_list
    # Используем find и mapfile для надежного получения списка файлов частей, отсортированных по имени
    mapfile -d $'\0' -t part_files_list < <(find "$BUILD_OUTPUT_DIR" -maxdepth 1 -name "oneliner_part_*" -print0 | sort -z)

    if [ ${#part_files_list[@]} -eq 0 ]; then
        echo "ОШИБКА: Не найдены файлы частей однострочника в '$BUILD_OUTPUT_DIR/' с префиксом 'oneliner_part_'."
        return 1
    fi

    echo ""
    echo "##################################################################################"
    echo "### ИНСТРУКЦИИ ПО ПЕРЕДАЧЕ И ЗАПУСКУ ОДНОСТРОЧНИКА ЧАСТЯМИ ###"
    echo "##################################################################################"
    echo ""
    echo "Однострочник был разбит на ${#part_files_list[@]} частей. Файлы частей находятся в каталоге '$BUILD_OUTPUT_DIR/'."
    echo "Вам нужно будет передать содержимое КАЖДОГО файла-части на целевую машину."
    echo "Для минимизации следов в истории команд Bash на целевой машине, вы можете:"
    echo "  а) Начинать каждую команду с ПРОБЕЛА (если HISTCONTROL настроен на ignorespace или ignoreboth)."
    echo "  б) Временно отключить историю: 'set +o history' (не забудьте включить обратно: 'set -o history')."
    echo ""
    echo "----------------------------------------------------------------------------------"
    echo "ЭТАП 1: Подготовка на ЦЕЛЕВОЙ машине"
    echo "----------------------------------------------------------------------------------"
    echo "1.1. Создайте временный файл для сборки Base64-строки. Выполните на ЦЕЛЕВОЙ машине:"
    echo '     export TMP_B64_ASSEMBLY_FILE=$(mktemp --tmpdir=/dev/shm guido_payload.XXXXXX.b64 2>/dev/null) || export TMP_B64_ASSEMBLY_FILE=$(mktemp /tmp/guido_payload.XXXXXX.b64)'
    echo '     echo "Временный файл для сборки создан: $TMP_B64_ASSEMBLY_FILE"'
    echo ""
    echo "----------------------------------------------------------------------------------"
    echo "ЭТАП 2: Передача КАЖДОЙ части на ЦЕЛЕВУЮ машину"
    echo "----------------------------------------------------------------------------------"
    local i=0
    for part_file in "${part_files_list[@]}"; do
        i=$((i+1))
        local part_filename_no_path
        part_filename_no_path=$(basename "$part_file")
        echo ""
        echo "   <<< Передача ЧАСТИ $i из ${#part_files_list[@]} (файл на машине сборки: '$part_filename_no_path') >>>"
        echo ""
        echo "   2.$i.A: На машине СБОРКИ, просмотрите и скопируйте ВЕСЬ текстовый блок из файла '$part_filename_no_path':"
        echo "           cat \"$part_file\""
        echo ""
        echo "   2.$i.Б: На ЦЕЛЕВОЙ машине, вставьте следующую команду ПОЛНОСТЬЮ и нажмите Enter:"
        echo "           (Эта команда начнет принимать многострочный ввод до маркера 'END_OF_GUIDO_PART')"
        echo '           cat <<'"'END_OF_GUIDO_PART'"' >> "\$TMP_B64_ASSEMBLY_FILE"'
        echo ""
        echo "   2.$i.В: Сразу после выполнения команды из шага 2.$i.Б, ВСТАВЬТЕ скопированный на шаге 2.$i.А"
        echo "           текстовый блок (содержимое файла-части) и нажмите Enter."
        echo ""
        echo "   2.$i.Г: Затем, на НОВОЙ СТРОКЕ введите ТОЧНО 'END_OF_GUIDO_PART' (без кавычек и пробелов)"
        echo "           и нажмите Enter. Это завершит добавление текущей части в файл."
        echo ""
        echo "           Пример того, что должно быть в терминале целевой машины для ОДНОЙ части:"
        echo "           ~$ # cat <<'END_OF_GUIDO_PART' >> \"\$TMP_B64_ASSEMBLY_FILE\"  <-- (нажали Enter)"
        echo "           > [СЮДА ВСТАВЛЕН БОЛЬШОЙ БЛОК BASE64 ИЗ ФАЙЛА ЧАСТИ]       <-- (нажали Enter)"
        echo "           > END_OF_GUIDO_PART                                      <-- (нажали Enter)"
        echo "           ~$ #"
        echo ""
        echo "   Повторите шаги 2.X.А - 2.X.Г для ВСЕХ оставшихся частей."
    done
    echo ""
    echo "----------------------------------------------------------------------------------"
    echo "ЭТАП 3: Запуск скрипта и очистка на ЦЕЛЕВОЙ машине"
    echo "----------------------------------------------------------------------------------"
    echo "3.1. После передачи ВСЕХ частей, выполните на ЦЕЛЕВОЙ машине одну из следующих команд:"
    echo ""
    echo "     Для запуска Guido с аргументами (например, --sneaky --pretty):"
    echo "     base64 -d \"\$TMP_B64_ASSEMBLY_FILE\" | $decompressor_cmd | bash -s -- --sneaky --pretty ; \\"
    echo "       echo 'Скрипт Guido завершен. Удаляю временный файл \$TMP_B64_ASSEMBLY_FILE.' ; \\"
    echo "       rm -f \"\$TMP_B64_ASSEMBLY_FILE\"; unset TMP_B64_ASSEMBLY_FILE"
    echo ""
    echo "     Или для запуска Guido БЕЗ аргументов:"
    echo "     base64 -d \"\$TMP_B64_ASSEMBLY_FILE\" | $decompressor_cmd | bash ; \\"
    echo "       echo 'Скрипт Guido завершен. Удаляю временный файл \$TMP_B64_ASSEMBLY_FILE.' ; \\"
    echo "       rm -f \"\$TMP_B64_ASSEMBLY_FILE\"; unset TMP_B64_ASSEMBLY_FILE"
    echo ""
    echo "3.2. (Опционально) Если вы временно отключали историю командой 'set +o history', не забудьте ее включить:"
    echo "      set -o history"
    echo ""
    echo "##################################################################################"
    echo "### Конец инструкций ###"
    echo "##################################################################################"
}

# === Блок: Подготовка к сборке ===
# (Как в предыдущей версии: создание BUILD_OUTPUT_DIR, проверки PAYLOAD_DIR, INSTALLER_TEMPLATE_SH)
echo "--- Начало сборки Guido Installer ---"
mkdir -p "$BUILD_OUTPUT_DIR"
echo "Каталог для артефактов сборки: '$BUILD_OUTPUT_DIR'."
if [ ! -d "$PAYLOAD_DIR" ]; then echo "ОШИБКА: Каталог полезной нагрузки '$PAYLOAD_DIR' не найден!"; exit 1; fi
echo "Каталог полезной нагрузки '$PAYLOAD_DIR' найден."
if [ ! -f "$INSTALLER_TEMPLATE_SH" ]; then echo "ОШИБКА: Файл шаблона '$INSTALLER_TEMPLATE_SH' не найден!"; exit 1; fi
if ! grep -qF "$PLACEHOLDER_STRING" "$INSTALLER_TEMPLATE_SH"; then echo "ОШИБКА: Плейсхолдер '$PLACEHOLDER_STRING' не найден в '$INSTALLER_TEMPLATE_SH'!"; exit 1; fi
echo "Шаблон установщика '$INSTALLER_TEMPLATE_SH' найден и содержит плейсхолдер."
rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"
echo "Старые артефакты полезной нагрузки удалены из '$BUILD_OUTPUT_DIR' (если существовали)."

# === Блок: Сборка основного установщика `guido_installer.sh` ===
# (Как в предыдущей версии: tar, base64 полезной нагрузки, awk для замены плейсхолдера, chmod)
echo "--- Сборка стандартного скрипта Guido Installer ---"
echo "Создание архива '$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME' из '$PAYLOAD_DIR'..."
if ! tar -czvf "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" -C "$PAYLOAD_DIR" .; then echo "ОШИБКА: Не удалось создать архив."; exit 1; fi
echo "Архив '$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME' успешно создан."
echo "Кодирование архива в Base64 (файл '$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME')..."
if ! base64 -w 0 "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" > "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"; then echo "ОШИБКА: Не удалось закодировать архив."; rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME"; exit 1; fi
echo "Архив успешно закодирован."
payload_base64_content=$(cat "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME")
if [ -z "$payload_base64_content" ]; then echo "ОШИБКА: Содержимое Base64 файла пустое."; rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"; exit 1; fi
echo "Содержимое Base64 прочитано."
echo "Создание финального '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME'..."
awk -v payload="$payload_base64_content" -v placeholder="$PLACEHOLDER_STRING" '{ if (index($0, placeholder) > 0) { sub(placeholder, payload); } print; }' "$INSTALLER_TEMPLATE_SH" > "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"
if [ $? -eq 0 ] && [ -s "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME" ]; then
    if grep -qF "$PLACEHOLDER_STRING" "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"; then echo "ОШИБКА: Плейсхолдер все еще присутствует в финальном установщике!"; exit 1; fi
    echo "Финальный '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME' успешно создан."
    chmod +x "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"
    echo "Права на выполнение установлены."
else
    echo "ОШИБКА: Не удалось создать финальный '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME' или он пустой."; rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"; exit 1;
fi
rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"
echo "Временные файлы полезной нагрузки удалены."
echo "--- Сборка стандартного скрипта Guido Installer успешно завершена ---"
echo "Результат: $BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"

# === Блок: Генерация однострочника для полной доставки ===
echo ""
echo "--- Начало генерации однострочника (компрессор: $COMPRESSOR_TYPE) ---"
rm -f "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME" "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME"
echo "Сжатие '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME' в '$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME'..."
# shellcheck disable=SC2086
if $COMPRESSOR_CMD "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME" > "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME"; then
    echo "Установщик успешно сжат."
else
    echo "ОШИБКА: Не удалось сжать '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME' с помощью '$COMPRESSOR_CMD'."
    exit 1
fi
echo "Кодирование сжатого установщика в Base64 (файл '$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME')..."
if base64 -w 0 "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME" > "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME"; then
    oneliner_content_length=$(wc -c < "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME")
    compressed_file_size=$(wc -c < "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME")
    original_file_size=$(wc -c < "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME")

    echo "Сжатый установщик успешно закодирован."
    echo "Размеры: Оригинал: $original_file_size байт | Сжатый ($COMPRESSOR_TYPE): $compressed_file_size байт | Base64: $oneliner_content_length байт."
    echo ""
    if [ -z "$SPLIT_ONELINER_BYTES" ]; then
        echo "Для запуска на целевой машине (если строка помещается):"
        echo "echo \"\$(cat $BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME)\" | base64 -d | $DECOMPRESSOR_CMD_ONELINER | bash -s -- --sneaky --pretty"
        echo ""
        echo "Содержимое файла '$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME' готово для копирования."
    fi
else
    echo "ОШИБКА: Не удалось закодировать сжатый установщик в Base64."
    rm -f "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME"; exit 1;
fi
rm -f "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME"
echo "Временный файл сжатого установщика удален."

if [ -n "$SPLIT_ONELINER_BYTES" ]; then
    echo "Разбиение '$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME' на части по $SPLIT_ONELINER_BYTES байт..."
    # Удаляем старые части, если они есть
    rm -f "$BUILD_OUTPUT_DIR/oneliner_part_"*
    split -b "$SPLIT_ONELINER_BYTES" -a 3 -d --additional-suffix="${COMPRESSED_EXT}.b64part" "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME" "$BUILD_OUTPUT_DIR/oneliner_part_"
    if [ $? -eq 0 ]; then
        echo "Однострочник успешно разбит на части."
        generate_split_instructions "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME" "$SPLIT_ONELINER_BYTES" "$DECOMPRESSOR_CMD_ONELINER"
    else
        echo "ОШИБКА: Не удалось разбить однострочник на части."
    fi
fi

echo "--- Генерация однострочника успешно завершена ---"
echo "Файл с полным однострочником (если не разбит): $BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME"
if [ -n "$SPLIT_ONELINER_BYTES" ]; then
  echo "Части однострочника сохранены в: $BUILD_OUTPUT_DIR/oneliner_part_*"
fi

exit 0