#!/bin/bash
# Файл: fx_lib/default/hq_cli/hq_cli_m2_fx.sh
# Содержит функции-шаги для роли HQ_CLI, Модуль 2, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для HQ_CLI - Модуль 2 (Сценарий: default) ---

# Функция: setup_hq_cli_m2_yabrowser_inst_bg
# Назначение: Запускает установку Яндекс.Браузера в фоновом режиме.
setup_hq_cli_m2_yabrowser_inst_bg() {
    local vm_role_code="HQ_CLI"; local mod_num_val="2"
    local step_name_for_flags_val="${FUNCNAME[0]}"
    local flag_bg_proc_started_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${step_name_for_flags_val}_bg_started.flag"
    local flag_inst_done_by_bg_proc_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${step_name_for_flags_val}_done.flag"

    log_msg "${P_ACTION} Установка Яндекс.Браузера на HQ_CLI (фоновый режим)..."
    
    if rpm -q "$m2_hq_cli_yabrowser_pkg_name" &>/dev/null; then
        log_msg "${P_OK} Яндекс.Браузер (${C_CYAN}$m2_hq_cli_yabrowser_pkg_name${C_GREEN}) уже установлен."
        touch "$flag_inst_done_by_bg_proc_val"
        rm -f "$flag_bg_proc_started_val"
        return 0
    fi

    if [[ -f "$flag_bg_proc_started_val" ]]; then
        log_msg "${P_INFO} Установка Яндекс.Браузера уже была запущена в фоновом режиме. Ожидайте завершения."
        return 0
    fi

    log_msg "${P_INFO} Обновление пакетного менеджера epm и запуск установки пакета ${C_CYAN}$m2_hq_cli_yabrowser_pkg_name${C_RESET} в фоновом режиме..."
    log_msg "${P_INFO} ${C_DIM}Это может занять некоторое время. Скрипт продолжит выполнение других шагов.${C_RESET}"
    
    (
        epm update -y && \
        epm -y install "$m2_hq_cli_yabrowser_pkg_name" && \
        touch "$flag_inst_done_by_bg_proc_val" && \
        rm -f "$flag_bg_proc_started_val" && \
        echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') - [INFO][Guido BG] Фоновая установка Яндекс.Браузера успешно завершена." > /dev/tty
    ) &
    local bg_proc_pid_val=$!

    if jobs -p | grep -q "^${bg_proc_pid_val}$"; then
        log_msg "${P_OK} Установка Яндекс.Браузера успешно запущена в фоновом режиме (PID: ${C_CYAN}$bg_proc_pid_val${C_RESET})."
        touch "$flag_bg_proc_started_val"
        reg_sneaky_cmd "epm -y install $m2_hq_cli_yabrowser_pkg_name & # (фоновая установка)"
        return 0
    else
        log_msg "${P_ERROR} Не удалось запустить установку Яндекс.Браузера в фоновом режиме."
        return 1
    fi
}

# Функция: setup_hq_cli_m2_ntp_cli
# Назначение: Настраивает HQ_CLI как NTP-клиента.
setup_hq_cli_m2_ntp_cli() {
    log_msg "${P_ACTION} Настройка NTP-клиента (chrony) на HQ_CLI..."
    if ! ensure_pkgs "chronyc" "chrony"; then
        log_msg "${P_ERROR} Пакет chrony не установлен."
        return 1
    fi

    local ntp_srv_ip_def_val; ntp_srv_ip_def_val=$(get_ip_only "$m1_hq_rtr_vlan_cli_ip")
    local ntp_srv_ip_val; ask_val_param "IP-адрес NTP-сервера (IP HQ_RTR в VLAN клиентов)" "$ntp_srv_ip_def_val" "is_ipcidr_valid" "ntp_srv_ip_val"
    ntp_srv_ip_val=$(get_ip_only "$ntp_srv_ip_val")

    if ! cat <<EOF > /etc/chrony.conf
# Конфигурация NTP-клиента chrony для HQ_CLI
server ${ntp_srv_ip_val} iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
    then
        log_msg "${P_ERROR} Ошибка записи в /etc/chrony.conf."; return 1
    fi
    log_msg "${P_OK} Файл /etc/chrony.conf успешно сконфигурирован (сервер: ${C_CYAN}$ntp_srv_ip_val${C_RESET})."
    reg_sneaky_cmd "cat /etc/chrony.conf # (сервер: $ntp_srv_ip_val)"

    if systemctl enable --now chronyd && systemctl restart chronyd && systemctl is-active --quiet chronyd; then
        log_msg "${P_OK} Служба chronyd (NTP-клиент) включена и активна."
        reg_sneaky_cmd "systemctl enable --now chronyd"
        return 0
    else
        log_msg "${P_ERROR} Не удалось запустить службу chronyd."
        systemctl status chronyd --no-pager -l
        return 1
    fi
}

