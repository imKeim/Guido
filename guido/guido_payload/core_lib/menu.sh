#!/bin/bash
# Файл: core_lib/menu.sh
# Содержит управляющие функции для выполнения сценариев, навигации по меню,
# определения роли, отображения информации и переключения режимов.
# Этот файл подключается (source) основным скриптом Guido.

# --- Мета-комментарий: Управляющие функции и логика меню ---

# === Блок: Управляющие функции для выполнения сценариев ===

# --- Функция: _run_step ---
# Назначение: Обертка для выполнения одного шага конфигурации.
# Параметры: $1:Имя функции-шага, $2:Код роли, $3:Номер модуля, $4:Описание шага.
_run_step() {
    local step_fx_name="$1"
    local vm_role_code_uc="$2" # Роль в верхнем регистре (HQSRV, ISP)
    local mod_num="$3"
    local step_desc_str="$4"

    local vm_role_code_lc; vm_role_code_lc=$(echo "$vm_role_code_uc" | tr '[:upper:]' '[:lower:]') # Роль в нижнем регистре (hqsrv, isp)

    # Путь к файлу с функциями для текущей роли и модуля в рамках текущего сценария
    local fx_file_to_source="${FX_LIB_DIR}/${g_cur_de_scenario_name}/${vm_role_code_lc}/${vm_role_code_lc}_m${mod_num}_fx.sh"

    # Проверяем, существует ли файл с функциями и не был ли он уже загружен
    # (простая проверка по наличию функции, можно усложнить, если нужно)
    if ! declare -F "$step_fx_name" &>/dev/null; then
        if [[ -f "$fx_file_to_source" ]]; then
            log_msg "${P_INFO} ${C_DIM}Загрузка файла функций: ${fx_file_to_source}${C_RESET}" "/dev/null"
            # shellcheck source=/dev/null
            source "$fx_file_to_source"
            if [[ $? -ne 0 ]]; then
                log_msg "${P_ERROR} Ошибка при загрузке файла функций ${C_BOLD_RED}${fx_file_to_source}${P_ERROR}."
                return 1 # Критическая ошибка, не можем продолжить шаг
            fi
        else
            log_msg "${P_ERROR} Файл функций ${C_BOLD_RED}${fx_file_to_source}${P_ERROR} не найден."
            return 1 # Критическая ошибка
        fi
    fi

    # Проверяем, определена ли функция после попытки загрузки
    if ! declare -F "$step_fx_name" &>/dev/null; then
        log_msg "${P_ERROR} Функция шага ${C_BOLD_RED}${step_fx_name}${P_ERROR} не определена даже после попытки загрузки из ${C_CYAN}${fx_file_to_source}${P_ERROR}."
        return 1 # Критическая ошибка
    fi

    local flag_step_done_pth="${FLAG_DIR_BASE}/${vm_role_code_uc}_M${mod_num}_${step_fx_name}_done.flag"
    local flag_step_error_pth="${FLAG_DIR_BASE}/${vm_role_code_uc}_M${mod_num}_${step_fx_name}_error.flag"

    if [[ -f "$flag_step_done_pth" && ! -f "$flag_step_error_pth" ]]; then
        log_msg "${P_OK} ${P_STEP} Шаг '${C_GREEN}${step_desc_str}${P_OK}' (функция: ${C_DIM}${step_fx_name}${P_OK}) уже был отмечен как выполненный."
        local choice_rerun_step_val
        ask_param "Выполнить этот шаг '${step_desc_str}' заново?" "y" "choice_rerun_step_val"
        if [[ "$choice_rerun_step_val" != "y" && "$choice_rerun_step_val" != "Y" ]]; then
            log_msg "${P_INFO} Пропуск повторного выполнения шага '${C_CYAN}${step_desc_str}${C_RESET}'."
            return 0
        fi
        log_msg "${P_INFO} Повторное выполнение шага '${C_CYAN}${step_desc_str}${C_RESET}'..."
    fi
    rm -f "$flag_step_error_pth" "$flag_step_done_pth"

    log_msg "${P_STEP} ${C_BOLD_BLUE}Начало выполнения шага:${C_RESET} ${C_BOLD_MAGENTA}${step_desc_str}${C_RESET}"
    log_msg "${P_INFO}   ${C_DIM}(Вызывается функция: ${step_fx_name} из ${fx_file_to_source})${C_RESET}"
    print_sep

    local step_actual_exit_code_val=0
    if "$step_fx_name"; then # Непосредственный вызов функции шага
        step_actual_exit_code_val=0
        log_msg "${P_OK} ${P_STEP} Шаг '${C_GREEN}${step_desc_str}${P_OK}' (функция: ${C_DIM}${step_fx_name}${P_OK}) успешно завершен."
        touch "$flag_step_done_pth"
        rm -f "$flag_step_error_pth"
    else
        step_actual_exit_code_val=$?
        if [[ "$step_actual_exit_code_val" -eq 1 ]]; then
            log_msg "${P_ERROR} ${P_STEP} Шаг '${C_BOLD_RED}${step_desc_str}${P_ERROR}' (функция: ${C_DIM}${step_fx_name}${P_ERROR}) завершился с ошибкой (код возврата 1)."
            touch "$flag_step_error_pth"
            rm -f "$flag_step_done_pth"
        elif [[ "$step_actual_exit_code_val" -eq 2 ]]; then
            log_msg "${P_WARN} ${P_STEP} Шаг '${C_BOLD_YELLOW}${step_desc_str}${P_WARN}' (функция: ${C_DIM}${step_fx_name}${P_WARN}) требует внешнего действия (код возврата 2)."
        else
            log_msg "${P_ERROR} ${P_STEP} Шаг '${C_BOLD_RED}${step_desc_str}${P_ERROR}' (функция: ${C_DIM}${step_fx_name}${P_ERROR}) завершился с неожиданным кодом ошибки: ${C_BOLD_RED}$step_actual_exit_code_val${P_ERROR}."
            touch "$flag_step_error_pth"
            rm -f "$flag_step_done_pth"
        fi
    fi
    print_sep
    return $step_actual_exit_code_val
}

