#!/bin/bash
# Файл: core_lib/utils.sh
# Содержит общие вспомогательные функции.
# Этот файл подключается (source) основным скриптом Guido.

# --- Мета-комментарий: Общие вспомогательные функции ---

# === Блок: Функции логирования и вывода ===

# --- Функция: log_msg ---
# Назначение: Выводит сообщение с учетом настроек цветов и логирования.
# Параметры:
#   $1: Строка сообщения (может содержать ANSI-коды).
#   $2 (опционально): Устройство вывода (например, /dev/tty). По умолчанию - stdout.
log_msg() {
    local msg_colors_param="$1"
    local out_tty_param="${2:-}"
    local msg_nocolors_content
    # Удаление ANSI-кодов для логирования и вывода без цветов
    msg_nocolors_content=$(echo -e "${msg_colors_param}" | sed -E 's/\x1b\[[0-9;]*[mGKHFJU]//g')
    if [[ "$g_pretty_mode_en" == "y" && -n "$C_RESET" ]]; then
        if [[ -n "$out_tty_param" ]]; then
            echo -e "${msg_colors_param}${C_RESET}" > "$out_tty_param"
        else
            echo -e "${msg_colors_param}${C_RESET}"
        fi
    else
        if [[ -n "$out_tty_param" ]]; then
            echo -e "${msg_nocolors_content}" > "$out_tty_param"
        else
            echo -e "${msg_nocolors_content}"
        fi
    fi
    if [[ "$g_log_en" == "y" && -n "$g_log_pth" ]]; then
        printf "%s - %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${msg_nocolors_content}" >> "$g_log_pth"
    fi
}
# --- Функция: init_colors_pfx ---
# Назначение: Инициализирует переменные для ANSI-цветов и префиксов сообщений.
init_colors_pfx() {
    if [[ "$g_pretty_mode_en" == "y" ]]; then
        C_RESET='\033[0m'; C_BOLD_BLUE='\033[1;34m'; C_GREEN='\033[0;32m'
        C_BOLD_YELLOW='\033[1;33m'; C_BOLD_RED='\033[1;31m'; C_CYAN='\033[0;36m'
        C_BOLD_MAGENTA='\033[1;35m'; C_DIM='\033[2m'
    else
        C_RESET=''; C_BOLD_BLUE=''; C_GREEN=''; C_BOLD_YELLOW=''; C_BOLD_RED=''
        C_CYAN=''; C_BOLD_MAGENTA=''; C_DIM=''
    fi
    P_INFO="${C_BOLD_BLUE}[INFO]${C_RESET}"; P_OK="${C_GREEN}[OK]${C_RESET}"
    P_WARN="${C_BOLD_YELLOW}[WARN]${C_RESET}"; P_ERROR="${C_BOLD_RED}[ERROR]${C_RESET}"
    P_PROMPT="${C_CYAN}[PROMPT]${C_RESET}"; P_ACTION="${C_BOLD_MAGENTA}[ACTION]${C_RESET}"
    P_STEP="${C_BOLD_BLUE}[STEP]${C_RESET}";
    # P_CMD не используется, можно удалить, если не планируется.
}
# === Блок: Функции для интерфейса и ввода ===