# Функция: setup_hq_cli_m2_ssh_srv_en
# Назначение: Включает SSH-сервер на HQ_CLI.
setup_hq_cli_m2_ssh_srv_en() {
    log_msg "${P_ACTION} Включение SSH-сервера на HQ_CLI..."
    if ! ensure_pkgs "sshd" "openssh-server"; then
        log_msg "${P_ERROR} Пакет openssh-server не установлен и не может быть установлен."
        return 1
    fi

    if systemctl is-enabled --quiet sshd && systemctl is-active --quiet sshd; then
        log_msg "${P_OK} Служба SSH-сервера (sshd) уже включена и активна."
    else
        log_msg "${P_INFO} Попытка включить и запустить службу SSH-сервера (sshd)..."
        if systemctl enable --now sshd && systemctl is-active --quiet sshd; then
            log_msg "${P_OK} Служба SSH-сервера (sshd) успешно включена и запущена."
            reg_sneaky_cmd "systemctl enable --now sshd"
        else
            log_msg "${P_ERROR} Не удалось включить или запустить службу SSH-сервера (sshd)."
            systemctl status sshd --no-pager -l
            return 1
        fi
    fi
    return 0
}

# Функция: setup_hq_cli_m2_samba_ad_join
# Назначение: Вводит HQ_CLI в домен Active Directory.
setup_hq_cli_m2_samba_ad_join() {
    log_msg "${P_ACTION} Ввод HQ_CLI в домен Active Directory..."
    if ! ensure_pkgs "system-auth realm" "task-auth-ad-sssd realmd krb5-workstation sssd-ad sssd-tools"; then
        log_msg "${P_ERROR} Не удалось установить все необходимые пакеты для ввода в домен AD."
        return 1
    fi

    local ad_realm_upper_val; ask_param "Kerberos Realm домена AD" "$m2_br_srv_samba_realm_upper" "ad_realm_upper_val"
    local ad_dom_netbios_val; ask_param "NetBIOS имя домена AD" "$m2_br_srv_samba_domain_netbios" "ad_dom_netbios_val"
    local ad_admin_user_val; ask_param "Имя администратора домена AD" "$m2_hq_cli_samba_admin_user" "ad_admin_user_val"
    local ad_admin_pass_val; ask_param "Пароль администратора домена AD ('${ad_admin_user_val}')" "$m2_br_srv_samba_admin_pass_def" "ad_admin_pass_val"
    local hq_cli_short_hn_val="hq-cli"

    log_msg "${P_INFO} Принудительная синхронизация времени с NTP-сервером (chronyc burst)..."
    if ! chronyc burst 4/10; then
        log_msg "${P_WARN} Команда 'chronyc burst' не удалась. Проблемы с NTP могут помешать вводу в домен."
    else
        log_msg "${P_OK} Синхронизация времени (burst) выполнена."
    fi
    sleep 2

    log_msg "${P_INFO} Попытка ввода в домен ${C_CYAN}$ad_realm_upper_val${C_RESET} с использованием 'system-auth'..."
    if system-auth write ad "$ad_realm_upper_val" "$hq_cli_short_hn_val" "$ad_dom_netbios_val" "$ad_admin_user_val" "$ad_admin_pass_val"; then
        log_msg "${P_OK} Команда 'system-auth write ad' успешно выполнена."
        reg_sneaky_cmd "system-auth write ad $ad_realm_upper_val $hq_cli_short_hn_val $ad_dom_netbios_val $ad_admin_user_val ***"
        sleep 5
        
        log_msg "${P_INFO} Проверка статуса домена командой 'realm list'..."
        if realm list | grep -qi "$ad_realm_upper_val"; then
            log_msg "${P_OK} Машина HQ_CLI успешно введена в домен ${C_GREEN}$ad_realm_upper_val${C_RESET}."
            return 0
        else
            log_msg "${P_ERROR} Команда 'realm list' не показывает, что машина находится в домене ${C_BOLD_RED}$ad_realm_upper_val${P_ERROR}."
            return 1
        fi
    else
        log_msg "${P_ERROR} Ошибка выполнения команды 'system-auth write ad'. Проверьте вывод выше."
        return 1
    fi
}

