#!/bin/bash
# ==============================================================================
# Скрипт сборки артефактов для "Guido"
#
# РЕЖИМЫ РАБОТЫ:
#
#   1. По умолчанию (./build_installer.sh):
#      Создает один файл 'guido_installer.oneliner.txt' с использованием
#      эффективного метода (tar -> xz -> base64).
#
#   2. С разделением (--split-oneliner [размер]):
#      Делает то же, что и по умолчанию, но дополнительно разбивает
#      однострочник на части 'oneliner_part_*'.
#
#   3. Устаревший режим (--legacy-installer):
#      Создает самодостаточный скрипт 'guido_installer.sh', который удобен
#      для распространения единым файлом, но неэффективен для передачи
#      через консоль.
# ==============================================================================

# === Блок: Определение путей и констант для сборки ===
PAYLOAD_DIR="guido_payload"
BUILD_OUTPUT_DIR="build_output"

# Константы для самодостаточного установщика (устаревший режим)
INSTALLER_TEMPLATE_SH="guido_installer.template.sh"
INSTALLER_SH_BASENAME="guido_installer.sh"
PLACEHOLDER_STRING="%%PAYLOAD_BASE64_CONTENT%%"

# Константы для эффективного однострочника (режим по умолчанию)
ONELINER_PAYLOAD_ARCHIVE_BASENAME="guido_payload.oneliner.tar.xz"
ONELINER_B64_BASENAME="guido_installer.oneliner.txt" # Изменено для консистентности

# === Блок: Обработка аргументов командной строки ===
SPLIT_ONELINER_BYTES=""
LEGACY_MODE="no"

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --split-oneliner)
      SPLIT_ONELINER_BYTES="$2"
      if ! [[ "$SPLIT_ONELINER_BYTES" =~ ^[0-9]+$ ]] || [[ "$SPLIT_ONELINER_BYTES" -le 0 ]]; then
        echo "ОШИБКА: Значение для --split-oneliner должно быть положительным числом (байты)."
        exit 1
      fi
      shift 2
      ;;
    --legacy-installer)
      LEGACY_MODE="yes"
      shift
      ;;
    *)
      echo "Неизвестный параметр: $1"
      exit 1
      ;;
  esac
done

# === Блок: Функция генерации инструкций для пользователя ===
generate_split_instructions() {
    local total_parts="$1"
    echo ""
    echo "##################################################################################"
    echo "###                      ИНСТРУКЦИИ ПО ПЕРЕДАЧЕ И ЗАПУСКУ                      ###"
    echo "##################################################################################"
    echo ""
    echo "Однострочник был разбит на ${total_parts} частей. Файлы частей находятся в каталоге '$BUILD_OUTPUT_DIR/'."
    echo "Полные и готовые к копированию инструкции находятся в файле: docs/bootstrap.md"
    echo ""
    echo "--- Краткий план действий на целевой машине ---"
    echo "1. ЭТАП 1: Скопируйте и вставьте большой подготовительный блок из 'docs/bootstrap.md'."
    echo "2. ЭТАП 2: Для каждой части (с 1 по ${total_parts}) выполните:"
    echo "   а) Напишите в терминале:  add_part [номер_части]"
    echo "   б) Вставьте содержимое файла 'oneliner_part_XXX.b64part'."
    echo "   в) На новой строке напишите: END_OF_PART"
    echo "3. ЭТАП 3: После добавления всех частей, выполните команду:  run_guido ${total_parts}"
    echo ""
    echo "##################################################################################"
}

# === Блок: Подготовка к сборке ===
echo "--- Начало сборки артефактов Guido ---"
mkdir -p "$BUILD_OUTPUT_DIR"
echo "Каталог для артефактов сборки: '$BUILD_OUTPUT_DIR'."
if [ ! -d "$PAYLOAD_DIR" ]; then echo "ОШИБКА: Каталог полезной нагрузки '$PAYLOAD_DIR' не найден!"; exit 1; fi
if [ ! -f "$INSTALLER_TEMPLATE_SH" ]; then echo "ОШИБКА: Файл шаблона '$INSTALLER_TEMPLATE_SH' не найден!"; exit 1; fi
echo "Все необходимые исходные файлы и каталоги найдены."

# ==============================================================================
# ОСНОВНАЯ ЛОГИКА: ВЫБОР РЕЖИМА СБОРКИ
# ==============================================================================