# --- Функция: run_guido_mod ---
# Назначение: Реализует режим "Guido" (Автопилот) для модуля.
# Параметры: $1:Код роли ВМ, $2:Номер модуля.
run_guido_mod() {
    local cur_vm_role_val="$1"
    local cur_mod_num_val="$2"
    local scn_array_name_val="SCN_${cur_vm_role_val}_M${cur_mod_num_val}"

    if ! declare -p "$scn_array_name_val" &>/dev/null; then
        log_msg "${P_ERROR} Сценарий ${C_BOLD_RED}$scn_array_name_val${P_ERROR} не найден для роли ${C_CYAN}$cur_vm_role_val${P_ERROR} - Модуль ${C_CYAN}${cur_mod_num_val}${P_ERROR}."
        pause_pmt; return 1
    fi
    declare -n cur_scn_ref="$scn_array_name_val" # Ссылка на массив сценария
    if [[ ${#cur_scn_ref[@]} -eq 0 ]]; then
        log_msg "${P_INFO} Сценарий для роли ${C_CYAN}$cur_vm_role_val${P_INFO} - Модуль ${C_CYAN}${cur_mod_num_val}${P_INFO} не содержит шагов."
        pause_pmt; return 0
    fi

    local guido_step_idx_file_pth="${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_guido_cur_step_idx.dat"
    local cur_guido_step_idx_val=0
    if [[ -f "$guido_step_idx_file_pth" ]]; then
        cur_guido_step_idx_val=$(cat "$guido_step_idx_file_pth")
        if ! [[ "$cur_guido_step_idx_val" =~ ^[0-9]+$ ]]; then
            log_msg "${P_WARN} Некорректный индекс (${C_YELLOW}$cur_guido_step_idx_val${P_WARN}) в файле ${C_YELLOW}$guido_step_idx_file_pth${P_WARN}. Сброс на начало (0)."
            cur_guido_step_idx_val=0
        fi
    fi
    if [[ "$cur_guido_step_idx_val" -ge "${#cur_scn_ref[@]}" ]]; then
        cur_guido_step_idx_val=0
        log_msg "${P_INFO} Индекс шага Guido был за пределами сценария. Сброшен на начало."
    fi

    while [[ "$cur_guido_step_idx_val" -lt "${#cur_scn_ref[@]}" ]]; do
        local cur_step_fx_name="${cur_scn_ref[$cur_guido_step_idx_val]}"
        local cur_step_desc_str
        cur_step_desc_str="${cur_step_fx_name//_/ }"
        cur_step_desc_str="${cur_step_desc_str//setup /}"
        cur_step_desc_str="${cur_step_desc_str//${cur_vm_role_val,,} m${cur_mod_num_val} /}"
        cur_step_desc_str=$(echo "$cur_step_desc_str" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
        # Дополнительные замены для улучшения читаемости описания шага
        cur_step_desc_str=$(echo "$cur_step_desc_str" | sed \
            -e 's/Net Ifaces Wan Lan Trunk/Network Interfaces WAN LAN Trunk/g' \
            -e 's/Net Ifaces/Network Interfaces/g' \
            -e 's/Ip Forwarding/IP Forwarding/g' \
            -e 's/Net Restart Base Ip/Network Restart (Base IP)/g' \
            -e 's/Net Restart Init/Network Restart (Initial)/g' \
            -e 's/Net Restart/Network Restart/g' \
            -e 's/Iptables Nat Mss/iptables NAT & MSS Clamping/g' \
            -e 's/Iptables Nat/iptables NAT/g' \
            -e 's/User Net Admin/User net_admin/g' \
            -e 's/User Sshuser/User sshuser/g' \
            -e 's/Vlans/VLANs/g' \
            -e 's/Gre Tunnel/GRE Tunnel/g' \
            -e 's/Tz/Timezone/g' \
            -e 's/Dns Cli Final/DNS Client (Final)/g' \
            -e 's/Dns Srv/DNS Server/g' \
            -e 's/Dhcp Srv/DHCP Server/g' \
            -e 's/Dhcp Cli Cfg/DHCP Client Config/g' \
            -e 's/Ospf/OSPF/g' \
            -e 's/Tmp Static Ip/Temporary Static IP/g' \
            -e 's/Init Reboot After Static Ip/Reboot after Static IP/g' \
            -e 's/Ntp Srv/NTP Server/g' \
            -e 's/Ntp Cli/NTP Client/g' \
            -e 's/Nginx Reverse Proxy/Nginx Reverse Proxy/g' \
            -e 's/Dnat Ssh To Hqsrv/DNAT SSH to HQSRV/g' \
            -e 's/Dnat Wiki Ssh To Brsrv/DNAT Wiki & SSH to BRSRV/g' \
            -e 's/Ssh Srv Port Update/SSH Server Port Update/g' \
            -e 's/Ssh Srv En/SSH Server Enable/g' \
            -e 's/Ssh Srv/SSH Server/g' \
            -e 's/Raid Nfs Srv/RAID & NFS Server/g' \
            -e 's/Dns Forwarding For Ad/DNS Forwarding for AD/g' \
            -e 's/Moodle Inst P1 Services Db/Moodle Install (Part 1: Services, DB)/g' \
            -e 's/Moodle Inst P2 Web Setup Pmt/Moodle Install (Part 2: Web Setup Prompt)/g' \
            -e 's/Moodle Inst P3 Proxy Cfg/Moodle Install (Part 3: Proxy Config)/g' \
            -e 's/Samba Dc Inst Provision/Samba DC Install & Provision/g' \
            -e 's/Samba Dc Kerberos Dns Crontab/Samba DC Kerberos, DNS, Crontab/g' \
            -e 's/Samba Dc Create Users Groups/Samba DC Create Users & Groups/g' \
            -e 's/Samba Dc Import Users Csv/Samba DC Import Users from CSV/g' \
            -e 's/Samba Ad Join/Samba AD Join/g' \
            -e 's/Ansible Inst Ssh Key Gen/Ansible Install & SSH Key Gen/g' \
            -e 's/Ansible Ssh Copy Id Pmt/Ansible SSH Copy ID Prompt/g' \
            -e 's/Ansible Cfg Files/Ansible Config Files/g' \
            -e 's/Docker Mediawiki Inst P1 Compose Up/Docker MediaWiki (Part 1: Compose Up)/g' \
            -e 's/Docker Mediawiki Inst P2 Web Setup Pmt/Docker MediaWiki (Part 2: Web Setup Prompt)/g' \
            -e 's/Docker Mediawiki Inst P3 Apply Localsettings/Docker MediaWiki (Part 3: Apply LocalSettings)/g' \
            -e 's/Yabrowser Inst Bg/Yandex Browser Install (Background)/g' \
            -e 's/Init Reboot After Ad Join/Reboot after AD Join/g' \
            -e 's/Create Domain User Homedirs/Create Domain User Homedirs/g' \
            -e 's/Sudo For Domain Group/Sudo for Domain Group/g' \
            -e 's/Nfs Cli Mount/NFS Client Mount/g' \
            -e 's/Wait Yabrowser Inst/Wait Yandex Browser Install/g' \
            -e 's/Copy Localsettings To Brsrv Pmt/Copy LocalSettings.php to BRSRV Prompt/g' \
        )


        local step_status_sym_val="${C_DIM}[ ]${C_RESET}"
        local flag_step_done_pth_val="${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_${cur_step_fx_name}_done.flag"
        local flag_step_error_pth_val="${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_${cur_step_fx_name}_error.flag"
        local has_any_pending_flag_val=0
        if compgen -G "${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_${cur_step_fx_name}_pending_*.flag" > /dev/null; then
            has_any_pending_flag_val=1
        fi

        if [[ -f "$flag_step_done_pth_val" && ! -f "$flag_step_error_pth_val" ]]; then step_status_sym_val="${C_GREEN}[✓]${C_RESET}";
        elif [[ -f "$flag_step_error_pth_val" ]]; then step_status_sym_val="${C_BOLD_RED}[!]${C_RESET}";
        elif [[ "$has_any_pending_flag_val" -eq 1 ]]; then step_status_sym_val="${C_BOLD_YELLOW}[P]${C_RESET}"; fi

        clear
        log_msg "${C_BOLD_BLUE}=== Guido: ${C_CYAN}$cur_vm_role_val${C_BOLD_BLUE} - Модуль ${C_CYAN}M${cur_mod_num_val}${C_BOLD_BLUE} (Автопилот) ==="
        log_msg "${P_INFO} Текущий шаг ${C_YELLOW}($((cur_guido_step_idx_val + 1)) / ${#cur_scn_ref[@]})${C_RESET}: ${step_status_sym_val} ${C_BOLD_MAGENTA}${cur_step_desc_str}${C_RESET}"
        log_msg "${P_INFO}   ${C_DIM}(Функция для выполнения: ${cur_step_fx_name})${C_RESET}"
        print_sep
        log_msg "  ${C_CYAN}1.${C_RESET} ${C_GREEN}Выполнить / Повторить текущий шаг${C_RESET}"
        log_msg "  ${C_CYAN}2.${C_RESET} ${C_BOLD_YELLOW}Пропустить текущий шаг${C_RESET}"
        log_msg "  ${C_CYAN}3.${C_RESET} ${C_BOLD_BLUE}Перейти в Ручное меню для этого модуля${C_RESET}"
        log_msg "---"
        log_msg "  ${C_CYAN}M.${C_RESET} Назад в ${C_BOLD_RED}Главное меню${C_RESET}"

        local user_guido_choice_val
        read -r -p "$(echo -e "${P_PROMPT} Ваш выбор (1-3, M): ${C_RESET}")" user_guido_choice_val < /dev/tty
        user_guido_choice_val=$(echo "$user_guido_choice_val" | tr '[:lower:]' '[:upper:]')

        case "$user_guido_choice_val" in
            "1")
                if _run_step "$cur_step_fx_name" "$cur_vm_role_val" "$cur_mod_num_val" "$cur_step_desc_str"; then
                    cur_guido_step_idx_val=$((cur_guido_step_idx_val + 1))
                    echo "$cur_guido_step_idx_val" > "$guido_step_idx_file_pth"
                else
                    local step_wrap_exit_code_val=$?
                    if [[ "$step_wrap_exit_code_val" -eq 1 ]]; then
                        log_msg "${P_INFO} Guido остается на текущем шаге из-за ошибки."
                    elif [[ "$step_wrap_exit_code_val" -eq 2 ]]; then
                        log_msg "${P_WARN} Guido будет приостановлен. Выполните необходимое внешнее действие и запустите Guido снова."
                        pause_pmt; return 0
                    fi
                fi
                pause_pmt
                ;;
            "2")
                log_msg "${P_WARN} Шаг '${C_YELLOW}${cur_step_desc_str}${P_WARN}' пропущен пользователем."
                cur_guido_step_idx_val=$((cur_guido_step_idx_val + 1))
                echo "$cur_guido_step_idx_val" > "$guido_step_idx_file_pth"
                pause_pmt
                ;;
            "3")
                log_msg "${P_INFO} Переход в ручное меню для модуля ${C_CYAN}$cur_vm_role_val${P_INFO} - M${C_CYAN}${cur_mod_num_val}${P_INFO}..."
                run_manual_mod "$cur_vm_role_val" "$cur_mod_num_val" "$guido_step_idx_file_pth"
                if [[ -f "$guido_step_idx_file_pth" ]]; then
                    cur_guido_step_idx_val=$(cat "$guido_step_idx_file_pth")
                    if ! [[ "$cur_guido_step_idx_val" =~ ^[0-9]+$ ]]; then cur_guido_step_idx_val=0; fi
                else
                    cur_guido_step_idx_val=0
                fi
                ;;
            "M")
                log_msg "${P_INFO} Возврат в Главное меню из Guido..."; return 0
                ;;
            *)
                log_msg "${P_ERROR} Неверный выбор. Пожалуйста, попробуйте снова."
                pause_pmt
                ;;
        esac
    done

    if [[ "$cur_guido_step_idx_val" -ge "${#cur_scn_ref[@]}" ]]; then
        log_msg "${P_OK} ${C_GREEN}Все шаги сценария для ${C_CYAN}$cur_vm_role_val${C_GREEN} - Модуль ${C_CYAN}${cur_mod_num_val}${C_GREEN} успешно пройдены в режиме Guido.${C_RESET}"
        echo "0" > "$guido_step_idx_file_pth"
        pause_pmt
    fi
    return 0
}