# Функция: setup_hq_cli_m2_init_reboot_after_ad_join
# Назначение: Инициирует перезагрузку HQ_CLI после ввода в домен.
setup_hq_cli_m2_init_reboot_after_ad_join() {
    local vm_role_code="HQ_CLI"; local mod_num_val="2"
    local flag_reboot_initiated_ad_join_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${FUNCNAME[0]}_reboot_initiated.flag"
    
    log_msg "${P_ACTION} ${C_BOLD_MAGENTA}ВНИМАНИЕ: Машина будет перезагружена для полного применения настроек Active Directory.${C_RESET}"
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}После перезагрузки, пожалуйста, войдите снова под пользователем root и запустите этот скрипт повторно.${C_RESET}"
    pause_pmt "Нажмите Enter для инициации перезагрузки через 5 секунд..."
    
    log_msg "${P_INFO} Инициирую перезагрузку через 5 секунд..."
    sleep 5
    touch "$flag_reboot_initiated_ad_join_val"
    reg_sneaky_cmd "reboot # Инициирована перезагрузка HQ_CLI после ввода в домен"

    if reboot; then
        return 2 
    else
        log_msg "${P_ERROR} Команда 'reboot' не удалась. Пожалуйста, перезагрузите машину вручную."
        rm -f "$flag_reboot_initiated_ad_join_val"
        return 1
    fi
}

