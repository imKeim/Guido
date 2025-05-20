#!/bin/bash
# Файл: core_lib/sneaky_utils.sh
# Содержит функции для "sneaky" (скрытого) режима и обработчик выхода on_exit.
# Этот файл подключается (source) основным скриптом Guido.

# --- Мета-комментарий: Функции для Sneaky режима и обработчик выхода ---

# === Блок: Функции для Sneaky (скрытого) режима ===

# --- Функция: sneaky_init_hist_clean ---
# Назначение: Начальная очистка файла истории команд в sneaky режиме.
sneaky_init_hist_clean() {
    # --- ОТЛАДКА ВНУТРИ ФУНКЦИИ ---
    # echo "[DEBUG_FUNC] Внутри sneaky_init_hist_clean. g_sneaky_mode_en = '$g_sneaky_mode_en'." > /dev/tty
    # read -r -p "[DEBUG_FUNC] Нажмите Enter для продолжения..." _ < /dev/tty
    # --- КОНЕЦ ОТЛАДКИ ---

    if [[ "$g_sneaky_mode_en" != "y" ]]; then
        # echo "[DEBUG_FUNC] Выход из sneaky_init_hist_clean, т.к. g_sneaky_mode_en ('$g_sneaky_mode_en') != 'y'." > /dev/tty
        # read -r -p "[DEBUG_FUNC] Нажмите Enter для продолжения..." _ < /dev/tty
        return 0
    fi

    # echo "[DEBUG_FUNC] g_sneaky_mode_en = 'y'. Продолжаю выполнение sneaky_init_hist_clean." > /dev/tty
    log_msg "${P_INFO} ${C_DIM}[SNEAKY] Начальная очистка файла истории команд...${C_RESET}" "/dev/null"


    if ! shopt -q histappend; then
        shopt -s histappend
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Опция 'histappend' принудительно включена.${C_RESET}" "/dev/null"
    fi

    local hist_file_pth="${HISTFILE:-$HOME/.bash_history}"

    if [[ ! -f "$hist_file_pth" ]]; then
        log_msg "${P_WARN} ${C_DIM}[SNEAKY] Файл истории '$hist_file_pth' не найден. Попытка создать...${C_RESET}" "/dev/null"
        touch "$hist_file_pth"
        if [[ ! -f "$hist_file_pth" ]]; then
             log_msg "${P_ERROR} ${C_DIM}[SNEAKY] Не удалось создать файл истории '$hist_file_pth'.${C_RESET}" "/dev/null"
             return 1
        fi
    fi
    if [[ ! -r "$hist_file_pth" || ! -w "$hist_file_pth" ]]; then
        log_msg "${P_ERROR} ${C_DIM}[SNEAKY] Файл истории '$hist_file_pth' недоступен для чтения/записи. Пропуск очистки.${C_RESET}" "/dev/null"
        return 1
    fi

    # --- ОТЛАДКА: Вывод содержимого файла ИСТОРИИ ДО sed ---
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] Содержимое '$hist_file_pth' ДО обработки sed:${C_RESET}" "/dev/tty"
    # if [[ -s "$hist_file_pth" ]]; then cat "$hist_file_pth" > /dev/tty
    # else log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] Файл '$hist_file_pth' пуст ДО sed.${C_RESET}" "/dev/tty"; fi
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] --- Конец содержимого ДО sed ---${C_RESET}" "/dev/tty"
    # --- КОНЕЦ ОТЛАДКИ ---

    local script_basename_for_sed
    script_basename_for_sed=$(basename "$SCRIPT_PTH_DEL" | sed -e 's/[\/.*^$[]/\\&/g' -e 's/[](){}?+|/\\]/\\&/g')
    if [[ $? -ne 0 || -z "$script_basename_for_sed" ]]; then
        log_msg "${P_ERROR} ${C_DIM}[SNEAKY] Не удалось получить имя файла скрипта для sed.${C_RESET}" "/dev/null"; return 1
    fi
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] script_basename_for_sed: '${script_basename_for_sed}'${C_RESET}" "/dev/tty"

    local full_path_pattern_for_sed
    full_path_pattern_for_sed=$(printf '%s\n' "$SCRIPT_PTH_DEL" | sed -e 's/[\/.*^$[]/\\&/g' -e 's/[](){}?+|/\\]/\\&/g')
    if [[ $? -ne 0 || -z "$full_path_pattern_for_sed" ]]; then
        log_msg "${P_ERROR} ${C_DIM}[SNEAKY] Не удалось получить полный путь скрипта для sed.${C_RESET}" "/dev/null"; return 1
    fi
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] full_path_pattern_for_sed: '${full_path_pattern_for_sed}'${C_RESET}" "/dev/tty"

    local sed_expressions_arr=()
    sed_expressions_arr+=("-e /${script_basename_for_sed}/Id")
    sed_expressions_arr+=("-e /${full_path_pattern_for_sed}/Id")
    sed_expressions_arr+=("-e /guido/Id") # Оставляем "guido" для обратной совместимости, если где-то используется
    sed_expressions_arr+=("-e /base64 -d .* gunzip .* bash/Id")
    sed_expressions_arr+=("-e /base64[[:space:]]*-d/Id")
    sed_expressions_arr+=("-e /wget[[:space:]].*${script_basename_for_sed}/Id")
    sed_expressions_arr+=("-e /curl[[:space:]].*${script_basename_for_sed}/Id")
    sed_expressions_arr+=("-e /^\.\/${script_basename_for_sed}/Id")
    sed_expressions_arr+=("-e /^[[:space:]]*\(bash\|sh\)[[:space:]]\+.*\/${script_basename_for_sed}/Id")
    sed_expressions_arr+=("-e /^[[:space:]]*\(bash\|sh\)[[:space:]]\+${script_basename_for_sed}/Id")

    # --- ОТЛАДКА: Вывод выражений sed ---
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] Выражения для sed:${C_RESET}" "/dev/tty"
    # printf "  %s\n" "${sed_expressions_arr[@]}" > /dev/tty
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] --- Конец выражений sed ---${C_RESET}" "/dev/tty"
    # --- КОНЕЦ ОТЛАДКИ ---

    local backup_hist_file_ts
    backup_hist_file_ts=$(date +%s)
    if [[ $? -ne 0 || -z "$backup_hist_file_ts" ]]; then
        backup_hist_file_ts="fallback_ts"
    fi
    local backup_hist_file_pth="${hist_file_pth}.guido_sneaky_bak_${backup_hist_file_ts}"

    if [[ -s "$hist_file_pth" ]]; then
        if ! cp "$hist_file_pth" "$backup_hist_file_pth"; then
            log_msg "${P_ERROR} ${C_DIM}[SNEAKY] Не удалось создать резервную копию '$backup_hist_file_pth'.${C_RESET}" "/dev/null"
            return 1
        fi
    else
        touch "$backup_hist_file_pth"
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Файл истории '$hist_file_pth' пуст, создан пустой файл бэкапа.${C_RESET}" "/dev/null"
    fi

    # shellcheck disable=SC2068
    if sed -i "${sed_expressions_arr[@]}" "$hist_file_pth"; then
        log_msg "${P_OK} ${C_DIM}[SNEAKY] Файл истории '$hist_file_pth' обработан sed.${C_RESET}" "/dev/null"
        if cmp -s "$hist_file_pth" "$backup_hist_file_pth"; then
            rm -f "$backup_hist_file_pth"
        else
            log_msg "${P_INFO} ${C_DIM}[SNEAKY] Файл истории изменен sed. Резервная копия: $backup_hist_file_pth ${C_RESET}" "/dev/null"
        fi
    else
        log_msg "${P_ERROR} ${C_DIM}[SNEAKY] Ошибка sed для '$hist_file_pth'. Восстановление.${C_RESET}" "/dev/null"
        if [[ -s "$backup_hist_file_pth" ]]; then cp "$backup_hist_file_pth" "$hist_file_pth"; fi
        return 1
    fi

    # --- ОТЛАДКА: Вывод содержимого файла ИСТОРИИ ПОСЛЕ обработки sed ---
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] Содержимое '$hist_file_pth' ПОСЛЕ обработки sed:${C_RESET}" "/dev/tty"
    # if [[ -s "$hist_file_pth" ]]; then cat "$hist_file_pth" > /dev/tty
    # else log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] Файл '$hist_file_pth' пуст ПОСЛЕ sed.${C_RESET}" "/dev/tty"; fi
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] --- Конец содержимого ПОСЛЕ sed ---${C_RESET}" "/dev/tty"
    # log_msg "${P_INFO} ${C_DIM}[SNEAKY DEBUG] Нажмите Enter для продолжения после отладки sed...${C_RESET}" "/dev/tty"
    # read -r _ < /dev/tty
    # --- КОНЕЦ ОТЛАДКИ ---

    if command -v history >/dev/null; then
        history -c
        history -r "$hist_file_pth"
        log_msg "${P_OK} ${C_DIM}[SNEAKY] Внутренняя история скрипта очищена и перезагружена.${C_RESET}" "/dev/null"
    else
        log_msg "${P_WARN} ${C_DIM}[SNEAKY] Команда 'history' не найдена в подшелле.${C_RESET}" "/dev/null"
        return 1
    fi
    return 0
}