# --- Функция: run_manual_mod ---
# Назначение: Отображает меню для ручного выбора и выполнения шагов модуля.
# Параметры: $1:Код роли ВМ, $2:Номер модуля, $3:Путь к файлу индекса Guido.
run_manual_mod() {
    local cur_vm_role_val="$1"
    local cur_mod_num_val="$2"
    local guido_idx_file_ref_val="$3"
    local scn_array_name_manual_val="SCN_${cur_vm_role_val}_M${cur_mod_num_val}"

    if ! declare -p "$scn_array_name_manual_val" &>/dev/null; then
        log_msg "${P_ERROR} Сценарий ${C_BOLD_RED}$scn_array_name_manual_val${P_ERROR} не найден."; pause_pmt; return 1
    fi
    declare -n cur_scn_manual_ref="$scn_array_name_manual_val"
    if [[ ${#cur_scn_manual_ref[@]} -eq 0 ]]; then
        log_msg "${P_INFO} Сценарий для ${C_CYAN}$cur_vm_role_val${P_INFO} - M${C_CYAN}${cur_mod_num_val}${P_INFO} пуст."; pause_pmt; return 0
    fi

    local user_manual_choice_val
    while true; do
        clear
        log_msg "${C_BOLD_BLUE}=== Ручное меню: ${C_CYAN}$cur_vm_role_val${C_BOLD_BLUE} - Модуль ${C_CYAN}M${cur_mod_num_val}${C_BOLD_BLUE} ==="
        log_msg "${P_INFO} Выберите шаг для выполнения или повторного выполнения:"
        print_sep
        local idx_manual_val=0
        for step_fx_manual_val in "${cur_scn_manual_ref[@]}"; do
            local disp_idx_manual_val=$((idx_manual_val + 1))
            local step_desc_manual_val
            step_desc_manual_val="${step_fx_manual_val//_/ }"
            step_desc_manual_val="${step_desc_manual_val//setup /}"
            step_desc_manual_val="${step_desc_manual_val//${cur_vm_role_val,,} m${cur_mod_num_val} /}"
            step_desc_manual_val=$(echo "$step_desc_manual_val" | awk '{for(j=1;j<=NF;j++) $j=toupper(substr($j,1,1)) substr($j,2)}1')
            # Дополнительные замены для улучшения читаемости описания шага (аналогично run_guido_mod)
            step_desc_manual_val=$(echo "$step_desc_manual_val" | sed \
                -e 's/Net Ifaces Wan Lan Trunk/Network Interfaces WAN LAN Trunk/g' \
                -e 's/Net Ifaces/Network Interfaces/g' \
                -e 's/Ip Forwarding/IP Forwarding/g' \
                -e 's/Net Restart Base Ip/Network Restart (Base IP)/g' \
                -e 's/Net Restart Init/Network Restart (Initial)/g' \
                -e 's/Net Restart/Network Restart/g' \
                -e 's/Iptables Nat Mss/iptables NAT & MSS Clamping/g' \
                -e 's/Iptables Nat/iptables NAT/g' \
                -e 's/User Net Admin/User net_admin/g' \
                -e 's/User Sshuser/User sshuser/g' \
                -e 's/Vlans/VLANs/g' \
                -e 's/Gre Tunnel/GRE Tunnel/g' \
                -e 's/Tz/Timezone/g' \
                -e 's/Dns Cli Final/DNS Client (Final)/g' \
                -e 's/Dns Srv/DNS Server/g' \
                -e 's/Dhcp Srv/DHCP Server/g' \
                -e 's/Dhcp Cli Cfg/DHCP Client Config/g' \
                -e 's/Ospf/OSPF/g' \
                -e 's/Tmp Static Ip/Temporary Static IP/g' \
                -e 's/Init Reboot After Static Ip/Reboot after Static IP/g' \
                -e 's/Ntp Srv/NTP Server/g' \
                -e 's/Ntp Cli/NTP Client/g' \
                -e 's/Nginx Reverse Proxy/Nginx Reverse Proxy/g' \
                -e 's/Dnat Ssh To Hqsrv/DNAT SSH to HQSRV/g' \
                -e 's/Dnat Wiki Ssh To Brsrv/DNAT Wiki & SSH to BRSRV/g' \
                -e 's/Ssh Srv Port Update/SSH Server Port Update/g' \
                -e 's/Ssh Srv En/SSH Server Enable/g' \
                -e 's/Ssh Srv/SSH Server/g' \
                -e 's/Raid Nfs Srv/RAID & NFS Server/g' \
                -e 's/Dns Forwarding For Ad/DNS Forwarding for AD/g' \
                -e 's/Moodle Inst P1 Services Db/Moodle Install (Part 1: Services, DB)/g' \
                -e 's/Moodle Inst P2 Web Setup Pmt/Moodle Install (Part 2: Web Setup Prompt)/g' \
                -e 's/Moodle Inst P3 Proxy Cfg/Moodle Install (Part 3: Proxy Config)/g' \
                -e 's/Samba Dc Inst Provision/Samba DC Install & Provision/g' \
                -e 's/Samba Dc Kerberos Dns Crontab/Samba DC Kerberos, DNS, Crontab/g' \
                -e 's/Samba Dc Create Users Groups/Samba DC Create Users & Groups/g' \
                -e 's/Samba Dc Import Users Csv/Samba DC Import Users from CSV/g' \
                -e 's/Samba Ad Join/Samba AD Join/g' \
                -e 's/Ansible Inst Ssh Key Gen/Ansible Install & SSH Key Gen/g' \
                -e 's/Ansible Ssh Copy Id Pmt/Ansible SSH Copy ID Prompt/g' \
                -e 's/Ansible Cfg Files/Ansible Config Files/g' \
                -e 's/Docker Mediawiki Inst P1 Compose Up/Docker MediaWiki (Part 1: Compose Up)/g' \
                -e 's/Docker Mediawiki Inst P2 Web Setup Pmt/Docker MediaWiki (Part 2: Web Setup Prompt)/g' \
                -e 's/Docker Mediawiki Inst P3 Apply Localsettings/Docker MediaWiki (Part 3: Apply LocalSettings)/g' \
                -e 's/Yabrowser Inst Bg/Yandex Browser Install (Background)/g' \
                -e 's/Init Reboot After Ad Join/Reboot after AD Join/g' \
                -e 's/Create Domain User Homedirs/Create Domain User Homedirs/g' \
                -e 's/Sudo For Domain Group/Sudo for Domain Group/g' \
                -e 's/Nfs Cli Mount/NFS Client Mount/g' \
                -e 's/Wait Yabrowser Inst/Wait Yandex Browser Install/g' \
                -e 's/Copy Localsettings To Brsrv Pmt/Copy LocalSettings.php to BRSRV Prompt/g' \
            )

            local step_status_sym_manual_val="${C_DIM}[ ]${C_RESET}"
            local flag_done_manual_pth_val="${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_${step_fx_manual_val}_done.flag"
            local flag_error_manual_pth_val="${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_${step_fx_manual_val}_error.flag"
            local has_any_pending_flag_manual_val=0
            if compgen -G "${FLAG_DIR_BASE}/${cur_vm_role_val}_M${cur_mod_num_val}_${step_fx_manual_val}_pending_*.flag" > /dev/null; then
                has_any_pending_flag_manual_val=1
            fi

            if [[ -f "$flag_done_manual_pth_val" && ! -f "$flag_error_manual_pth_val" ]]; then step_status_sym_manual_val="${C_GREEN}[✓]${C_RESET}";
            elif [[ -f "$flag_error_manual_pth_val" ]]; then step_status_sym_manual_val="${C_BOLD_RED}[!]${C_RESET}";
            elif [[ "$has_any_pending_flag_manual_val" -eq 1 ]]; then step_status_sym_manual_val="${C_BOLD_YELLOW}[P]${C_RESET}"; fi

            log_msg "  ${C_CYAN}${disp_idx_manual_val}.${C_RESET} ${step_status_sym_manual_val} ${step_desc_manual_val} ${C_DIM}(${step_fx_manual_val})${C_RESET}"
            idx_manual_val=$((idx_manual_val + 1))
        done
        print_sep
        log_msg "  ${C_CYAN}B.${C_RESET} Назад в ${C_BOLD_YELLOW}Guido / Главное меню${C_RESET}"

        read -r -p "$(echo -e "${P_PROMPT} Ваш выбор (1-${#cur_scn_manual_ref[@]}, B): ${C_RESET}")" user_manual_choice_val < /dev/tty
        user_manual_choice_val=$(echo "$user_manual_choice_val" | tr '[:lower:]' '[:upper:]')

        if [[ "$user_manual_choice_val" == "B" ]]; then
            log_msg "${P_INFO} Возврат из ручного меню..."; return 0
        fi

        if [[ "$user_manual_choice_val" =~ ^[0-9]+$ ]] && \
           [ "$user_manual_choice_val" -ge 1 ] && \
           [ "$user_manual_choice_val" -le "${#cur_scn_manual_ref[@]}" ]; then
            local sel_manual_step_idx_val=$((user_manual_choice_val - 1))
            local sel_manual_step_fx_name="${cur_scn_manual_ref[$sel_manual_step_idx_val]}"
            local sel_manual_step_desc_str
            sel_manual_step_desc_str="${sel_manual_step_fx_name//_/ }"
            sel_manual_step_desc_str="${sel_manual_step_desc_str//setup /}"
            sel_manual_step_desc_str="${sel_manual_step_desc_str//${cur_vm_role_val,,} m${cur_mod_num_val} /}"
            sel_manual_step_desc_str=$(echo "$sel_manual_step_desc_str" | awk '{for(j=1;j<=NF;j++) $j=toupper(substr($j,1,1)) substr($j,2)}1')
            # Дополнительные замены для улучшения читаемости описания шага (аналогично run_guido_mod)
            sel_manual_step_desc_str=$(echo "$sel_manual_step_desc_str" | sed \
                -e 's/Net Ifaces Wan Lan Trunk/Network Interfaces WAN LAN Trunk/g' \
                -e 's/Net Ifaces/Network Interfaces/g' \
                -e 's/Ip Forwarding/IP Forwarding/g' \
                -e 's/Net Restart Base Ip/Network Restart (Base IP)/g' \
                -e 's/Net Restart Init/Network Restart (Initial)/g' \
                -e 's/Net Restart/Network Restart/g' \
                -e 's/Iptables Nat Mss/iptables NAT & MSS Clamping/g' \
                -e 's/Iptables Nat/iptables NAT/g' \
                -e 's/User Net Admin/User net_admin/g' \
                -e 's/User Sshuser/User sshuser/g' \
                -e 's/Vlans/VLANs/g' \
                -e 's/Gre Tunnel/GRE Tunnel/g' \
                -e 's/Tz/Timezone/g' \
                -e 's/Dns Cli Final/DNS Client (Final)/g' \
                -e 's/Dns Srv/DNS Server/g' \
                -e 's/Dhcp Srv/DHCP Server/g' \
                -e 's/Dhcp Cli Cfg/DHCP Client Config/g' \
                -e 's/Ospf/OSPF/g' \
                -e 's/Tmp Static Ip/Temporary Static IP/g' \
                -e 's/Init Reboot After Static Ip/Reboot after Static IP/g' \
                -e 's/Ntp Srv/NTP Server/g' \
                -e 's/Ntp Cli/NTP Client/g' \
                -e 's/Nginx Reverse Proxy/Nginx Reverse Proxy/g' \
                -e 's/Dnat Ssh To Hqsrv/DNAT SSH to HQSRV/g' \
                -e 's/Dnat Wiki Ssh To Brsrv/DNAT Wiki & SSH to BRSRV/g' \
                -e 's/Ssh Srv Port Update/SSH Server Port Update/g' \
                -e 's/Ssh Srv En/SSH Server Enable/g' \
                -e 's/Ssh Srv/SSH Server/g' \
                -e 's/Raid Nfs Srv/RAID & NFS Server/g' \
                -e 's/Dns Forwarding For Ad/DNS Forwarding for AD/g' \
                -e 's/Moodle Inst P1 Services Db/Moodle Install (Part 1: Services, DB)/g' \
                -e 's/Moodle Inst P2 Web Setup Pmt/Moodle Install (Part 2: Web Setup Prompt)/g' \
                -e 's/Moodle Inst P3 Proxy Cfg/Moodle Install (Part 3: Proxy Config)/g' \
                -e 's/Samba Dc Inst Provision/Samba DC Install & Provision/g' \
                -e 's/Samba Dc Kerberos Dns Crontab/Samba DC Kerberos, DNS, Crontab/g' \
                -e 's/Samba Dc Create Users Groups/Samba DC Create Users & Groups/g' \
                -e 's/Samba Dc Import Users Csv/Samba DC Import Users from CSV/g' \
                -e 's/Samba Ad Join/Samba AD Join/g' \
                -e 's/Ansible Inst Ssh Key Gen/Ansible Install & SSH Key Gen/g' \
                -e 's/Ansible Ssh Copy Id Pmt/Ansible SSH Copy ID Prompt/g' \
                -e 's/Ansible Cfg Files/Ansible Config Files/g' \
                -e 's/Docker Mediawiki Inst P1 Compose Up/Docker MediaWiki (Part 1: Compose Up)/g' \
                -e 's/Docker Mediawiki Inst P2 Web Setup Pmt/Docker MediaWiki (Part 2: Web Setup Prompt)/g' \
                -e 's/Docker Mediawiki Inst P3 Apply Localsettings/Docker MediaWiki (Part 3: Apply LocalSettings)/g' \
                -e 's/Yabrowser Inst Bg/Yandex Browser Install (Background)/g' \
                -e 's/Init Reboot After Ad Join/Reboot after AD Join/g' \
                -e 's/Create Domain User Homedirs/Create Domain User Homedirs/g' \
                -e 's/Sudo For Domain Group/Sudo for Domain Group/g' \
                -e 's/Nfs Cli Mount/NFS Client Mount/g' \
                -e 's/Wait Yabrowser Inst/Wait Yandex Browser Install/g' \
                -e 's/Copy Localsettings To Brsrv Pmt/Copy LocalSettings.php to BRSRV Prompt/g' \
            )


            if _run_step "$sel_manual_step_fx_name" "$cur_vm_role_val" "$cur_mod_num_val" "$sel_manual_step_desc_str"; then
                if [[ -f "$guido_idx_file_ref_val" ]]; then
                    local cur_guido_idx_val; cur_guido_idx_val=$(cat "$guido_idx_file_ref_val")
                    if [[ "$sel_manual_step_idx_val" -ge "$cur_guido_idx_val" ]]; then
                        local next_guido_idx_val=$((sel_manual_step_idx_val + 1))
                        if [[ "$next_guido_idx_val" -ge "${#cur_scn_manual_ref[@]}" ]]; then
                            next_guido_idx_val="${#cur_scn_manual_ref[@]}"
                        fi
                        echo "$next_guido_idx_val" > "$guido_idx_file_ref_val"
                        log_msg "${P_INFO} Индекс Guido обновлен на: ${C_CYAN}$next_guido_idx_val${C_RESET} (после ручного выполнения)."
                    fi
                fi
            else
                local manual_step_exit_code_val=$?
                 if [[ "$manual_step_exit_code_val" -eq 2 ]]; then
                    log_msg "${P_WARN} Выполненный шаг требует внешнего действия. Для продолжения Guido, вернитесь в него."
                fi
            fi
            pause_pmt
        else
            log_msg "${P_ERROR} Неверный выбор. Пожалуйста, попробуйте снова."
            pause_pmt
        fi
    done
}

# === Блок: Функции для выбора сценария ===

# --- Функция: select_de_scenario ---
# Назначение: Отображает меню для выбора доступного сценария ДЭ.
#             Обновляет глобальную переменную g_cur_de_scenario_name.
# Возвращает: 0, если сценарий успешно выбран, 1 если выбор отменен или нет доступных сценариев.
select_de_scenario() {
    local available_scenarios_arr=()
    local scenario_display_names_arr=()
    
    log_msg "${P_INFO} Поиск доступных сценариев в ${C_CYAN}${SCENARIOS_DIR}${C_RESET}..." "/dev/tty"

    # Ищем файлы *_cfg.sh и извлекаем из них имена сценариев
    for cfg_file_path_val in "${SCENARIOS_DIR}"/*_cfg.sh; do
        if [[ -f "$cfg_file_path_val" ]]; then
            local scenario_filename_val; scenario_filename_val=$(basename "$cfg_file_path_val")
            local scenario_name_candidate_val="${scenario_filename_val%_cfg.sh}"
            
            if check_scenario_exists "$scenario_name_candidate_val"; then
                available_scenarios_arr+=("$scenario_name_candidate_val")
                local display_name_val="$scenario_name_candidate_val"
                if [[ "$scenario_name_candidate_val" == "default" ]]; then
                    display_name_val+=" (По умолчанию)"
                fi
                scenario_display_names_arr+=("$display_name_val")
                log_msg "${P_INFO} ${C_DIM}Найден валидный сценарий: ${scenario_name_candidate_val}${C_RESET}" "/dev/null"
            else
                log_msg "${P_WARN} ${C_DIM}Кандидат в сценарии '${scenario_name_candidate_val}' (из файла ${scenario_filename_val}) не прошел проверку (отсутствуют все компоненты).${C_RESET}" "/dev/null"
            fi
        fi
    done

    if [[ ${#available_scenarios_arr[@]} -eq 0 ]]; then
        log_msg "${P_ERROR} Не найдено ни одного валидного сценария в каталоге ${C_BOLD_RED}${SCENARIOS_DIR}${P_ERROR}." "/dev/tty"
        log_msg "${P_ERROR} Убедитесь, что для каждого сценария <name> существуют:" "/dev/tty"
        log_msg "${P_ERROR}   1. ${C_CYAN}${SCENARIOS_DIR}/<name>_cfg.sh${C_RESET}" "/dev/tty"
        log_msg "${P_ERROR}   2. ${C_CYAN}${SCENARIOS_DIR}/<name>_scn.sh${C_RESET}" "/dev/tty"
        log_msg "${P_ERROR}   3. Каталог ${C_CYAN}${FX_LIB_DIR}/<name>/${C_RESET}" "/dev/tty"
        return 1
    fi

    local user_choice_scn_val
    while true; do
        clear
        log_msg "${P_WARN} ${C_BOLD_YELLOW}!!! Необходимо выбрать сценарий Демонстрационного Экзамена !!!${C_RESET}" "/dev/tty"
        log_msg "${P_INFO} Пожалуйста, выберите один из доступных сценариев:" "/dev/tty"
        print_sep
        local i=1
        for display_scenario_name_val in "${scenario_display_names_arr[@]}"; do
            log_msg "  ${C_CYAN}${i}.${C_RESET} ${display_scenario_name_val}" "/dev/tty"
            i=$((i + 1))
        done
        print_sep
        log_msg "  ${C_CYAN}X.${C_RESET} Выход из скрипта" "/dev/tty"

        read -r -p "$(echo -e "${P_PROMPT} Ваш выбор (1-$((${#available_scenarios_arr[@]})), X): ${C_RESET}")" user_choice_scn_val < /dev/tty
        user_choice_scn_val=$(echo "$user_choice_scn_val" | tr '[:lower:]' '[:upper:]')

        if [[ "$user_choice_scn_val" == "X" ]]; then
            log_msg "${P_INFO} Выход из скрипта по выбору пользователя." "/dev/tty"
            return 1 # Возвращаем 1, чтобы главный скрипт мог выйти
        fi

        if [[ "$user_choice_scn_val" =~ ^[0-9]+$ ]] && \
           [ "$user_choice_scn_val" -ge 1 ] && \
           [ "$user_choice_scn_val" -le ${#available_scenarios_arr[@]} ]; then
            g_cur_de_scenario_name="${available_scenarios_arr[$((user_choice_scn_val - 1))]}"
            log_msg "${P_OK} Выбран сценарий: ${C_GREEN}$g_cur_de_scenario_name${C_RESET}" "/dev/tty"
            pause_pmt "Нажмите Enter для продолжения с выбранным сценарием."
            return 0
        else
            log_msg "${P_ERROR} Неверный выбор. Пожалуйста, попробуйте снова." "/dev/tty"
            pause_pmt
        fi
    done
}
export -f select_de_scenario

# === Блок: Функции для определения роли, отображения информации и переключения режимов ===

# --- Функция: det_vm_role ---
# Назначение: Автоматически определяет роль текущей ВМ.
det_vm_role() {
    local local_fqdn_val; local_fqdn_val=$(hostname -f 2>/dev/null)
    if [[ -z "$local_fqdn_val" || "$local_fqdn_val" == "localhost" || "$local_fqdn_val" == "(none)" ]]; then
        local_fqdn_val="$HOSTNAME"
    fi

    g_eff_hn_for_role="$local_fqdn_val"
    g_cur_vm_role="UNKNOWN" # Используем глобальную переменную g_cur_vm_role

    for role_key_lc_val in "${!EXPECTED_FQDNS[@]}"; do
        if [[ "${g_eff_hn_for_role,,}" == "${EXPECTED_FQDNS[$role_key_lc_val],,}" ]]; then
            g_cur_vm_role="${role_key_lc_val^^}"
            return 0
        fi
        if [[ "${g_eff_hn_for_role,,}" == "${role_key_lc_val}."* && "${g_eff_hn_for_role,,}" == *"${DOM_NAME,,}"* ]]; then
             g_cur_vm_role="${role_key_lc_val^^}"
             return 0
        fi
    done

    g_eff_hn_for_role="$HOSTNAME"
    for role_key_lc_val in "${!EXPECTED_FQDNS[@]}"; do
        if [[ "${HOSTNAME,,}" == "$role_key_lc_val" ]]; then
            g_cur_vm_role="${role_key_lc_val^^}"
            return 0
        fi
    done

    g_cur_vm_role="UNKNOWN"
    return 1
}

# --- Функция: ask_vm_role ---
# Назначение: Предлагает пользователю вручную выбрать роль ВМ.
ask_vm_role() {
    local user_choice_role_val
    while true; do
        clear
        log_msg "${P_WARN} ${C_BOLD_YELLOW}!!! Роль текущей Виртуальной Машины не определена автоматически !!!${C_RESET}" "/dev/tty"
        log_msg "${P_INFO} Пожалуйста, выберите роль из списка:" "/dev/tty"
        print_sep
        local i=1
        for role_opt_code_val in "${ALL_VM_ROLES[@]}"; do
            log_msg "  ${C_CYAN}${i}.${C_RESET} ${role_opt_code_val} (${VM_ROLE_DESCS[$role_opt_code_val]})" "/dev/tty"
            i=$((i + 1))
        done
        print_sep
        log_msg "  ${C_CYAN}X.${C_RESET} Выход из скрипта" "/dev/tty"

        read -r -p "$(echo -e "${P_PROMPT} Ваш выбор (1-$((${#ALL_VM_ROLES[@]})), X): ${C_RESET}")" user_choice_role_val < /dev/tty
        user_choice_role_val=$(echo "$user_choice_role_val" | tr '[:lower:]' '[:upper:]')

        if [[ "$user_choice_role_val" == "X" ]]; then
            log_msg "${P_INFO} Выход из скрипта по выбору пользователя." "/dev/tty"
            on_exit 0 # on_exit из sneaky_utils.sh
        fi

        if [[ "$user_choice_role_val" =~ ^[0-9]+$ ]] && \
           [ "$user_choice_role_val" -ge 1 ] && \
           [ "$user_choice_role_val" -le ${#ALL_VM_ROLES[@]} ]; then
            g_cur_vm_role="${ALL_VM_ROLES[$((user_choice_role_val - 1))]}"
            g_eff_hn_for_role="${EXPECTED_FQDNS[${g_cur_vm_role,,}]}"
            log_msg "${P_OK} Выбрана роль: ${C_GREEN}$g_cur_vm_role${C_RESET} (Ожидаемый FQDN: ${C_CYAN}$g_eff_hn_for_role${C_RESET})" "/dev/tty"
            pause_pmt
            return 0
        else
            log_msg "${P_ERROR} Неверный выбор. Пожалуйста, попробуйте снова." "/dev/tty"
            pause_pmt
        fi
    done
}

# --- Функция: get_mod_status_sym ---
# Назначение: Определяет и возвращает символ общего статуса выполнения модуля.
# Параметры: $1:Код роли ВМ, $2:Номер модуля.
get_mod_status_sym() {
    local vm_role_for_timeline_val="$1"
    local mod_num_for_timeline_val="$2"
    local scn_var_name_timeline_val="SCN_${vm_role_for_timeline_val}_M${mod_num_for_timeline_val}"

    if ! declare -p "$scn_var_name_timeline_val" &>/dev/null; then
        echo -e "${C_DIM}[?]${C_RESET}"; return
    fi
    declare -n scn_ref_timeline_val="$scn_var_name_timeline_val"
    if [[ ${#scn_ref_timeline_val[@]} -eq 0 ]]; then
        echo -e "${C_DIM}[-]${C_RESET}"; return
    fi

    local total_steps_val=${#scn_ref_timeline_val[@]}
    local done_steps_cnt_val=0
    local error_steps_cnt_val=0
    local pending_steps_cnt_val=0

    for step_fx_timeline_val in "${scn_ref_timeline_val[@]}"; do
        local flag_done_pth_tl_val="${FLAG_DIR_BASE}/${vm_role_for_timeline_val}_M${mod_num_for_timeline_val}_${step_fx_timeline_val}_done.flag"
        local flag_error_pth_tl_val="${FLAG_DIR_BASE}/${vm_role_for_timeline_val}_M${mod_num_for_timeline_val}_${step_fx_timeline_val}_error.flag"
        local has_any_pending_flag_tl_val=0
        if compgen -G "${FLAG_DIR_BASE}/${vm_role_for_timeline_val}_M${mod_num_for_timeline_val}_${step_fx_timeline_val}_pending_*.flag" > /dev/null; then
            has_any_pending_flag_tl_val=1
        fi

        if [[ -f "$flag_error_pth_tl_val" ]]; then
            error_steps_cnt_val=$((error_steps_cnt_val + 1))
        elif [[ "$has_any_pending_flag_tl_val" -eq 1 ]]; then
            pending_steps_cnt_val=$((pending_steps_cnt_val + 1))
        elif [[ -f "$flag_done_pth_tl_val" ]]; then
            done_steps_cnt_val=$((done_steps_cnt_val + 1))
        fi
    done

    if [[ "$error_steps_cnt_val" -gt 0 ]]; then echo -e "${C_BOLD_RED}[!]${C_RESET}"; return; fi
    if [[ "$pending_steps_cnt_val" -gt 0 ]]; then echo -e "${C_BOLD_YELLOW}[P]${C_RESET}"; return; fi
    if [[ "$done_steps_cnt_val" -eq "$total_steps_val" ]]; then echo -e "${C_GREEN}[✓]${C_RESET}"; return; fi
    if [[ "$done_steps_cnt_val" -gt 0 ]]; then echo -e "${C_CYAN}[>]${C_RESET}"; return; fi
    echo -e "${C_DIM}[ ]${C_RESET}"; return
}

# --- Функция: disp_timeline ---
# Назначение: Отображает "чемпионский путь" с указанием статуса модулей.
disp_timeline() {
    log_msg "${C_BOLD_BLUE}Рекомендуемая последовательность и прогресс:${C_RESET}" "/dev/tty"
    if [[ ${#MAIN_SCN_SEQ[@]} -eq 0 ]]; then
        log_msg "  ${C_DIM}(Последовательность выполнения не определена в скрипте)${C_RESET}" "/dev/tty"
        print_sep; return
    fi

    for timeline_path_entry_val in "${MAIN_SCN_SEQ[@]}"; do
        if [[ "$timeline_path_entry_val" == "---"* ]]; then
            log_msg "  ${C_DIM}${timeline_path_entry_val}${C_RESET}" "/dev/tty"
            continue
        fi
        local role_in_tl_step_val; role_in_tl_step_val=$(echo "$timeline_path_entry_val" | awk -F: '{print $1}' | xargs)
        local mod_in_tl_step_val; mod_in_tl_step_val=$(echo "$timeline_path_entry_val" | awk -F: '{print $2}' | xargs)
        local desc_in_tl_step_val; desc_in_tl_step_val=$(echo "$timeline_path_entry_val" | cut -d: -f3- | sed 's/^[[:space:]]*//')

        local overall_status_sym_tl_val=""
        if [[ "$mod_in_tl_step_val" =~ ^[12]$ ]]; then
            overall_status_sym_tl_val=$(get_mod_status_sym "$role_in_tl_step_val" "$mod_in_tl_step_val")
        else
            overall_status_sym_tl_val="${C_DIM}[?]${C_RESET}"
        fi

        local output_timeline_line_val="  ${overall_status_sym_tl_val} ${C_CYAN}${role_in_tl_step_val}${C_RESET}: ${desc_in_tl_step_val}"
        if [[ -n "$g_cur_vm_role" && "$g_cur_vm_role" != "UNKNOWN" && "$role_in_tl_step_val" == "$g_cur_vm_role" ]]; then
            output_timeline_line_val="  ${overall_status_sym_tl_val} ${C_BOLD_YELLOW}${role_in_tl_step_val}${C_RESET}: ${C_BOLD_YELLOW}${desc_in_tl_step_val}${C_RESET}"
        fi
        log_msg "${output_timeline_line_val}" "/dev/tty"
    done
    print_sep
}

# --- Функции для переключения глобальных режимов ---

# --- Функция: tog_pretty_mode ---
# Назначение: Переключает режим использования ANSI-цветов.
tog_pretty_mode() {
    if [[ "$g_pretty_mode_en" == "y" ]]; then
        g_pretty_mode_en="n"
        init_colors_pfx
        log_msg "${P_INFO} Красочный (Pretty) вывод ${C_BOLD_RED}ВЫКЛЮЧЕН${C_RESET}." "/dev/tty"
    else
        g_pretty_mode_en="y"
        init_colors_pfx
        log_msg "${P_INFO} Красочный (Pretty) вывод ${C_GREEN}ВКЛЮЧЕН${C_RESET}." "/dev/tty"
    fi
    pause_pmt
}

# --- Функция: tog_logging ---
# Назначение: Переключает режим логирования действий скрипта в файл.
tog_logging() {
    if [[ "$g_log_en" == "y" ]]; then
        g_log_en="n"
        log_msg "${P_INFO} Логирование в файл ${C_BOLD_RED}ВЫКЛЮЧEНО${C_RESET}." "/dev/tty"
    else
        g_log_en="y"
        if [[ -z "$g_log_pth" ]]; then
            g_log_pth="${FLAG_DIR_BASE}/guido_log_$(date +%Y%m%d_%H%M%S)_${HOSTNAME}.log"
        fi
        touch "$g_log_pth" && chmod 600 "$g_log_pth"
        log_msg "${P_INFO} Логирование в файл ${C_GREEN}ВКЛЮЧEНО${C_RESET}. Файл лога: ${C_CYAN}$g_log_pth${C_RESET}" "/dev/tty"
        echo -e "================================\nЛог сессии скрипта \"Guido\"\nХост: $HOSTNAME (Определенная роль: $g_cur_vm_role)\nВремя начала логирования: $(date)\n================================" >> "$g_log_pth"
    fi
    pause_pmt
}

# --- Функция: tog_sneaky_mode ---
# Назначение: Переключает "sneaky" режим работы скрипта.
tog_sneaky_mode() {
    if [[ "$g_sneaky_mode_en" == "y" ]]; then
        g_sneaky_mode_en="n"
        log_msg "${P_INFO} Скрытый (Sneaky) режим ${C_BOLD_RED}ВЫКЛЮЧЕН${C_RESET}." "/dev/tty"
    else
        g_sneaky_mode_en="y"
        log_msg "${P_INFO} Скрытый (Sneaky) режим ${C_GREEN}ВКЛЮЧЕН${C_RESET}." "/dev/tty"
        log_msg "${P_WARN} ${C_BOLD_YELLOW}ВНИМАНИЕ: При выходе из скрипта в sneaky режиме будут предприняты попытки \"замести следы\".${C_RESET}" "/dev/tty"
    fi
    pause_pmt
}

# === Блок: Главное меню ===

# --- Функция: main_menu ---
# Назначение: Отображает главное меню скрипта.
main_menu() {
    if [ ! -d "$FLAG_DIR_BASE" ]; then
        if mkdir -p "$FLAG_DIR_BASE"; then
            log_msg "${P_INFO} Создана директория для хранения флагов выполнения: ${C_CYAN}$FLAG_DIR_BASE${C_RESET}"
        else
            log_msg "${P_ERROR} Не удалось создать директорию для флагов: ${C_BOLD_RED}$FLAG_DIR_BASE${P_ERROR}. Работа скрипта может быть некорректной."
        fi
    fi

    local user_main_menu_choice_val
    while true; do
        clear
        log_msg "${C_BOLD_BLUE}======================= ГЛАВНОЕ МЕНЮ \"Guido\" v2.1.0 =======================${C_RESET}" "/dev/tty"
        log_msg "${P_INFO} Текущий хост: ${C_CYAN}${HOSTNAME}${C_RESET} (Определен как FQDN: ${C_CYAN}$(hostname -f 2>/dev/null || echo "N/A")${C_RESET})" "/dev/tty"

        local log_status_color_mm_val log_status_text_mm_val log_file_disp_mm_val=""
        if [[ "$g_log_en" == "y" ]]; then
            log_status_color_mm_val="${C_GREEN}"; log_status_text_mm_val="ВКЛ";
            log_file_disp_mm_val=" ${C_DIM}(Файл: ${g_log_pth:-"не задан"})";
        else
            log_status_color_mm_val="${C_BOLD_RED}"; log_status_text_mm_val="ВЫКЛ";
        fi
        local pretty_status_text_mm_val; if [[ "$g_pretty_mode_en" == "y" ]]; then pretty_status_text_mm_val="${C_GREEN}ВКЛ${C_RESET}"; else pretty_status_text_mm_val="${C_BOLD_RED}ВЫКЛ${C_RESET}"; fi
        local sneaky_status_text_mm_val; if [[ "$g_sneaky_mode_en" == "y" ]]; then sneaky_status_text_mm_val="${C_GREEN}ВКЛ${C_RESET}"; else sneaky_status_text_mm_val="${C_BOLD_RED}ВЫКЛ${C_RESET}"; fi
        log_msg "${P_INFO} Статус режимов: Логирование: ${log_status_color_mm_val}${log_status_text_mm_val}${C_RESET}${log_file_disp_mm_val}${C_RESET} | Красота: ${pretty_status_text_mm_val} | Скрытность: ${sneaky_status_text_mm_val}" "/dev/tty"

        disp_timeline

        if [[ "$g_cur_vm_role" == "UNKNOWN" ]]; then
            log_msg "${P_WARN} ${C_BOLD_YELLOW}!!! Роль текущей Виртуальной Машины не определена. Пожалуйста, выберите роль. !!!${C_RESET}" "/dev/tty"
            log_msg "  ${C_CYAN}R.${C_RESET} Выбрать роль ВМ" "/dev/tty"
        else
            log_msg "${P_INFO} Текущая определенная роль ВМ: ${C_GREEN}$g_cur_vm_role${C_RESET} (${VM_ROLE_DESCS[$g_cur_vm_role]})" "/dev/tty"
            log_msg "  ${C_CYAN}1.${C_RESET} Настроить Модуль 1 для ${C_BOLD_BLUE}${g_cur_vm_role}${C_RESET} $(get_mod_status_sym "$g_cur_vm_role" "1")" "/dev/tty"
            log_msg "  ${C_CYAN}2.${C_RESET} Настроить Модуль 2 для ${C_BOLD_BLUE}${g_cur_vm_role}${C_RESET} $(get_mod_status_sym "$g_cur_vm_role" "2")" "/dev/tty"
            print_sep
            log_msg "  ${C_CYAN}R.${C_RESET} Сменить / Перевыбрать роль ВМ" "/dev/tty"
        fi
        log_msg "  ${C_CYAN}L.${C_RESET} Включить/Выключить логирование в файл" "/dev/tty"
        log_msg "  ${C_CYAN}P.${C_RESET} Включить/Выключить Красочный (Pretty) вывод" "/dev/tty"
        log_msg "  ${C_CYAN}S.${C_RESET} Включить/Выключить Скрытый (Sneaky) режим" "/dev/tty"
        log_msg "  ${C_CYAN}X.${C_RESET} Выход из скрипта" "/dev/tty"

        read -r -p "$(echo -e "${P_PROMPT} Ваш выбор: ${C_RESET}")" user_main_menu_choice_val < /dev/tty
        user_main_menu_choice_val=$(echo "$user_main_menu_choice_val" | tr '[:lower:]' '[:upper:]')

        case "$user_main_menu_choice_val" in
            "1")
                if [[ "$g_cur_vm_role" == "UNKNOWN" ]]; then
                    log_msg "${P_ERROR} Сначала необходимо выбрать роль ВМ (пункт 'R')." "/dev/tty"; pause_pmt
                else
                    run_guido_mod "$g_cur_vm_role" "1"
                fi ;;
            "2")
                if [[ "$g_cur_vm_role" == "UNKNOWN" ]]; then
                    log_msg "${P_ERROR} Сначала необходимо выбрать роль ВМ (пункт 'R')." "/dev/tty"; pause_pmt
                else
                    run_guido_mod "$g_cur_vm_role" "2"
                fi ;;
            "R") ask_vm_role ;;
            "L") tog_logging ;;
            "P") tog_pretty_mode ;;
            "S") tog_sneaky_mode ;;
            "X")
                log_msg "${P_INFO} Инициирован выход из скрипта..." "/dev/tty"
                on_exit 0 # on_exit из sneaky_utils.sh
                ;;
            *)
                log_msg "${P_ERROR} Неверный выбор. Пожалуйста, попробуйте снова." "/dev/tty"
                pause_pmt
                ;;
        esac
    done
}

# --- Мета-комментарий: Конец управляющих функций и логики меню ---