# Функция: setup_hq_cli_m2_create_domain_user_homedirs
# Назначение: Создает домашние каталоги для доменных пользователей.
setup_hq_cli_m2_create_domain_user_homedirs() {
    local vm_role_code="HQ_CLI"; local mod_num_val="2"
    local flag_reboot_marker_ad_join_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_setup_hq_cli_m2_init_reboot_after_ad_join_reboot_initiated.flag"
    if [[ ! -f "$flag_reboot_marker_ad_join_val" ]]; then
        log_msg "${P_WARN} Предыдущий шаг (перезагрузка после ввода в домен) не был завершен штатно или его флаг отсутствует."
        pause_pmt "Нажмите Enter, если уверены, что хотите продолжить."
    fi

    log_msg "${P_ACTION} Создание домашних каталогов для доменных пользователей на HQ_CLI..."
    
    local ad_realm_upper_homedir_val="$m2_br_srv_samba_realm_upper"
    local base_home_dir_val="/home/${ad_realm_upper_homedir_val,,}"
    local skel_dir_val="/etc/skel"

    if ! mkdir -p "$base_home_dir_val" && chmod 755 "$base_home_dir_val"; then
        log_msg "${P_ERROR} Не удалось создать или установить права на базовую директорию ${C_BOLD_RED}$base_home_dir_val${P_ERROR}."; return 1
    fi
    log_msg "${P_INFO} Базовая директория для домашних каталогов: ${C_CYAN}$base_home_dir_val${C_RESET}."

    local users_hq_list_val=(); for i in {1..5}; do users_hq_list_val+=("user${i}.hq"); done
    local users_csv_example_list_val=("lucian.buck" "jacob.schneider")
    local all_users_for_homedir_val=("${users_hq_list_val[@]}" "${users_csv_example_list_val[@]}")

    for username_mixed_case_val in "${all_users_for_homedir_val[@]}"; do
        local username_lower_val; username_lower_val=$(echo "$username_mixed_case_val" | tr '[:upper:]' '[:lower:]')
        local full_username_for_id_val="${username_lower_val}@${ad_realm_upper_homedir_val,,}"
        local user_home_pth_val="${base_home_dir_val}/${username_lower_val}"

        log_msg -n "${P_INFO} Обработка домашнего каталога для ${C_CYAN}$username_mixed_case_val${C_RESET}... " "/dev/tty"
        
        local user_uid_val; user_uid_val=$(id -u "$full_username_for_id_val" 2>/dev/null)
        local user_gid_val; user_gid_val=$(id -g "$full_username_for_id_val" 2>/dev/null)

        if [[ -n "$user_uid_val" && -n "$user_gid_val" ]]; then
            if [[ ! -d "$user_home_pth_val" ]]; then
                log_msg -n "создание... " "/dev/tty"
                if install -d -o "$user_uid_val" -g "$user_gid_val" -m 700 "$user_home_pth_val"; then
                    if cp -aT "${skel_dir_val}/" "${user_home_pth_val}/"; then
                        chown -R "${user_uid_val}:${user_gid_val}" "${user_home_pth_val}"
                        log_msg "${C_GREEN}успешно создан.${C_RESET}" "/dev/tty"
                        reg_sneaky_cmd "install -d -o $user_uid_val -g $user_gid_val -m 700 $user_home_pth_val; cp -aT /etc/skel/ $user_home_pth_val/"
                    else
                        log_msg "${P_ERROR} ошибка копирования из /etc/skel в ${C_BOLD_RED}$user_home_pth_val${P_ERROR}.${C_RESET}" "/dev/tty"
                    fi
                else
                    log_msg "${P_ERROR} ошибка команды 'install' для ${C_BOLD_RED}$user_home_pth_val${P_ERROR}.${C_RESET}" "/dev/tty"
                fi
            else
                log_msg -n "существует, обновление прав... " "/dev/tty"
                chown -R "${user_uid_val}:${user_gid_val}" "${user_home_pth_val}" && chmod 700 "${user_home_pth_val}"
                log_msg "${C_GREEN}успешно обновлен.${C_RESET}" "/dev/tty"
            fi
        else
            log_msg "${P_WARN} не удалось получить UID/GID для ${C_YELLOW}$full_username_for_id_val${P_WARN}. Пропуск.${C_RESET}" "/dev/tty"
        fi
    done

    if [[ -f "$flag_reboot_marker_ad_join_val" ]]; then
        rm -f "$flag_reboot_marker_ad_join_val"
        log_msg "${P_INFO} Флаг перезагрузки (${C_CYAN}$flag_reboot_marker_ad_join_val${C_RESET}) успешно удален."
    fi
    return 0
}