# --- Функция: reg_sneaky_cmd ---
# Назначение: Регистрирует команду для добавления в "симулированную" историю Bash в sneaky режиме.
# Параметры: $1: Строка команды для регистрации.
reg_sneaky_cmd() {
    if [[ "$g_sneaky_mode_en" == "y" ]]; then
        g_sneaky_hist_cmds+=("$1")
    fi
}
export -f reg_sneaky_cmd

# --- Функция: sneaky_sim_hist_cmds ---
# Назначение: Добавляет ранее зарегистрированные "симулированные" команды в историю
#             текущего подшелла и записывает обновленную историю в файл.
sneaky_sim_hist_cmds() {
    if [[ "$g_sneaky_mode_en" != "y" ]]; then return 0; fi

    if ! command -v history >/dev/null; then
        log_msg "${P_WARN} ${C_DIM}[SNEAKY] Команда 'history' не найдена. Пропуск симуляции и записи истории.${C_RESET}" "/dev/null"
        return 1
    fi

    if ! shopt -q histappend; then
        shopt -s histappend
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Опция 'histappend' принудительно включена перед записью симулированных команд.${C_RESET}" "/dev/null"
    fi

    if [[ ${#g_sneaky_hist_cmds[@]} -gt 0 ]]; then
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Добавление симулированных команд во внутреннюю историю скрипта...${C_RESET}" "/dev/null"
        for cmd_to_sim in "${g_sneaky_hist_cmds[@]}"; do
            local clean_cmd_to_sim
            clean_cmd_to_sim=$(echo -E "$cmd_to_sim" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g') # Очистка от ANSI
            history -s "$clean_cmd_to_sim"
        done
        log_msg "${P_OK} ${C_DIM}[SNEAKY] Симулированные команды добавлены во внутреннюю историю скрипта.${C_RESET}" "/dev/null"
    fi

    history -w # Записываем текущую историю подшелла в файл $HISTFILE.
    log_msg "${P_OK} ${C_DIM}[SNEAKY] Внутренняя история скрипта записана в '$HISTFILE' (history -w).${C_RESET}" "/dev/null"

    return 0
}

# --- Функция: sneaky_deep_cls ---
# Назначение: Выполняет "глубокую" очистку экрана терминала и буфера прокрутки.
sneaky_deep_cls() {
    if [[ "$g_sneaky_mode_en" != "y" ]]; then return 0; fi

    if command -v reset >/dev/null; then
        reset >/dev/tty 2>&1
        printf '\033c' >/dev/tty
    elif command -v clear >/dev/null; then
        clear >/dev/tty 2>&1
        printf '\033c' >/dev/tty
    else
        printf '\033[2J\033[3J\033[H\033c' >/dev/tty
    fi
    for i in {1..100}; do
        printf '\n' >/dev/tty
    done
}

      
# --- Функция: sneaky_self_del ---
# Назначение: Пытается удалить файл текущего скрипта и его каталог библиотеки,
#             или весь временный каталог развертывания, если он используется.
#             Запускается в фоновом режиме с небольшой задержкой.
sneaky_self_del() {
    if [[ "$g_sneaky_mode_en" != "y" ]]; then return 0; fi

    local items_deleted_flag=0

    # SCRIPT_PTH_DEL, SCRIPT_DIR, GUIDO_TEMP_DEPLOY_DIR должны быть экспортированы из guido.sh
    # CORE_LIB_DIR, SCENARIOS_DIR, FX_LIB_DIR также доступны через экспорт, если нужны

    if [[ -n "$GUIDO_TEMP_DEPLOY_DIR" && -d "$GUIDO_TEMP_DEPLOY_DIR" ]]; then
        # Если мы работаем из временного каталога развертывания, удаляем его целиком
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Обнаружен временный каталог развертывания: ${GUIDO_TEMP_DEPLOY_DIR}${C_RESET}" "/dev/null"
        ( sleep 0.4 && rm -rf "$GUIDO_TEMP_DEPLOY_DIR" && \
          log_msg "${P_OK} ${C_DIM}[SNEAKY] Временный каталог развертывания ${C_GREEN}$GUIDO_TEMP_DEPLOY_DIR${C_DIM} (предположительно) удален.${C_RESET}" "/dev/null" ) &
        disown -h %+
        items_deleted_flag=1
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Запланировано удаление каталога: ${GUIDO_TEMP_DEPLOY_DIR}${C_RESET}" "/dev/null"
    else
        # Старый механизм удаления отдельных частей, если не используется временный каталог
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Временный каталог развертывания не используется. Попытка удалить отдельные компоненты...${C_RESET}" "/dev/null"
        local script_del_ok=0
        local payload_dir_del_ok=0 # Флаг для удаления каталога SCRIPT_DIR, если он содержит маркер

        # Удаление основного скрипта
        if [[ -n "$SCRIPT_PTH_DEL" && -f "$SCRIPT_PTH_DEL" ]]; then
            ( sleep 0.2 && rm -f "$SCRIPT_PTH_DEL" && \
              log_msg "${P_OK} ${C_DIM}[SNEAKY] Основной скрипт ${C_GREEN}$SCRIPT_PTH_DEL${C_DIM} (предположительно) удален.${C_RESET}" "/dev/null" ) &
            disown -h %+
            script_del_ok=1
            items_deleted_flag=1
        else
            log_msg "${P_WARN} ${C_DIM}[SNEAKY] Путь к основному скрипту для самоудаления не задан или файл не существует: '${SCRIPT_PTH_DEL}'.${C_RESET}" "/dev/null"
        fi

        # Удаление всего каталога SCRIPT_DIR, если он содержит маркер .guido_payload_marker
        # Этот маркер будет создаваться загрузчиком guido_installer.sh внутри распакованного каталога.
        # Это более надежно, чем удалять CORE_LIB_DIR, SCENARIOS_DIR, FX_LIB_DIR по отдельности.
        if [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" != "/" && "$SCRIPT_DIR" != "/tmp" && -d "$SCRIPT_DIR" && -f "${SCRIPT_DIR}/.guido_payload_marker" ]]; then
            log_msg "${P_INFO} ${C_DIM}[SNEAKY] Найден маркер .guido_payload_marker в SCRIPT_DIR. Попытка удалить SCRIPT_DIR: ${SCRIPT_DIR} ${C_RESET}" "/dev/null"
            ( sleep 0.5 && rm -rf "$SCRIPT_DIR" && \
              log_msg "${P_OK} ${C_DIM}[SNEAKY] Каталог полезной нагрузки ${C_GREEN}$SCRIPT_DIR${C_DIM} (предположительно) удален.${C_RESET}" "/dev/null" ) &
            disown -h %+
            payload_dir_del_ok=1
            items_deleted_flag=1
        elif [[ -n "$SCRIPT_DIR" && "$SCRIPT_DIR" != "/" && "$SCRIPT_DIR" != "/tmp" && -d "$SCRIPT_DIR" ]]; then
             log_msg "${P_INFO} ${C_DIM}[SNEAKY] Маркер .guido_payload_marker не найден в ${SCRIPT_DIR}. Каталог SCRIPT_DIR не будет удален целиком.${C_RESET}" "/dev/null"
             # Можно добавить здесь удаление CORE_LIB_DIR и т.д. по отдельности, если это все еще нужно
             # как fallback, но удаление родительского каталога с маркером предпочтительнее.
        fi
    fi

    if [[ "$items_deleted_flag" -eq 1 ]]; then
        return 0
    else
        log_msg "${P_WARN} ${C_DIM}[SNEAKY] Не было предпринято попыток удаления файлов/каталогов.${C_RESET}" "/dev/null"
        return 1
    fi
}

# === Блок: Обработчик выхода ===

# --- Функция: on_exit ---
# Назначение: Обработчик, вызываемый при завершении скрипта.
# Параметры: $1 (опционально): Код выхода скрипта.
on_exit() {
    local exit_code=${1:-$?}

    if [[ "$g_on_exit_called" -eq 1 ]]; then
        exit "$exit_code"
    fi
    g_on_exit_called=1

    local orig_log_en_val="$g_log_en"
    local cur_histfile_pth_on_exit="${HISTFILE:-~/.bash_history}"

    if [[ "$g_sneaky_mode_en" == "y" ]]; then
        if ! [[ -n "$g_log_pth" && "$orig_log_en_val" == "y" ]]; then
             true
        else
             g_log_en="y"
        fi

        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Завершение работы скрипта (статус выхода: $exit_code)...${C_RESET}" "/dev/null"
        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Активация процедур выхода из sneaky режима...${C_RESET}" "/dev/null"

        sneaky_sim_hist_cmds

        local user_pmt_msg_hist_update="${C_BOLD_YELLOW}[ВАЖНО - Sneaky режим]${C_RESET}\n"
        user_pmt_msg_hist_update+="Файл истории Bash (${C_CYAN}${cur_histfile_pth_on_exit}${C_RESET}) был обновлен этим скриптом.\n\n"
        user_pmt_msg_hist_update+="Для корректного отображения \"чистой\" истории команд:\n"
        user_pmt_msg_hist_update+="  1. ${C_GREEN}НАДЕЖНЫЙ СПОСОБ:${C_RESET} Закройте текущий терминал и откройте новый.\n"
        user_pmt_msg_hist_update+="     История команд в новой сессии терминала будет правильной.\n\n"
        user_pmt_msg_hist_update+="  2. ${C_YELLOW}ПОПЫТКА ДЛЯ ТЕКУЩЕЙ СЕССИИ (может не сработать немедленно):${C_RESET}\n"
        user_pmt_msg_hist_update+="     Выполните в этом терминале следующую команду: ${C_CYAN}history -c && history -r${C_RESET}\n"
        user_pmt_msg_hist_update+="     Это *может* обновить историю команд в текущем окне терминала.\n"

        echo -e "\n${user_pmt_msg_hist_update}\n" > /dev/tty
        read -r -p "$(echo -e "${C_CYAN}Нажмите Enter для продолжения и завершения работы скрипта...${C_RESET}")" _ < /dev/tty

        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Пользователь уведомлен. Ожидание 3 секунды перед финальной очисткой и попыткой самоудаления...${C_RESET}" "/dev/null"
        sleep 3

        sneaky_self_del

        log_msg "${P_INFO} ${C_DIM}[SNEAKY] Процедуры sneaky режима завершены. Глубокая очистка экрана...${C_RESET}" "/dev/null"
        sneaky_deep_cls

    else
        log_msg "${P_INFO} ${C_BOLD_BLUE}Завершение работы скрипта \"Guido\"...${C_RESET}"
        log_msg "${P_INFO} ${C_GREEN}Скрипт завершен со статусом выхода: $exit_code${C_RESET}"
    fi

    g_log_en="$orig_log_en_val"

    trap - EXIT SIGINT SIGTERM
    exit "$exit_code"
}

# --- Мета-комментарий: Конец функций для Sneaky режима и обработчика выхода ---