if [ "$LEGACY_MODE" == "yes" ]; then
    # --- РЕЖИМ 1: Сборка устаревшего самодостаточного установщика ---
    echo ""
    echo "--- Сборка в режиме --legacy-installer: создается guido_installer.sh ---"
    temp_archive_gz="$BUILD_OUTPUT_DIR/temp_payload.tar.gz"
    temp_base64_txt="$BUILD_OUTPUT_DIR/temp_payload_b64.txt"
    final_installer_path="$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"
    rm -f "$temp_archive_gz" "$temp_base64_txt"

    echo "1. Создание архива полезной нагрузки..."
    if ! tar -czf "$temp_archive_gz" -C "$PAYLOAD_DIR" . ; then echo "ОШИБКА: Не удалось создать архив."; exit 1; fi

    echo "2. Кодирование архива в Base64..."
    if ! base64 -w 0 "$temp_archive_gz" > "$temp_base64_txt"; then echo "ОШИБКА: Не удалось закодировать архив."; rm -f "$temp_archive_gz"; exit 1; fi

    echo "3. Внедрение Base64-строки в шаблон установщика..."
    if ! sed -e "/${PLACEHOLDER_STRING}/r ${temp_base64_txt}" -e "/${PLACEHOLDER_STRING}/d" "${INSTALLER_TEMPLATE_SH}" > "${final_installer_path}"; then
        echo "ОШИБКА: Не удалось выполнить подстановку с помощью sed."; exit 1
    fi

    if [ -s "$final_installer_path" ]; then
        chmod +x "$final_installer_path"
        echo "Успешно создан: $final_installer_path (Готов для копирования как единый файл)"
    else
        echo "ОШИБКА: Не удалось создать финальный '$final_installer_path' или он пустой.";
    fi
    rm -f "$temp_archive_gz" "$temp_base64_txt"

else
    # --- РЕЖИМ 2: Сборка эффективного однострочника (по умолчанию) ---
    echo ""
    echo "--- Сборка в режиме по умолчанию: создается эффективный однострочник ---"
    
    if ! command -v xz &> /dev/null; then echo "ОШИБКА: Для этого режима требуется компрессор 'xz'."; exit 1; fi

    temp_archive_xz="$BUILD_OUTPUT_DIR/$ONELINER_PAYLOAD_ARCHIVE_BASENAME"
    final_oneliner_path="$BUILD_OUTPUT_DIR/$ONELINER_B64_BASENAME"
    rm -f "$temp_archive_xz" "$final_oneliner_path" "$BUILD_OUTPUT_DIR/oneliner_part_"*

    echo "1. Архивируем и сжимаем '$PAYLOAD_DIR' напрямую (tar | xz)..."
    if ! tar -c -C "$PAYLOAD_DIR" . | xz -9 -c -T0 > "$temp_archive_xz"; then
        echo "ОШИБКА: Не удалось создать сжатый архив полезной нагрузки."; exit 1
    fi
    
    echo "2. Кодируем сжатый архив в Base64..."
    if ! base64 -w 0 "$temp_archive_xz" > "$final_oneliner_path"; then
        echo "ОШИБКА: Не удалось закодировать сжатый архив в Base64."; rm -f "$temp_archive_xz"; exit 1
    fi

    original_payload_size=$(du -sb "$PAYLOAD_DIR" | awk '{print $1}')
    compressed_payload_size=$(wc -c < "$temp_archive_xz")
    final_b64_size=$(wc -c < "$final_oneliner_path")
    echo "Размеры: Исходный payload: $original_payload_size байт | Сжатый (tar.xz): $compressed_payload_size байт | Итоговый Base64: $final_b64_size байт."
    echo "Успешно создан: $final_oneliner_path"

    # Дополнительный шаг: разбиение на части, если указан флаг
    if [ -n "$SPLIT_ONELINER_BYTES" ]; then
        echo ""
        echo "3. Разбиение итоговой Base64-строки на части по $SPLIT_ONELINER_BYTES байт..."
        split -b "$SPLIT_ONELINER_BYTES" -a 3 -d --additional-suffix=".b64part" "$final_oneliner_path" "$BUILD_OUTPUT_DIR/oneliner_part_"
        
        if [ $? -eq 0 ]; then
            total_parts_created=$(ls "$BUILD_OUTPUT_DIR"/oneliner_part_*.b64part 2>/dev/null | wc -l)
            echo "Однострочник успешно разбит на $total_parts_created частей."
            echo "Части сохранены в: $BUILD_OUTPUT_DIR/oneliner_part_*.b64part"
            generate_split_instructions "$total_parts_created"
        else
            echo "ОШИБКА: Не удалось разбить однострочник на части."
        fi
    fi

    # Очистка временных файлов
    rm -f "$temp_archive_xz"
fi

echo ""
echo "--- Сборка завершена ---"
exit 0