# Функция: setup_hq_cli_m2_sudo_for_domain_group
# Назначение: Настраивает права sudo для доменной группы 'hq'.
setup_hq_cli_m2_sudo_for_domain_group() {
    log_msg "${P_ACTION} Настройка прав sudo для доменной группы '${C_CYAN}$m2_hq_cli_sudo_group_name${C_RESET}' на HQ_CLI..."
    
    local dom_group_name_val="$m2_hq_cli_sudo_group_name"
    local allowed_sudo_cmds_val="$m2_hq_cli_sudo_allowed_cmds"
    local sudoers_cfg_file_pth_val="/etc/sudoers.d/${dom_group_name_val}"

    if command -v control &>/dev/null && control sudo public &>/dev/null; then
        log_msg "${P_OK} Поддержка /etc/sudoers.d включена через 'control sudo public'."
        reg_sneaky_cmd "control sudo public"
    else
        log_msg "${P_INFO} Команда 'control sudo public' не найдена или не выполнена. Предполагается, что /etc/sudoers.d уже активна."
    fi

    if echo "%${dom_group_name_val} ALL=(ALL) NOPASSWD:${allowed_sudo_cmds_val}" > "$sudoers_cfg_file_pth_val"; then
        chmod 0440 "$sudoers_cfg_file_pth_val"
        log_msg "${P_OK} Файл sudoers (${C_CYAN}$sudoers_cfg_file_pth_val${C_GREEN}) создан с правами для группы '${C_CYAN}$dom_group_name_val${C_RESET}'."
        reg_sneaky_cmd "echo '%${dom_group_name_val} ALL=(ALL) NOPASSWD:${allowed_sudo_cmds_val}' > $sudoers_cfg_file_pth_val"
        reg_sneaky_cmd "chmod 0440 $sudoers_cfg_file_pth_val"
        
        log_msg "${P_INFO} Проверка синтаксиса sudoers файла с помощью 'visudo -c -f ${sudoers_cfg_file_pth_val}'..."
        if visudo -c -f "$sudoers_cfg_file_pth_val"; then
            log_msg "${P_OK} Синтаксис файла sudoers (${C_GREEN}$sudoers_cfg_file_pth_val${C_RESET}) корректен."
            return 0
        else
            log_msg "${P_ERROR} Ошибка синтаксиса в файле sudoers (${C_BOLD_RED}$sudoers_cfg_file_pth_val${P_ERROR}). Файл будет удален."
            rm -f "$sudoers_cfg_file_pth_val"
            return 1
        fi
    else
        log_msg "${P_ERROR} Не удалось создать файл sudoers (${C_BOLD_RED}$sudoers_cfg_file_pth_val${P_ERROR})."; return 1
    fi
}

# Функция: setup_hq_cli_m2_nfs_cli_mount
# Назначение: Настраивает HQ_CLI как NFS-клиента.
setup_hq_cli_m2_nfs_cli_mount() {
    log_msg "${P_ACTION} Настройка NFS-клиента и монтирование общего ресурса на HQ_CLI..."
    if ! ensure_pkgs "mount.nfs" "nfs-utils"; then
        log_msg "${P_ERROR} Пакет nfs-utils (или эквивалент) не установлен."
        return 1
    fi

    local nfs_srv_ip_val; nfs_srv_ip_val=$(get_ip_only "$m1_hq_srv_lan_ip")
    local raid_level_on_srv_val; ask_val_param "Уровень RAID, используемый на HQ_SRV (для пути к NFS)" "$m2_hq_srv_raid_level_def" "is_not_empty_valid" "raid_level_on_srv_val"
    local remote_nfs_share_pth_def_val="${m2_hq_srv_raid_mount_point_base}${raid_level_on_srv_val}/${m2_hq_srv_nfs_export_subdir}"
    local local_nfs_mount_point_val; ask_param "Локальная точка монтирования для NFS" "$m2_hq_cli_nfs_mount_point" "local_nfs_mount_point_val"

    ask_val_param "IP-адрес NFS-сервера (HQ_SRV)" "$nfs_srv_ip_val" "is_ipcidr_valid" "nfs_srv_ip_val"
    nfs_srv_ip_val=$(get_ip_only "$nfs_srv_ip_val")
    local remote_nfs_share_pth_val; ask_param "Полный путь к удаленному NFS-ресурсу на сервере" "$remote_nfs_share_pth_def_val" "remote_nfs_share_pth_val"
    
    mkdir -p "$local_nfs_mount_point_val"
    log_msg "${P_INFO} Локальная точка монтирования NFS: ${C_CYAN}$local_nfs_mount_point_val${C_RESET}."

    local fstab_nfs_entry_val="${nfs_srv_ip_val}:${remote_nfs_share_pth_val} ${local_nfs_mount_point_val} nfs intr,soft,_netdev,x-systemd.automount,users,rw 0 0"
    
    if grep -qF "${local_nfs_mount_point_val} nfs" /etc/fstab; then
        sed -i "s|^.*${local_nfs_mount_point_val}[[:space:]]nfs.*|${fstab_nfs_entry_val}|" /etc/fstab
        log_msg "${P_OK} Запись NFS для ${C_CYAN}$local_nfs_mount_point_val${C_GREEN} обновлена в /etc/fstab."
    else
        echo "$fstab_nfs_entry_val" >> /etc/fstab
        log_msg "${P_OK} Запись NFS для ${C_CYAN}$local_nfs_mount_point_val${C_GREEN} добавлена в /etc/fstab."
    fi
    reg_sneaky_cmd "echo '$fstab_nfs_entry_val' >> /etc/fstab # (или sed)"

    log_msg "${P_INFO} Перезагрузка конфигурации systemd и попытка монтирования (mount -a)..."
    if systemctl daemon-reload && mount -a; then
        log_msg "${P_OK} Конфигурация systemd перезагружена, команда 'mount -a' выполнена."
        reg_sneaky_cmd "systemctl daemon-reload; mount -a"
        if mountpoint -q "$local_nfs_mount_point_val"; then
            log_msg "${P_OK} NFS-ресурс ${C_GREEN}$local_nfs_mount_point_val${C_RESET} успешно смонтирован."
            return 0
        else
            log_msg "${P_ERROR} NFS-ресурс ${C_BOLD_RED}$local_nfs_mount_point_val${P_ERROR} НЕ смонтирован после 'mount -a'."
            return 1
        fi
    else
        log_msg "${P_ERROR} Ошибка при выполнении 'systemctl daemon-reload' или 'mount -a'."; return 1
    fi
}