# --- Функция: print_sep ---
# Назначение: Выводит строку-разделитель.
print_sep() {
    log_msg "${C_BOLD_BLUE}--------------------------------------------------------------------------------${C_RESET}";
}
# --- Функция: pause_pmt ---
# Назначение: Отображает сообщение и ожидает нажатия Enter.
# Параметры:
#   $1 (опционально): Текст сообщения. По умолчанию "Нажмите Enter для продолжения...".
pause_pmt() {
    local pmt_txt="${1:-Нажмите Enter для продолжения...}"
    
    if [[ "$g_sneaky_mode_en" == "y" ]]; then
        # В sneaky-режиме используем read с таймаутом
        if ! read -r -t "$g_sneaky_timeout_sec" -p "$(echo -e "${P_PROMPT} ${pmt_txt} ${C_RESET}")" _ < /dev/tty; then
            log_msg "\n${P_WARN} ${C_BOLD_YELLOW}Таймаут бездействия истёк. Инициирую принудительный выход...${C_RESET}" "/dev/tty"
            on_exit 143 # Вызываем on_exit с кодом завершения по таймауту
        fi
    else
        # В обычном режиме работаем как раньше
        read -r -p "$(echo -e "${P_PROMPT} ${pmt_txt} ${C_RESET}")" _ < /dev/tty
    fi

    if [[ "$g_log_en" == "y" ]]; then
        log_msg "${C_DIM}[PAUSE] Пользователь нажал Enter.${C_RESET}" "/dev/null"
    fi
}
# --- Функция: ask_param ---
# Назначение: Запрашивает у пользователя значение параметра с значением по умолчанию.
# Параметры:
#   $1: Описание параметра.
#   $2: Значение по умолчанию.
#   $3 (опционально): Имя переменной для сохранения результата. Если не указано, выводит на stdout.
ask_param() {
    local desc_str="$1"
    local def_val="$2"
    local store_var_name="${3:-}"
    local input_val
    local choice_val
    log_msg "\n${P_PROMPT} ${C_BOLD_BLUE}Параметр: ${desc_str}${C_RESET}" "/dev/tty"
    log_msg "${P_PROMPT} ${C_DIM}Значение по умолчанию: '${def_val}'${C_RESET}" "/dev/tty"
    if [[ "$g_log_en" == "y" ]]; then
        log_msg "${C_DIM}--- Запрос параметра: $desc_str (По умолчанию: '$def_val') ---${C_RESET}" "/dev/null"
    fi
    local pmt_msg_str="${P_PROMPT} Использовать значение по умолчанию? (Y/n, или введите свое значение): ${C_RESET}"
    while true; do
        if [[ "$g_sneaky_mode_en" == "y" ]]; then
            # В sneaky-режиме используем read с таймаутом
            if ! read -r -t "$g_sneaky_timeout_sec" -p "$(echo -e "${pmt_msg_str}")" choice_val < /dev/tty; then
                log_msg "\n${P_WARN} ${C_BOLD_YELLOW}Таймаут бездействия истёк. Инициирую принудительный выход...${C_RESET}" "/dev/tty"
                on_exit 143
            fi
        else
            # В обычном режиме работаем как раньше
            if ! read -r -p "$(echo -e "${pmt_msg_str}")" choice_val < /dev/tty; then
                log_msg "${P_WARN} Ошибка чтения ввода. Используется значение по умолчанию.${C_RESET}" "/dev/tty"
                if [[ "$g_log_en" == "y" ]]; then log_msg "${P_WARN} Ошибка чтения для '$desc_str'. По умолчанию." "/dev/null"; fi
                input_val="$def_val"; break
            fi
        fi

        local cleaned_choice_val
        cleaned_choice_val=$(echo "$choice_val" | tr -d '[:cntrl:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^'//;s/'$//;s/^\"//;s/\"$//")
        if [[ -z "$cleaned_choice_val" || "$cleaned_choice_val" == "y" || "$cleaned_choice_val" == "Y" ]]; then
            input_val="$def_val"
            log_msg "${P_OK} По умолчанию: '${C_GREEN}$input_val${C_RESET}'" "/dev/tty"
            if [[ "$g_log_en" == "y" ]]; then log_msg "${P_OK} Для '$desc_str' по умолчанию: '$input_val'" "/dev/null"; fi
            break
        elif [[ "$cleaned_choice_val" == "n" || "$cleaned_choice_val" == "N" ]]; then
            local enter_val_pmt_str="${P_PROMPT} Введите ваше значение для '${desc_str}': ${C_RESET}"
            while true; do
                local user_val
                if [[ "$g_sneaky_mode_en" == "y" ]]; then
                    # В sneaky-режиме используем read с таймаутом
                    if ! read -r -t "$g_sneaky_timeout_sec" -p "$(echo -e "${enter_val_pmt_str}")" user_val < /dev/tty; then
                        log_msg "\n${P_WARN} ${C_BOLD_YELLOW}Таймаут бездействия истёк. Инициирую принудительный выход...${C_RESET}" "/dev/tty"
                        on_exit 143
                    fi
                else
                    # В обычном режиме работаем как раньше
                    if ! read -r -p "$(echo -e "${enter_val_pmt_str}")" user_val < /dev/tty; then
                         log_msg "${P_WARN} Ошибка чтения. Повторите.${C_RESET}" "/dev/tty"
                         if [[ "$g_log_en" == "y" ]]; then log_msg "${P_WARN} Ошибка чтения нового значения для '$desc_str'." "/dev/null"; fi
                         continue
                    fi
                fi

                local trimmed_user_val
                trimmed_user_val=$(echo "$user_val" | tr -d '[:cntrl:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^'//;s/'$//;s/^\".*//;s/\"$//")
                if [[ -z "$trimmed_user_val" ]]; then
                    log_msg "${P_ERROR} Пустое значение. Повторите.${C_RESET}" "/dev/tty"
                    if [[ "$g_log_en" == "y" ]]; then log_msg "${P_ERROR} Для '$desc_str' пустое значение." "/dev/null"; fi
                else
                    input_val="$trimmed_user_val"
                    log_msg "${P_OK} Введено: '${C_GREEN}$input_val${C_RESET}'" "/dev/tty"
                    if [[ "$g_log_en" == "y" ]]; then log_msg "${P_OK} Для '$desc_str' введено: '$input_val'" "/dev/null"; fi
                    break
                fi
            done
            break
        else
            input_val="$cleaned_choice_val"
            log_msg "${P_OK} Введено: '${C_GREEN}$input_val${C_RESET}'" "/dev/tty"
            if [[ "$g_log_en" == "y" ]]; then log_msg "${P_OK} Для '$desc_str' введено: '$input_val'" "/dev/null"; fi
            break
        fi
    done
    if [[ -n "$store_var_name" ]]; then
        printf -v "$store_var_name" '%s' "$input_val"
    else
        echo "$input_val"
    fi
}
# === Блок: Функции валидации ввода ===

# --- Функция: val_input ---
# Назначение: Общая функция-обертка для вызова конкретной функции валидации.
# Параметры:
#   $1: Значение для валидации.
#   $2: Имя функции валидации.
# Возвращает: Статус выхода функции валидации (0 - успешно, 1 - ошибка).
val_input() {
    local val_to_check="$1"
    local val_fx_name="$2"
    if "$val_fx_name" "$val_to_check"; then return 0; else return 1; fi
}

# --- Функция: is_vlan_valid ---
# Назначение: Проверяет, является ли значение корректным VLAN ID (1-4094).
# Параметры: $1: Значение для проверки.
is_vlan_valid() {
    local vlan_id_val="$1"
    if ! [[ "$vlan_id_val" =~ ^[0-9]+$ && "$vlan_id_val" -ge 1 && "$vlan_id_val" -le 4094 ]]; then
        log_msg "${P_ERROR} VLAN ID '${C_CYAN}$vlan_id_val${C_BOLD_RED}' некорректен (ожидается число от 1 до 4094)." "/dev/tty"; return 1
    fi
    return 0
}

# --- Функция: is_ipcidr_valid ---
# Назначение: Проверяет, является ли значение корректным IP-адресом (опционально с CIDR).
# Параметры: $1: Значение для проверки (IP или IP/CIDR).
is_ipcidr_valid() {
    local ip_val_arg="$1"
    local ip_val
    ip_val=$(echo "${ip_val_arg}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed "s/^'//;s/'$//;s/^\".*//;s/\"$//")
    local regex='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$'
    if [[ "${ip_val}" =~ ${regex} ]]; then
        IFS='.' read -r o1 o2 o3 o4_cidr <<< "${ip_val%%/*}"
        local o4="${o4_cidr%%/*}"
        for octet in $o1 $o2 $o3 $o4; do
            if ! [[ "$octet" =~ ^[0-9]+$ ]] || (( octet < 0 || octet > 255 )); then
                log_msg "${P_ERROR} IP '${C_CYAN}$ip_val${C_BOLD_RED}' содержит некорректный октет ($octet)." "/dev/tty"; return 1
            fi
        done
        if [[ "$ip_val" == */* ]]; then
            local cidr_mask="${ip_val#*/}"
            if ! [[ "$cidr_mask" =~ ^[0-9]+$ && "$cidr_mask" -ge 0 && "$cidr_mask" -le 32 ]]; then
                 log_msg "${P_ERROR} CIDR-маска '${C_CYAN}$cidr_mask${C_BOLD_RED}' в IP '${C_CYAN}$ip_val${C_BOLD_RED}' некорректна (ожидается от 0 до 32)." "/dev/tty"; return 1
            fi
        fi
        return 0
    else
        log_msg "${P_ERROR} IP-адрес '${C_CYAN}$ip_val${C_BOLD_RED}' имеет неверный формат." "/dev/tty"; return 1
    fi
}

# --- Функция: is_port_valid ---
# Назначение: Проверяет, является ли значение корректным номером порта (1-65535).
# Параметры: $1: Значение для проверки.
is_port_valid() {
    local port_val="$1"
    if ! [[ "$port_val" =~ ^[0-9]+$ && "$port_val" -ge 1 && "$port_val" -le 65535 ]]; then
        log_msg "${P_ERROR} Порт '${C_CYAN}$port_val${C_BOLD_RED}' некорректен (ожидается число от 1 до 65535)." "/dev/tty"; return 1
    fi
    return 0
}

# --- Функция: is_uid_valid ---
# Назначение: Проверяет, является ли значение корректным UID (неотрицательное число).
# Параметры: $1: Значение для проверки.
is_uid_valid() {
    local uid_val="$1"
    if ! [[ "$uid_val" =~ ^[0-9]+$ && "$uid_val" -ge 0 ]]; then
        log_msg "${P_ERROR} UID '${C_CYAN}$uid_val${C_BOLD_RED}' некорректен (ожидается неотрицательное число)." "/dev/tty"; return 1
    fi
    return 0
}

# --- Функция: is_not_empty_valid ---
# Назначение: Проверяет, не является ли значение пустым.
# Параметры: $1: Значение для проверки.
is_not_empty_valid() {
    if [[ -z "$1" ]]; then
        log_msg "${P_ERROR} Значение не может быть пустым." "/dev/tty"; return 1
    fi
    return 0
}

# --- Функция: ask_val_param ---
# Назначение: Запрашивает параметр и проверяет его с помощью функции валидации.
# Параметры:
#   $1: Описание параметра.
#   $2: Значение по умолчанию.
#   $3: Имя функции валидации.
#   $4 (опционально): Имя переменной для сохранения результата.
ask_val_param() {
    local desc_str="$1"
    local def_val="$2"
    local val_fx_name="$3"
    local store_var_name="${4:-}"
    local param_val_to_check
    while true; do
        param_val_to_check=$(ask_param "$desc_str" "$def_val") # Используем ask_param для получения значения
        if val_input "$param_val_to_check" "$val_fx_name"; then
            break
        else
            pause_pmt "Нажмите Enter, чтобы повторить ввод."
            if [[ -t 0 && -t 1 && -n "$TERM" && "$TERM" != "dumb" ]]; then
                 for _ in {1..6}; do tput cuu1; tput el; done
            fi
        fi
    done
    if [[ -n "$store_var_name" ]]; then
        printf -v "$store_var_name" '%s' "$param_val_to_check"
    else
        echo "$param_val_to_check"
    fi
}

# === Блок: Функции для конфигурации и сети ===

# --- Функция: ensure_pkgs ---
# Назначение: Проверяет наличие команд и устанавливает пакеты через apt-get.
# Параметры:
#   $1: Строка с именами команд для проверки (пробелы как разделитель).
#   $2: Строка с именами пакетов для установки (пробелы как разделитель).
ensure_pkgs() {
    local cmds_to_check_str="$1"
    local pkgs_to_install_str="$2"
    local cmds_arr=()
    local pkgs_arr=()
    if [[ -n "$cmds_to_check_str" ]]; then read -r -a cmds_arr <<< "$cmds_to_check_str"; fi
    if [[ -n "$pkgs_to_install_str" ]]; then read -r -a pkgs_arr <<< "$pkgs_to_install_str"; fi
    local missing_cmds_arr=()
    if [[ ${#cmds_arr[@]} -gt 0 ]]; then
        log_msg "${P_INFO} Проверка наличия утилит: ${C_CYAN}${cmds_to_check_str}${C_RESET}..."
        for cmd_item in "${cmds_arr[@]}"; do
            if ! command -v "$cmd_item" &>/dev/null; then
                log_msg "${P_WARN} Утилита '${C_CYAN}$cmd_item${C_BOLD_YELLOW}' не найдена."
                missing_cmds_arr+=("$cmd_item")
            else
                log_msg "${P_OK} Утилита '${C_CYAN}$cmd_item${C_GREEN}' найдена."
            fi
        done
    else
        log_msg "${P_INFO} Список команд для проверки пуст (не критично, если пакеты будут установлены)."
    fi
    if [[ ${#missing_cmds_arr[@]} -gt 0 || (${#cmds_arr[@]} -eq 0 && ${#pkgs_arr[@]} -gt 0) ]]; then
        if [[ ${#pkgs_arr[@]} -eq 0 ]]; then
            log_msg "${P_ERROR} Отсутствуют необходимые утилиты (${C_CYAN}${missing_cmds_arr[*]}${C_BOLD_RED}), но пакеты для их установки не указаны."
            return 1
        fi
        log_msg "${P_INFO} Будет предпринята попытка установки пакетов: ${C_CYAN}${pkgs_to_install_str}${C_RESET}"
        local install_failed_flag=0
        log_msg "${P_INFO} Обновление списка пакетов (apt-get update)..."
        if ! apt-get update -y; then
            log_msg "${P_ERROR} Команда 'apt-get update' не удалась. Проверьте интернет и репозитории."
            install_failed_flag=1
        else
            log_msg "${P_OK} Список пакетов обновлен."
            log_msg "${P_INFO} Установка пакетов: ${C_CYAN}${pkgs_to_install_str}${C_RESET}..."
            # shellcheck disable=SC2068
            if apt-get install -y "${pkgs_arr[@]}"; then
                log_msg "${P_OK} Команда 'apt-get install' завершена."
                local still_missing_after_install_flag=0
                for cmd_item in "${cmds_arr[@]}"; do
                    if ! command -v "$cmd_item" &>/dev/null; then
                        log_msg "${P_WARN} Утилита '${C_CYAN}$cmd_item${C_BOLD_YELLOW}' все еще не найдена после установки."
                        still_missing_after_install_flag=1
                    else
                        log_msg "${P_OK} Утилита '${C_CYAN}$cmd_item${C_GREEN}' теперь найдена."
                    fi
                done
                if [[ "$still_missing_after_install_flag" -eq 0 ]]; then
                    log_msg "${P_OK} Все необходимые утилиты теперь доступны."
                else
                    log_msg "${P_ERROR} Некоторые утилиты все еще отсутствуют после установки пакетов."
                    install_failed_flag=1
                fi
            else
                log_msg "${P_ERROR} Команда 'apt-get install -y ${pkgs_to_install_str}' не удалась."
                install_failed_flag=1
            fi
        fi
        if [[ "$install_failed_flag" -eq 1 ]]; then
            log_msg "${P_WARN} Установка пакетов не удалась. Проверьте вывод выше на наличие ошибок."
            return 1
        fi
    elif [[ ${#cmds_arr[@]} -gt 0 ]]; then
        log_msg "${P_OK} Все необходимые утилиты уже присутствуют в системе."
    fi
    return 0
}

# --- Функция: set_cfg_val ---
# Назначение: Устанавливает или обновляет параметр в конфигурационном файле.
# Параметры:
#   $1: Путь к конфигурационному файлу.
#   $2: Ключ параметра.
#   $3: Значение параметра.
#   $4 (опционально): Комментарий.
set_cfg_val() {
    local cfg_pth="$1"
    local key_str="$2"
    local val_str="$3"
    local comment_str="${4:-}"
    local tmp_file_pth
    tmp_file_pth=$(mktemp)
    touch "$cfg_pth" # Убедимся, что файл существует.
    local escaped_key_str; escaped_key_str=$(printf '%s\n' "$key_str" | sed 's:[][\\/.^$*]:\\&:g')
    local key_pattern_str="^\\s*#*\\s*${escaped_key_str}\\s*="
    grep -vE "$key_pattern_str" "$cfg_pth" > "$tmp_file_pth"
    if [[ -n "$comment_str" ]]; then
        local escaped_comment_str; escaped_comment_str=$(printf '%s\n' "$comment_str" | sed 's:[][\\/.^$*]:\\&:g')
        local comment_pattern_str="^${escaped_comment_str}$"
        local tmp_file2_pth; tmp_file2_pth=$(mktemp)
        grep -vE "$comment_pattern_str" "$tmp_file_pth" > "$tmp_file2_pth"
        mv "$tmp_file2_pth" "$tmp_file_pth"
    fi
    if [ -s "$tmp_file_pth" ] && [ "$(tail -c1 "$tmp_file_pth")" != $'\n' ]; then
        echo >> "$tmp_file_pth"
    fi
    if [[ -n "$comment_str" ]]; then
        echo "$comment_str" >> "$tmp_file_pth"
    fi
    echo "${key_str}=${val_str}" >> "$tmp_file_pth"
    awk 'BEGIN{prev_blank=1} NF>0{print; prev_blank=0; next} NF==0 && !prev_blank {print; prev_blank=1; next}' "$tmp_file_pth" > "$cfg_pth"
    rm -f "$tmp_file_pth"
    return 0
}
export -f set_cfg_val

# --- Функция: rm_cfg_val ---
# Назначение: Удаляет параметр (и его опциональный комментарий) из конфигурационного файла.
# Параметры:
#   $1: Путь к конфигурационному файлу.
#   $2: Ключ параметра для удаления.
#   $3 (опционально): Комментарий для удаления.
rm_cfg_val() {
    local cfg_pth="$1"
    local key_to_rm_str="$2"
    local comment_to_rm_str="${3:-}"
    touch "$cfg_pth" # Убедимся, что файл существует.
    local escaped_key_to_rm_str; escaped_key_to_rm_str=$(printf '%s\n' "$key_to_rm_str" | sed 's:[][\\/.^$*]:\\&:g')
    local key_pattern_to_rm_str="^\\s*#*\\s*${escaped_key_to_rm_str}\\s*="
    sed -i "/${key_pattern_to_rm_str}/d" "$cfg_pth"
    if [[ -n "$comment_to_rm_str" ]]; then
        local escaped_comment_to_rm_str; escaped_comment_to_rm_str=$(printf '%s\n' "$comment_to_rm_str" | sed 's:[][\\/.^$*]:\\&:g')
        local comment_pattern_to_rm_str="^${escaped_comment_to_rm_str}$"
        sed -i "/${comment_pattern_to_rm_str}/d" "$cfg_pth"
    fi
    local tmp_cleaned_file_pth; tmp_cleaned_file_pth=$(mktemp)
    awk 'BEGIN{prev_blank=1} NF>0{print; prev_blank=0; next} NF==0 && !prev_blank {print; prev_blank=1; next}' "$cfg_pth" > "$tmp_cleaned_file_pth"
    cat "$tmp_cleaned_file_pth" > "$cfg_pth"
    rm -f "$tmp_cleaned_file_pth"
    return 0
}
export -f rm_cfg_val

# --- Функция: get_netaddr ---
# Назначение: Вычисляет адрес сети на основе IP-адреса и CIDR-маски.
# Параметры: $1: IP-адрес с CIDR-маской (например, "192.168.1.10/24").
get_netaddr() {
    local ip_cidr_val="$1"
    local ip_addr="${ip_cidr_val%/*}"
    local cidr_val="${ip_cidr_val#*/}"
    if ! is_ipcidr_valid "$ip_cidr_val" || [[ "$ip_cidr_val" != */* ]]; then
        log_msg "${P_ERROR} get_netaddr: Некорректный IP/CIDR '$ip_cidr_val'." "/dev/tty"
        echo "$ip_cidr_val"
        return 1
    fi
    IFS=. read -r i1 i2 i3 i4 <<< "$ip_addr"
    local ip_int_val=$(( (i1<<24) + (i2<<16) + (i3<<8) + i4 ))
    local mask_int_val=$(( ( (1<<32) - 1 ) << (32 - cidr_val) ))
    mask_int_val=$(( mask_int_val < 0 ? mask_int_val + (1<<32) : mask_int_val ))
    local net_int_val=$(( ip_int_val & mask_int_val ))
    local n1=$(( (net_int_val>>24) & 255 ))
    local n2=$(( (net_int_val>>16) & 255 ))
    local n3=$(( (net_int_val>>8) & 255 ))
    local n4=$(( net_int_val & 255 ))
    echo "${n1}.${n2}.${n3}.${n4}/${cidr_val}"
}

# --- Функция: get_ip_only ---
# Назначение: Извлекает IP-адрес из строки IP/CIDR.
# Параметры: $1: Строка IP/CIDR.
get_ip_only() {
    echo "${1%/*}";
}

# --- Функция: get_docker_compose_cmd ---
# Назначение: Определяет команду для Docker Compose ('docker-compose' или 'docker compose').
get_docker_compose_cmd() {
    if command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
        echo "docker compose"
    else
        echo ""
    fi
}

# --- Функция: import_samba_csv_users ---
# Назначение: Импортирует пользователей в Samba AD из CSV-файла.
# Параметры:
#   $1: Пароль по умолчанию для создаваемых пользователей.
#   $2: Путь к CSV-файлу.
import_samba_csv_users() {
    local def_password_val="$1"
    local csv_file_pth_val="$2"
    if [[ ! -f "$csv_file_pth_val" ]]; then
        log_msg "${P_ERROR} Файл ${C_CYAN}$csv_file_pth_val${C_BOLD_RED} не найден!"
        return 1
    fi
    log_msg "${P_INFO} ${P_STEP} Импорт пользователей из ${C_CYAN}$csv_file_pth_val${C_RESET}..."
    local success_cnt=0
    local failure_cnt=0
    local total_lines_proc=0
    while IFS=';' read -r first_name_val last_name_val _unused_fields_val; do
        total_lines_proc=$((total_lines_proc + 1))
        first_name_val=$(echo "${first_name_val}"|tr -d '\r'| tr -d '[:cntrl:]' |sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        last_name_val=$(echo "${last_name_val}"|tr -d '\r'| tr -d '[:cntrl:]' |sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$first_name_val" || -z "$last_name_val" ]]; then
            log_msg "${P_WARN} Строка $total_lines_proc: пустое имя/фамилия ('${C_CYAN}$first_name_val${C_RESET}', '${C_CYAN}$last_name_val${C_RESET}'). Пропуск."
            continue
        fi
        local username_val="${first_name_val,,}.${last_name_val,,}"
        log_msg -n "${P_INFO} Строка $total_lines_proc: обработка пользователя ${C_CYAN}$username_val${C_RESET} ... " "/dev/tty"
        if samba-tool user list | grep -q "^${username_val}$"; then
            log_msg "${C_BOLD_YELLOW}уже существует.${C_RESET}" "/dev/tty"
            continue
        fi
        if samba-tool user add "$username_val" "$def_password_val" --given-name="$first_name_val" --surname="$last_name_val" >/dev/null 2>&1; then
            log_msg "${C_GREEN}успешно добавлен.${C_RESET}" "/dev/tty"
            success_cnt=$((success_cnt + 1))
        else
            log_msg "${P_WARN} ошибка добавления (код: $?).${C_RESET}" "/dev/tty"
            failure_cnt=$((failure_cnt + 1))
        fi
    done < <(tail -n +2 "$csv_file_pth_val")
    log_msg "${P_INFO} ${P_STEP} Импорт завершён. Обработано строк (из CSV, не считая заголовка): ${C_CYAN}$total_lines_proc${C_RESET}. Успешно добавлено: ${C_GREEN}$success_cnt${C_RESET}. Ошибок: ${C_BOLD_RED}$failure_cnt${C_RESET}."
    if [ "$failure_cnt" -gt 0 ]; then return 1; fi
    return 0
}
export -f import_samba_csv_users

# === Блок: Функции для управления сценариями ===

# --- Функция: check_scenario_exists ---
# Назначение: Проверяет существование всех необходимых файлов и каталогов для указанного сценария.
# Параметры: $1: Имя сценария.
# Возвращает: 0, если сценарий существует и валиден, 1 в противном случае.
check_scenario_exists() {
    local scenario_name_to_check="$1"
    if [[ -z "$scenario_name_to_check" ]]; then
        log_msg "${P_ERROR} Имя сценария для проверки не может быть пустым." "/dev/tty"
        return 1
    fi
    local cfg_file_check="${SCENARIOS_DIR}/${scenario_name_to_check}_cfg.sh"
    local scn_file_check="${SCENARIOS_DIR}/${scenario_name_to_check}_scn.sh"
    local fx_dir_check="${FX_LIB_DIR}/${scenario_name_to_check}"
    if [[ ! -f "$cfg_file_check" ]]; then
        # log_msg "${P_INFO} ${C_DIM}Проверка: Файл конфигурации ${cfg_file_check} для сценария '${scenario_name_to_check}' не найден.${C_RESET}" "/dev/null"
        return 1
    fi
    if [[ ! -f "$scn_file_check" ]]; then
        # log_msg "${P_INFO} ${C_DIM}Проверка: Файл определений ${scn_file_check} для сценария '${scenario_name_to_check}' не найден.${C_RESET}" "/dev/null"
        return 1
    fi
    if [[ ! -d "$fx_dir_check" ]]; then
        # log_msg "${P_INFO} ${C_DIM}Проверка: Каталог функций ${fx_dir_check} для сценария '${scenario_name_to_check}' не найден.${C_RESET}" "/dev/null"
        return 1
    fi
    # log_msg "${P_INFO} ${C_DIM}Проверка: Сценарий '${scenario_name_to_check}' найден и валиден.${C_RESET}" "/dev/null"
    return 0
}
export -f check_scenario_exists

# --- Мета-комментарий: Конец общих вспомогательных функций ---