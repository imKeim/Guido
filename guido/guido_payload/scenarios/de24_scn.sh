#!/bin/bash
# Файл: scenarios/de24_scn.sh
# Содержит определения последовательностей шагов для сценария ДЭ "de24" (пустышка).

# --- Мета-комментарий: Определения сценариев для "de24" (пустышка) ---

# Основная последовательность выполнения (пустая или с одним элементом-заголовком)
declare -ag MAIN_SCN_SEQ=(
    "--- Модуль 1 (Сценарий de24 - Пустышка) ---"
    "--- Модуль 2 (Сценарий de24 - Пустышка) ---"
)

# Сценарии для ролей и модулей (пустые)
declare -ag SCN_ISP_M1=()
declare -ag SCN_ISP_M2=()
declare -ag SCN_HQ_RTR_M1=()
declare -ag SCN_HQ_RTR_M2=()
declare -ag SCN_BR_RTR_M1=()
declare -ag SCN_BR_RTR_M2=()
declare -ag SCN_HQ_SRV_M1=()
declare -ag SCN_HQ_SRV_M2=()
declare -ag SCN_BR_SRV_M1=()
declare -ag SCN_BR_SRV_M2=()
declare -ag SCN_HQ_CLI_M1=()
declare -ag SCN_HQ_CLI_M2=()

log_msg "${P_INFO} ${C_DIM}Загружен файл определений сценариев-пустышек для 'de24'.${C_RESET}" "/dev/null"