# Функция: setup_hq_cli_m2_wait_yabrowser_inst
# Назначение: Ожидает завершения фоновой установки Яндекс.Браузера.
setup_hq_cli_m2_wait_yabrowser_inst() {
    local vm_role_code="HQ_CLI"; local mod_num_val="2"
    local bg_inst_step_name_val="setup_hq_cli_m2_yabrowser_inst_bg"
    local flag_bg_proc_has_started_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${bg_inst_step_name_val}_bg_started.flag"
    local flag_bg_inst_is_done_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${bg_inst_step_name_val}_done.flag"

    log_msg "${P_ACTION} Ожидание завершения установки Яндекс.Браузера на HQ_CLI..."

    if [[ -f "$flag_bg_inst_is_done_val" ]]; then
        log_msg "${P_OK} Установка Яндекс.Браузера уже была отмечена как завершенная."
        return 0
    fi

    if [[ ! -f "$flag_bg_proc_has_started_val" ]]; then
        log_msg "${P_WARN} Фоновая установка Яндекс.Браузера не была запущена."
        log_msg "${P_INFO} Проверка, установлен ли пакет ${C_CYAN}$m2_hq_cli_yabrowser_pkg_name${C_RESET} вручную..."
        if rpm -q "$m2_hq_cli_yabrowser_pkg_name" &>/dev/null; then
            log_msg "${P_OK} Яндекс.Браузер (${C_CYAN}$m2_hq_cli_yabrowser_pkg_name${C_GREEN}) уже установлен."
            touch "$flag_bg_inst_is_done_val"
            return 0
        else
            log_msg "${P_ERROR} Яндекс.Браузер не установлен, и фоновый процесс установки не был запущен."
            return 1
        fi
    fi

    log_msg "${P_INFO} Ожидание завершения фоновой установки Яндекс.Браузера (максимум ~5 минут)..."
    local wait_timeout_sec_val=300
    local check_interval_sec_val=5
    local time_waited_sec_val=0

    while [[ -f "$flag_bg_proc_has_started_val" && $time_waited_sec_val -lt $wait_timeout_sec_val ]]; do
        if [[ -f "$flag_bg_inst_is_done_val" ]]; then
            log_msg "\n${P_OK} Установка Яндекс.Браузера успешно завершена."
            return 0
        fi
        log_msg -n "." "/dev/tty"; sleep "$check_interval_sec_val"
        time_waited_sec_val=$((time_waited_sec_val + check_interval_sec_val))
    done
    echo ""

    if [[ -f "$flag_bg_inst_is_done_val" ]]; then
        log_msg "${P_OK} Установка Яндекс.Браузера успешно завершена."
        return 0
    elif [[ -f "$flag_bg_proc_has_started_val" ]]; then
        log_msg "${P_ERROR} Время ожидания установки Яндекс.Браузера истекло."
        return 1
    else
        log_msg "${P_WARN} Фоновый процесс установки Яндекс.Браузера, похоже, завершился, но флаг успеха не был установлен."
        log_msg "${P_INFO} Повторная проверка пакета ${C_CYAN}$m2_hq_cli_yabrowser_pkg_name${C_RESET}..."
        if rpm -q "$m2_hq_cli_yabrowser_pkg_name" &>/dev/null; then
            log_msg "${P_OK} Яндекс.Браузер (${C_CYAN}$m2_hq_cli_yabrowser_pkg_name${C_GREEN}) все же установлен."
            touch "$flag_bg_inst_is_done_val"
            return 0
        else
            log_msg "${P_ERROR} Яндекс.Браузер не установлен после завершения фонового процесса."
            return 1
        fi
    fi
}

