#!/bin/bash
# ==============================================================================
# Скрипт сборки артефактов для "Guido" (Оригинальная логика)
#
# 1. Создает самодостаточный 'guido_installer.sh' путем внедрения
#    Base64-кодированной полезной нагрузки.
# 2. При использовании флага --split-oneliner, сжимает готовый
#    'guido_installer.sh', кодирует его в Base64 и разбивает на части.
# ==============================================================================

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
# Для этого режима компрессор всегда xz для максимальной эффективности
COMPRESSOR_CMD="xz -9 -c -T0"
DECOMPRESSOR_CMD_ONELINER="unxz -c"
COMPRESSED_EXT=".xz"

SPLIT_ONELINER_BYTES="" # По умолчанию не разбивать

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
    *)
      echo "Неизвестный параметр: $1"
      exit 1
      ;;
  esac
done

FINAL_INSTALLER_COMPRESSED_BASENAME="${INSTALLER_SH_BASENAME}${COMPRESSED_EXT}"

# === Блок: Подготовка к сборке ===
echo "--- Начало сборки Guido Installer ---"
mkdir -p "$BUILD_OUTPUT_DIR"
echo "Каталог для артефактов сборки: '$BUILD_OUTPUT_DIR'."
if [ ! -d "$PAYLOAD_DIR" ]; then echo "ОШИБКА: Каталог полезной нагрузки '$PAYLOAD_DIR' не найден!"; exit 1; fi
if [ ! -f "$INSTALLER_TEMPLATE_SH" ]; then echo "ОШИБКА: Файл шаблона '$INSTALLER_TEMPLATE_SH' не найден!"; exit 1; fi
echo "Все необходимые исходные файлы и каталоги найдены."
rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"

# === Блок: Сборка основного установщика `guido_installer.sh` ===
echo ""
echo "--- Сборка стандартного скрипта-установщика (guido_installer.sh) ---"
echo "1. Создание архива полезной нагрузки..."
if ! tar -czf "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" -C "$PAYLOAD_DIR" .; then echo "ОШИБКА: Не удалось создать архив."; exit 1; fi

echo "2. Кодирование архива в Base64..."
if ! base64 -w 0 "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" > "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"; then echo "ОШИБКА: Не удалось закодировать архив."; exit 1; fi

echo "3. Внедрение Base64-строки в шаблон установщика..."
payload_base64_content=$(cat "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME")
if [ -z "$payload_base64_content" ]; then echo "ОШИБКА: Содержимое Base64 файла пустое."; exit 1; fi

# Используем оригинальный метод 'awk', который у вас работал
awk -v payload="$payload_base64_content" -v placeholder="$PLACEHOLDER_STRING" '{ if (index($0, placeholder) > 0) { sub(placeholder, payload); } print; }' "$INSTALLER_TEMPLATE_SH" > "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"

if [ $? -eq 0 ] && [ -s "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME" ]; then
    chmod +x "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME"
    echo "Успешно создан: $BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME (Готов для копирования как единый файл)"
else
    echo "ОШИБКА: Не удалось создать финальный '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME' или он пустой."; exit 1;
fi
rm -f "$BUILD_OUTPUT_DIR/$ARCHIVE_NAME_BASENAME" "$BUILD_OUTPUT_DIR/$BASE64_FILE_BASENAME"

# === Блок: Генерация однострочника (если запрошено) ===
if [ -n "$SPLIT_ONELINER_BYTES" ]; then
    echo ""
    echo "--- Начало генерации однострочника (компрессор: xz) ---"
    rm -f "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME" "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME" "$BUILD_OUTPUT_DIR/oneliner_part_"*

    echo "1. Сжатие готового '$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME'..."
    if ! $COMPRESSOR_CMD "$BUILD_OUTPUT_DIR/$INSTALLER_SH_BASENAME" > "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME"; then
        echo "ОШИБКА: Не удалось сжать '$INSTALLER_SH_BASENAME'."
        exit 1
    fi

    echo "2. Кодирование сжатого установщика в Base64..."
    if ! base64 -w 0 "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME" > "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME"; then
        echo "ОШИБКА: Не удалось закодировать сжатый установщик в Base64."; exit 1
    fi
    
    echo "3. Разбиение итоговой Base64-строки на части по $SPLIT_ONELINER_BYTES байт..."
    split -b "$SPLIT_ONELINER_BYTES" -a 3 -d --additional-suffix="${COMPRESSED_EXT}.b64part" "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME" "$BUILD_OUTPUT_DIR/oneliner_part_"
    
    if [ $? -eq 0 ]; then
        total_parts_created=$(ls "$BUILD_OUTPUT_DIR"/oneliner_part_*.b64part 2>/dev/null | wc -l)
        echo "Однострочник успешно разбит на $total_parts_created частей."
        echo "Части сохранены в: $BUILD_OUTPUT_DIR/oneliner_part_*.b64part"
    else
        echo "ОШИБКА: Не удалось разбить однострочник на части."
    fi
    
    # Очистка
    rm -f "$BUILD_OUTPUT_DIR/$FINAL_INSTALLER_COMPRESSED_BASENAME" "$BUILD_OUTPUT_DIR/$FINAL_BASE64_ONELINER_FILE_BASENAME"
fi

echo ""
echo "--- Сборка завершена ---"
exit 0