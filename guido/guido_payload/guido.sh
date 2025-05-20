#!/bin/bash

# ==========================================================================================================================
# Скрипт "Guido (General Utility of Infrastructure Deployment Operations)"
# Версия: 2.3.1 (Рефакторинг: Этап 3 - Механизм выбора сценария, Шаг 2 - Интерактивное меню)
# ==========================================================================================================================
# Запуск скрипта:
# ./guido.sh --pretty --sneaky
# ./guido.sh --scenario de2025 --pretty
# Или: ./guido.sh -c de2025 --pretty
# ==========================================================================================================================

# === Блок: Начальное определение критически важных переменных и путей ===
if [[ -n "$GUIDO_TEMP_DEPLOY_DIR" && -d "$GUIDO_TEMP_DEPLOY_DIR" ]]; then
    SCRIPT_DIR="$GUIDO_TEMP_DEPLOY_DIR"
    SCRIPT_PTH_DEL="${SCRIPT_DIR}/guido.sh"
    echo "[INFO][Guido Bootstrap] Guido запущен из временного каталога: ${SCRIPT_DIR}" >&2
else
    if [[ "$0" == /* ]]; then SCRIPT_PTH_DEL="$0"; else SCRIPT_PTH_DEL="$(pwd)/$0"; fi
    SCRIPT_PTH_DEL=$(readlink -f "$SCRIPT_PTH_DEL" 2>/dev/null || echo "$SCRIPT_PTH_DEL")
    SCRIPT_DIR=$(dirname "$SCRIPT_PTH_DEL")
    echo "[INFO][Guido Bootstrap] Guido запущен в стандартном режиме. SCRIPT_DIR: ${SCRIPT_DIR}" >&2
fi

CORE_LIB_DIR="${SCRIPT_DIR}/core_lib"
SCENARIOS_DIR="${SCRIPT_DIR}/scenarios"
FX_LIB_DIR="${SCRIPT_DIR}/fx_lib"
export CORE_LIB_DIR SCENARIOS_DIR FX_LIB_DIR SCRIPT_DIR SCRIPT_PTH_DEL GUIDO_TEMP_DEPLOY_DIR

if [ -z "$FLAG_DIR_BASE" ]; then
    FLAG_DIR_BASE="/var/tmp/exam_deploy_flags_v2"
fi
mkdir -p "$FLAG_DIR_BASE" 2>/dev/null

# === Блок: Подключение базовых библиотек (vars.sh и utils.sh) и инициализация цветов ===
if [[ -f "${CORE_LIB_DIR}/vars.sh" ]]; then
    # shellcheck source=core_lib/vars.sh
    source "${CORE_LIB_DIR}/vars.sh"
else
    echo "[CRITICAL ERROR][Guido Bootstrap] Файл ${CORE_LIB_DIR}/vars.sh не найден!" >&2; exit 1
fi
if [[ -f "${CORE_LIB_DIR}/utils.sh" ]]; then
    # shellcheck source=core_lib/utils.sh
    source "${CORE_LIB_DIR}/utils.sh"
else
    echo "[CRITICAL ERROR][Guido Bootstrap] Файл ${CORE_LIB_DIR}/utils.sh не найден!" >&2
    if [[ "$g_pretty_mode_en" == "y" ]]; then init_colors_pfx; fi
    log_msg "${P_ERROR} Файл ${CORE_LIB_DIR}/utils.sh не найден!" "/dev/tty"; exit 1
fi
init_colors_pfx

# === Блок: Подключение menu.sh (нужен для select_de_scenario) ===
if [[ -f "${CORE_LIB_DIR}/menu.sh" ]]; then
    # shellcheck source=core_lib/menu.sh
    source "${CORE_LIB_DIR}/menu.sh"
else
    log_msg "${P_ERROR} Файл ${CORE_LIB_DIR}/menu.sh не найден!" "/dev/tty"; exit 1
fi

# === Блок: Обработка аргументов командной строки и определение сценария ===
g_pretty_arg_ovr="n"
g_sneaky_arg_ovr="n"
arg_scenario_name=""

temp_args=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --pretty|-p) g_pretty_arg_ovr="y"; g_pretty_mode_en="y"; init_colors_pfx; shift ;;
        --sneaky|-s) g_sneaky_arg_ovr="y"; g_sneaky_mode_en="y"; shift ;;
        --scenario|-c)
            if [[ -n "$2" && "$2" != --* && "$2" != -* ]]; then
                arg_scenario_name="$2"; shift 2;
            else
                log_msg "${P_ERROR} Опция $key требует значение." "/dev/tty"; shift;
            fi ;;
        *) temp_args+=("$1"); shift ;;
    esac
done

# Логика выбора сценария
scenario_selected_successfully=0
if [[ -n "$arg_scenario_name" ]]; then
    log_msg "${P_INFO} Сценарий указан в аргументах: ${C_CYAN}$arg_scenario_name${C_RESET}" "/dev/tty"
    if check_scenario_exists "$arg_scenario_name"; then
        g_cur_de_scenario_name="$arg_scenario_name"
        log_msg "${P_OK} Сценарий '${C_GREEN}$g_cur_de_scenario_name${P_OK}' найден и будет использован." "/dev/tty"
        scenario_selected_successfully=1
    else
        log_msg "${P_ERROR} Указанный сценарий '${C_BOLD_RED}$arg_scenario_name${P_ERROR}' не найден или неполный." "/dev/tty"
        pause_pmt "Нажмите Enter для выбора другого сценария..."
        if select_de_scenario; then # select_de_scenario обновит g_cur_de_scenario_name
            scenario_selected_successfully=1
        else
            log_msg "${P_ERROR} Выбор сценария не был сделан или отменен. Выход." "/dev/tty"; exit 1
        fi
    fi
else
    # Сценарий не указан в аргументах, пытаемся использовать default (g_cur_de_scenario_name из vars.sh)
    if check_scenario_exists "$g_cur_de_scenario_name"; then
        log_msg "${P_INFO} Сценарий по умолчанию '${C_GREEN}$g_cur_de_scenario_name${P_INFO}' найден и будет использован." "/dev/tty"
        scenario_selected_successfully=1
    else
        log_msg "${P_WARN} Сценарий по умолчанию '${C_YELLOW}$g_cur_de_scenario_name${P_WARN}' не найден или неполный." "/dev/tty"
        pause_pmt "Нажмите Enter для выбора другого сценария..."
        if select_de_scenario; then # select_de_scenario обновит g_cur_de_scenario_name
            scenario_selected_successfully=1
        else
            log_msg "${P_ERROR} Выбор сценария не был сделан или отменен. Выход." "/dev/tty"; exit 1
        fi
    fi
fi

if [[ "$scenario_selected_successfully" -eq 0 ]]; then # Дополнительная проверка
    log_msg "${P_ERROR} Не удалось определить или выбрать действительный сценарий. Выход." "/dev/tty"
    exit 1
fi
export g_cur_de_scenario_name

log_msg "${P_INFO} Активный сценарий ДЭ: ${C_GREEN}${g_cur_de_scenario_name}${C_RESET}" "/dev/tty"

# === Блок: Загрузка файлов выбранного сценария и остальных библиотек ===
SCENARIO_CFG_FILE="${SCENARIOS_DIR}/${g_cur_de_scenario_name}_cfg.sh"
SCENARIO_SCN_FILE="${SCENARIOS_DIR}/${g_cur_de_scenario_name}_scn.sh"

# Финальная проверка перед загрузкой (хотя check_scenario_exists уже должна была это сделать)
if [[ ! -f "$SCENARIO_CFG_FILE" || ! -f "$SCENARIO_SCN_FILE" || ! -d "${FX_LIB_DIR}/${g_cur_de_scenario_name}" ]]; then
    log_msg "${P_ERROR} Критическая ошибка: Не найдены все компоненты для сценария '${C_BOLD_RED}$g_cur_de_scenario_name${P_ERROR}'. Выход." "/dev/tty"
    exit 1
fi

log_msg "${P_INFO} ${C_DIM}Загрузка конфигурации сценария: ${SCENARIO_CFG_FILE}${C_RESET}" "/dev/null"
# shellcheck source=/dev/null
source "$SCENARIO_CFG_FILE"
log_msg "${P_INFO} ${C_DIM}Загрузка определений сценария: ${SCENARIO_SCN_FILE}${C_RESET}" "/dev/null"
# shellcheck source=/dev/null
source "$SCENARIO_SCN_FILE"

# Подключаем файл с утилитами для sneaky режима и обработчиком выхода
if [[ -f "${CORE_LIB_DIR}/sneaky_utils.sh" ]]; then
    # shellcheck source=core_lib/sneaky_utils.sh
    source "${CORE_LIB_DIR}/sneaky_utils.sh"
else
    log_msg "${P_ERROR} Файл ${CORE_LIB_DIR}/sneaky_utils.sh не найден!" "/dev/tty"; exit 1
fi
# menu.sh уже подключен выше

# === Блок: Вызов начальной очистки истории (если включен sneaky режим) ===
if [[ "$g_sneaky_mode_en" == "y" ]]; then
    sneaky_init_hist_clean
fi

# ==========================================================================================================================
# Блок: Точка входа в скрипт
# ==========================================================================================================================

if [[ $EUID -ne 0 ]]; then
   log_msg "${P_ERROR} Этот скрипт должен быть запущен от имени суперпользователя (root)." "/dev/tty"
   exit 1
fi

trap 'on_exit $?' EXIT SIGINT SIGTERM

clear
log_msg "${C_BOLD_BLUE}Добро пожаловать в \"Guido\" - утилиту настройки стенда демонстрационного экзамена!${C_RESET}" "/dev/tty"
print_sep
log_msg "${P_INFO} Версия скрипта: 2.3.1 (Сценарий: ${C_CYAN}${g_cur_de_scenario_name}${C_RESET})" "/dev/tty"
log_msg "${P_INFO} ${C_BOLD_YELLOW}Важное замечание:${C_RESET} ${C_BOLD_BLUE}Для корректной работы некоторых шагов (установка пакетов) необходимо активное Интернет-соединение.${C_RESET}" "/dev/tty"
print_sep

if ! det_vm_role; then
    log_msg "${P_WARN} Не удалось автоматически определить роль текущей ВМ (на основе: '${C_CYAN}$g_eff_hn_for_role${P_WARN}')." "/dev/tty"
    pause_pmt "Нажмите Enter для ручного выбора роли."
    ask_vm_role
else
    log_msg "${P_OK} Автоматически определена роль ВМ: ${C_GREEN}$g_cur_vm_role${C_RESET} (на основе имени хоста: ${C_CYAN}$g_eff_hn_for_role${C_RESET})" "/dev/tty"
    pause_pmt "Нажмите Enter для входа в главное меню."
fi

main_menu