# Функция: setup_hq_cli_m2_copy_localsettings_to_br_srv_pmt
# Назначение: Информирует о необходимости скопировать LocalSettings.php на BR_SRV.
setup_hq_cli_m2_copy_localsettings_to_br_srv_pmt() {
    log_msg "${P_ACTION} Копирование LocalSettings.php с HQ_CLI на BR_SRV..."
    
    local localsettings_pth_on_hq_cli_def_val="$m2_hq_cli_localsettings_download_pth_def"
    local localsettings_pth_on_hq_cli_val; ask_param "Полный путь к файлу LocalSettings.php на HQ_CLI" "$localsettings_pth_on_hq_cli_def_val" "localsettings_pth_on_hq_cli_val"

    if [[ ! -f "$localsettings_pth_on_hq_cli_val" ]]; then
        log_msg "${P_WARN} Файл '${C_YELLOW}$localsettings_pth_on_hq_cli_val${P_WARN}' не найден на HQ_CLI. Пропуск."
        return 0
    fi

    local br_srv_target_ip_val; br_srv_target_ip_val=$(get_ip_only "$m1_br_srv_lan_ip")
    local br_srv_target_ssh_port_val="$DEF_SSH_PORT"
    local br_srv_target_user_val="sshuser"
    local br_srv_target_pth_for_ls_val="$m2_br_srv_wiki_localsettings_pth_on_br_srv"

    log_msg "${P_INFO} Попытка скопировать файл '${C_CYAN}$localsettings_pth_on_hq_cli_val${C_RESET}'"
    log_msg "${P_INFO} на ${C_CYAN}${br_srv_target_user_val}@${br_srv_target_ip_val}:${br_srv_target_pth_for_ls_val}${C_RESET} (порт ${C_CYAN}$br_srv_target_ssh_port_val${C_RESET})."
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}Может потребоваться ввести пароль для пользователя '${C_CYAN}$br_srv_target_user_val${C_RESET}' на BR_SRV (пароль по умолчанию: ${C_YELLOW}$DEF_SSHUSER_PASS${C_YELLOW}).${C_RESET}"
    
    if scp -P "$br_srv_target_ssh_port_val" "$localsettings_pth_on_hq_cli_val" "${br_srv_target_user_val}@${br_srv_target_ip_val}:${br_srv_target_pth_for_ls_val}"; then
        log_msg "${P_OK} Файл LocalSettings.php успешно скопирован на BR_SRV."
        log_msg "${P_ACTION} ${C_BOLD_MAGENTA}Не забудьте перезапустить скрипт на BR_SRV (шаг 'Apply LocalSettings'), чтобы изменения вступили в силу!${C_RESET}"
        reg_sneaky_cmd "scp -P $br_srv_target_ssh_port_val $localsettings_pth_on_hq_cli_val ${br_srv_target_user_val}@${br_srv_target_ip_val}:${br_srv_target_pth_for_ls_val}"
        return 0
    else
        log_msg "${P_ERROR} Ошибка при копировании файла LocalSettings.php на BR_SRV."
        log_msg "${P_ERROR} Пожалуйста, скопируйте файл вручную и затем продолжите настройку на BR_SRV."
        return 1
    fi
}

# --- Мета-комментарий: Функции-шаги для HQ_CLI - Модуль 2 (Сценарий: default) ---