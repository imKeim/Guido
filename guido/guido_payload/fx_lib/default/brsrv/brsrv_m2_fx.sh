#!/bin/bash
# Файл: fx_lib/default/brsrv/brsrv_m2_fx.sh
# Содержит функции-шаги для роли BRSRV, Модуль 2, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для BRSRV - Модуль 2 (Сценарий: default) ---

# Функция: setup_brsrv_m2_ntp_cli
# Назначение: Настраивает BRSRV как NTP-клиента.
setup_brsrv_m2_ntp_cli() {
    log_msg "${P_ACTION} Настройка NTP-клиента (chrony) на BRSRV..."
    if ! ensure_pkgs "chronyc" "chrony"; then
        log_msg "${P_ERROR} Пакет chrony не установлен."
        return 1
    fi

    local ntp_srv_ip_def_val; ntp_srv_ip_def_val=$(get_ip_only "$m1_hqrtr_gre_tunnel_ip")
    local ntp_srv_ip_val; ask_val_param "IP-адрес NTP-сервера (IP HQRTR в GRE-туннеле)" "$ntp_srv_ip_def_val" "is_ipcidr_valid" "ntp_srv_ip_val"
    ntp_srv_ip_val=$(get_ip_only "$ntp_srv_ip_val")

    if ! cat <<EOF > /etc/chrony.conf
# Конфигурация NTP-клиента chrony для BRSRV
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

# Функция: setup_brsrv_m2_ssh_srv_port_update
# Назначение: Обновляет порт SSH-сервера на BRSRV.
setup_brsrv_m2_ssh_srv_port_update() {
    log_msg "${P_ACTION} Проверка и обновление порта SSH-сервера на BRSRV..."
    if ! command -v sshd &>/dev/null; then
        log_msg "${P_ERROR} Команда sshd не найдена. OpenSSH-server не установлен?"
        return 1
    fi

    local target_ssh_port_val; ask_val_param "Целевой порт SSH (должен совпадать с DNAT на BRRTR)" "$DEF_SSH_PORT" "is_port_valid" "target_ssh_port_val"
    local cur_ssh_port_val; cur_ssh_port_val=$(sshd -T 2>/dev/null | grep -i "^port " | awk '{print $2}' | head -n 1)

    if [[ -z "$cur_ssh_port_val" ]]; then
        log_msg "${P_WARN} Не удалось определить текущий порт SSH. Попытка установить порт ${C_CYAN}$target_ssh_port_val${C_RESET}."
    elif [[ "$cur_ssh_port_val" == "$target_ssh_port_val" ]]; then
        log_msg "${P_OK} SSH-сервер уже настроен на порт ${C_GREEN}$target_ssh_port_val${C_RESET}."
        return 0
    fi

    log_msg "${P_INFO} Изменение порта SSH на ${C_CYAN}$target_ssh_port_val${C_RESET} в /etc/openssh/sshd_config..."
    sed -i "s/^#*[[:space:]]*Port[[:space:]]\+.*/Port $target_ssh_port_val/" /etc/openssh/sshd_config
    if ! grep -q "^Port $target_ssh_port_val" /etc/openssh/sshd_config; then
        echo "Port $target_ssh_port_val" >> /etc/openssh/sshd_config
    fi
    reg_sneaky_cmd "sed -i 's/Port .*/Port $target_ssh_port_val/' /etc/openssh/sshd_config # (или добавлено)"

    log_msg "${P_INFO} Перезапуск sshd для применения нового порта..."
    if systemctl restart sshd && systemctl is-active --quiet sshd; then
        log_msg "${P_OK} Порт SSH-сервера успешно изменен на ${C_GREEN}$target_ssh_port_val${C_RESET}, служба перезапущена."
        reg_sneaky_cmd "systemctl restart sshd"
        return 0
    else
        log_msg "${P_ERROR} Не удалось перезапустить службу sshd после изменения порта."
        systemctl status sshd --no-pager -l
        return 1
    fi
}

# Функция: setup_brsrv_m2_samba_dc_inst_provision
# Назначение: Установка и начальная настройка Samba AD DC.
setup_brsrv_m2_samba_dc_inst_provision() {
    log_msg "${P_ACTION} Установка и начальная настройка Samba AD DC на BRSRV..."
    
    local samba_dc_req_pkgs_val="samba samba-client task-samba-dc bind-utils"
    local samba_dc_check_cmds_val="samba-tool kinit"
    if ! ensure_pkgs "$samba_dc_check_cmds_val" "$samba_dc_req_pkgs_val"; then
        log_msg "${P_ERROR} Не удалось установить все необходимые пакеты для Samba AD DC."
        return 1
    fi

    if rpm -q bind &>/dev/null || dpkg -s bind9 &>/dev/null; then
        log_msg "${P_INFO} Обнаружен пакет BIND. Попытка удаления для совместимости с Samba AD DC..."
        if apt-get remove -y bind bind9 --purge >/dev/null 2>&1 || yum remove -y bind bind-utils >/dev/null 2>&1; then
            log_msg "${P_OK} Пакет BIND (bind/bind9) успешно удален."
            reg_sneaky_cmd "apt-get remove -y bind bind9 --purge # или yum remove"
        else
            log_msg "${P_WARN} Не удалось автоматически удалить пакет BIND. Это может вызвать конфликты с Samba AD DC."
        fi
    fi

    if [ -f /etc/samba/smb.conf ]; then
        mv /etc/samba/smb.conf "/etc/samba/smb.conf.bak.$(date +%F_%T)"
        log_msg "${P_INFO} Существующий файл /etc/samba/smb.conf переименован в бэкап."
        reg_sneaky_cmd "mv /etc/samba/smb.conf /etc/samba/smb.conf.bak"
    fi

    local samba_realm_upper_val; ask_param "Kerberos Realm (например, AU-TEAM.IRPO)" "$m2_brsrv_samba_realm_upper" "samba_realm_upper_val"
    local samba_dom_netbios_val; ask_param "NetBIOS имя домена (например, AU-TEAM)" "$m2_brsrv_samba_domain_netbios" "samba_dom_netbios_val"
    local samba_admin_pass_val; ask_param "Пароль для администратора домена Samba AD ('administrator')" "$m2_brsrv_samba_admin_pass_def" "samba_admin_pass_val"
    local dns_fwd_def_val; dns_fwd_def_val=$(get_ip_only "$m1_hqsrv_lan_ip")
    local dns_fwd_val; ask_val_param "DNS-форвардер для Samba AD (IP-адрес HQSRV)" "$dns_fwd_def_val" "is_ipcidr_valid" "dns_fwd_val"
    dns_fwd_val=$(get_ip_only "$dns_fwd_val")

    if [ -f "/var/lib/samba/private/sam.ldb" ]; then
        log_msg "${P_INFO} База данных Samba AD (sam.ldb) уже существует. Пропуск 'samba-tool domain provision'."
    else
        log_msg "${P_INFO} Запуск 'samba-tool domain provision' для инициализации домена..."
        if samba-tool domain provision \
            --realm="$samba_realm_upper_val" \
            --domain="$samba_dom_netbios_val" \
            --server-role=dc \
            --dns-backend=SAMBA_INTERNAL \
            --use-rfc2307 \
            --adminpass="$samba_admin_pass_val" \
            --option="dns forwarder = $dns_fwd_val"; then
            log_msg "${P_OK} Команда 'samba-tool domain provision' успешно выполнена."
            reg_sneaky_cmd "samba-tool domain provision --realm=$samba_realm_upper_val --domain=$samba_dom_netbios_val --adminpass=*** ..."
        else
            log_msg "${P_ERROR} Ошибка выполнения 'samba-tool domain provision'. Проверьте вывод выше."
            return 1
        fi
    fi
    return 0
}

# Функция: setup_brsrv_m2_samba_dc_kerberos_dns_crontab
# Назначение: Настройка Kerberos, DNS-клиента и crontab для Samba AD DC.
setup_brsrv_m2_samba_dc_kerberos_dns_crontab() {
    log_msg "${P_ACTION} Настройка Kerberos, DNS-клиента и crontab для Samba AD DC..."
    
    local lan_iface_for_samba_dns_val="$m1_brsrv_lan_iface"
    local samba_realm_lower_val; samba_realm_lower_val=$(echo "$m2_brsrv_samba_realm_upper" | tr '[:upper:]' '[:lower:]')

    if \cp -f /var/lib/samba/private/krb5.conf /etc/krb5.conf; then
        log_msg "${P_OK} Файл /etc/krb5.conf скопирован из /var/lib/samba/private/krb5.conf."
        reg_sneaky_cmd "cp /var/lib/samba/private/krb5.conf /etc/krb5.conf"
    else
        log_msg "${P_ERROR} Не удалось скопировать /var/lib/samba/private/krb5.conf в /etc/krb5.conf."; return 1
    fi

    mkdir -p "/etc/net/ifaces/${lan_iface_for_samba_dns_val}"
    if ! cat <<EOF > "/etc/net/ifaces/${lan_iface_for_samba_dns_val}/resolv.conf"
search ${samba_realm_lower_val}
nameserver 127.0.0.1
EOF
    then
        log_msg "${P_ERROR} Ошибка создания resolv.conf для интерфейса ${C_BOLD_RED}${lan_iface_for_samba_dns_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Файл resolv.conf для ${C_CYAN}${lan_iface_for_samba_dns_val}${C_GREEN} настроен на использование localhost (127.0.0.1) как DNS."
    reg_sneaky_cmd "echo -e 'search ${samba_realm_lower_val}\nnameserver 127.0.0.1' > /etc/net/ifaces/${lan_iface_for_samba_dns_val}/resolv.conf"

    log_msg "${P_INFO} Обновление конфигурации DNS (resolvconf -u) и перезапуск сети..."
    if ! (resolvconf -u && systemctl restart network); then
        log_msg "${P_ERROR} Ошибка при обновлении DNS или перезапуске сетевой службы."; return 1
    fi
    log_msg "${P_OK} Системный DNS обновлен, сеть перезапущена. Ожидание 5 сек..."; sleep 5
    reg_sneaky_cmd "resolvconf -u; systemctl restart network"

    if systemctl unmask samba-ad-dc.service 2>/dev/null || systemctl unmask samba.service 2>/dev/null || true; then
        log_msg "${P_INFO} Попытка размаскировать службу samba/samba-ad-dc выполнена."
    fi
    local samba_srv_name_val="samba-ad-dc"
    if ! systemctl list-unit-files | grep -q "^${samba_srv_name_val}.service"; then
        samba_srv_name_val="samba"
    fi

    if systemctl enable --now "$samba_srv_name_val" && systemctl is-active --quiet "$samba_srv_name_val"; then
        log_msg "${P_OK} Служба Samba AD DC (${C_CYAN}$samba_srv_name_val${C_GREEN}) включена и активна."
        reg_sneaky_cmd "systemctl enable --now $samba_srv_name_val"
    else
        log_msg "${P_ERROR} Не удалось запустить службу Samba AD DC (${C_BOLD_RED}$samba_srv_name_val${P_ERROR})."
        systemctl status "$samba_srv_name_val" --no-pager -l
        return 1
    fi

    local cron_restart_net_cmd_val="@reboot sleep 45 ; /bin/systemctl restart network"
    local cron_restart_samba_cmd_val="@reboot sleep 60 ; /bin/systemctl restart ${samba_srv_name_val}"
    (crontab -l 2>/dev/null | grep -v -F "$cron_restart_net_cmd_val" | grep -v -F "$cron_restart_samba_cmd_val"; echo "$cron_restart_net_cmd_val"; echo "$cron_restart_samba_cmd_val") | crontab -
    log_msg "${P_OK} Задачи для отложенного перезапуска network и ${C_CYAN}$samba_srv_name_val${C_GREEN} добавлены в crontab."
    reg_sneaky_cmd "crontab -l | { cat; echo '$cron_restart_net_cmd_val'; echo '$cron_restart_samba_cmd_val'; } | crontab -"
    
    return 0
}

# Функция: setup_brsrv_m2_samba_dc_create_users_groups
# Назначение: Создает тестовых пользователей и группу 'hq' в Samba AD.
setup_brsrv_m2_samba_dc_create_users_groups() {
    log_msg "${P_ACTION} Создание тестовых пользователей и групп в Samba AD на BRSRV..."
    
    local samba_admin_pass_val; ask_param "Пароль администратора домена Samba AD (для kinit)" "$m2_brsrv_samba_admin_pass_def" "samba_admin_pass_val"
    local user_hq_pass_val; ask_param "Пароль для создаваемых пользователей userX.hq" "$m2_brsrv_samba_user_hq_pass_def" "user_hq_pass_val"
    local samba_realm_upper_kinit_val="$m2_brsrv_samba_realm_upper"

    log_msg "${P_INFO} Попытка получения Kerberos-тикета для administrator@${samba_realm_upper_kinit_val}..."
    if echo "$samba_admin_pass_val" | kinit "administrator@${samba_realm_upper_kinit_val}" &>/dev/null; then
        log_msg "${P_OK} kinit для администратора успешно выполнен."
        reg_sneaky_cmd "echo '***' | kinit administrator@${samba_realm_upper_kinit_val}"
    else
        log_msg "${P_WARN} kinit для администратора не удался. Создание пользователей может не сработать."
    fi

    for i in {1..5}; do
        local cur_username_val="user${i}.hq"
        if samba-tool user list | grep -q "^${cur_username_val}$"; then
            log_msg "${P_INFO} Пользователь ${C_CYAN}$cur_username_val${C_RESET} уже существует."
        else
            log_msg "${P_INFO} Создание пользователя ${C_CYAN}$cur_username_val${C_RESET}..."
            if samba-tool user create "$cur_username_val" "$user_hq_pass_val" --given-name="User" --surname="${i}HQ"; then
                log_msg "${P_OK} Пользователь ${C_GREEN}$cur_username_val${C_RESET} успешно создан."
                reg_sneaky_cmd "samba-tool user create $cur_username_val *** --given-name=User --surname=${i}HQ"
            else
                log_msg "${P_ERROR} Ошибка при создании пользователя ${C_BOLD_RED}$cur_username_val${P_ERROR}."
            fi
        fi
    done

    local group_name_to_create_val="hq"
    if samba-tool group list | grep -q "^${group_name_to_create_val}$"; then
        log_msg "${P_INFO} Группа ${C_CYAN}$group_name_to_create_val${C_RESET} уже существует."
    else
        log_msg "${P_INFO} Создание группы ${C_CYAN}$group_name_to_create_val${C_RESET}..."
        if samba-tool group add "$group_name_to_create_val"; then
            log_msg "${P_OK} Группа ${C_GREEN}$group_name_to_create_val${C_RESET} успешно создана."
            reg_sneaky_cmd "samba-tool group add $group_name_to_create_val"
        else
            log_msg "${P_ERROR} Ошибка при создании группы ${C_BOLD_RED}$group_name_to_create_val${P_ERROR}."
            return 1
        fi
    fi

    local users_to_add_to_group_val="user1.hq,user2.hq,user3.hq,user4.hq,user5.hq"
    log_msg "${P_INFO} Добавление пользователей (${C_CYAN}$users_to_add_to_group_val${C_RESET}) в группу ${C_CYAN}$group_name_to_create_val${C_RESET}..."
    if samba-tool group addmembers "$group_name_to_create_val" "$users_to_add_to_group_val"; then
        log_msg "${P_OK} Пользователи успешно добавлены в группу ${C_GREEN}$group_name_to_create_val${C_RESET}."
        reg_sneaky_cmd "samba-tool group addmembers $group_name_to_create_val $users_to_add_to_group_val"
    else
        log_msg "${P_WARN} Ошибка при добавлении пользователей в группу ${C_BOLD_YELLOW}$group_name_to_create_val${P_WARN}."
    fi
    
    kdestroy -A &>/dev/null
    return 0
}

# Функция: setup_brsrv_m2_samba_dc_import_users_csv
# Назначение: Импортирует пользователей в Samba AD из CSV-файла.
setup_brsrv_m2_samba_dc_import_users_csv() {
    log_msg "${P_ACTION} Импорт пользователей из CSV-файла в Samba AD на BRSRV..."
    
    local csv_def_pass_val; ask_param "Пароль по умолчанию для пользователей из CSV" "$m2_brsrv_samba_csv_user_pass_def" "csv_def_pass_val"
    local csv_file_pth_val; ask_param "Полный путь к CSV-файлу с пользователями" "/opt/users.csv" "csv_file_pth_val"

    if [[ ! -f "$csv_file_pth_val" ]]; then
        log_msg "${P_WARN} Файл ${C_YELLOW}$csv_file_pth_val${P_WARN} не найден. Пропуск импорта пользователей из CSV."
        return 0
    fi
    
    if import_samba_csv_users "$csv_def_pass_val" "$csv_file_pth_val"; then
        log_msg "${P_OK} Импорт пользователей из CSV-файла (${C_CYAN}$csv_file_pth_val${C_GREEN}) завершен успешно."
        reg_sneaky_cmd "import_samba_csv_users *** $csv_file_pth_val # (вызов внутренней функции)"
        return 0
    else
        log_msg "${P_ERROR} Во время импорта пользователей из CSV-файла (${C_BOLD_RED}$csv_file_pth_val${P_ERROR}) возникли ошибки."
        return 1
    fi
}

# Функция: setup_brsrv_m2_ansible_inst_ssh_key_gen
# Назначение: Устанавливает Ansible и генерирует SSH-ключ.
setup_brsrv_m2_ansible_inst_ssh_key_gen() {
    log_msg "${P_ACTION} Установка Ansible и генерация SSH-ключа на BRSRV..."
    if ! ensure_pkgs "ansible ssh-keygen" "ansible openssh-clients"; then
        log_msg "${P_ERROR} Не удалось установить Ansible и/или openssh-clients."
        return 1
    fi

    local ssh_key_pth_val="$m2_brsrv_ansible_ssh_key_pth"
    
    if [[ -f "$ssh_key_pth_val" ]]; then
        log_msg "${P_INFO} SSH-ключ (${C_CYAN}$ssh_key_pth_val${C_RESET}) для Ansible уже существует."
    else
        log_msg "${P_INFO} SSH-ключ для Ansible (${C_CYAN}$ssh_key_pth_val${C_RESET}) не найден. Генерация нового ключа..."
        if ssh-keygen -t rsa -b 4096 -f "$ssh_key_pth_val" -N ""; then
            log_msg "${P_OK} SSH-ключ (${C_GREEN}$ssh_key_pth_val${C_RESET}) успешно сгенерирован."
            reg_sneaky_cmd "ssh-keygen -t rsa -f $ssh_key_pth_val -N ''"
        else
            log_msg "${P_ERROR} Ошибка при генерации SSH-ключа (${C_BOLD_RED}$ssh_key_pth_val${P_ERROR})."; return 1
        fi
    fi
    return 0
}

# Функция: setup_brsrv_m2_ansible_ssh_copy_id_pmt
# Назначение: Информирует о необходимости скопировать SSH-ключ Ansible.
setup_brsrv_m2_ansible_ssh_copy_id_pmt() {
    local vm_role_code="BRSRV"; local mod_num_val="2"
    local flag_manual_ssh_copy_pending_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${FUNCNAME[0]}_pending_manual.flag"
    
    local ssh_pub_key_pth_val="${m2_brsrv_ansible_ssh_key_pth}.pub"
    
    local hqsrv_target_ip_val; hqsrv_target_ip_val=$(get_ip_only "$m1_hqsrv_lan_ip")
    local hqsrv_target_ssh_port_val="$DEF_SSH_PORT"
    local hqcli_target_ip_val; hqcli_target_ip_val=$(get_ip_only "$m1_hqcli_dhcp_reserved_ip_def")
    local hqrtr_target_wan_ip_val; hqrtr_target_wan_ip_val=$(get_ip_only "$m1_hqrtr_wan_ip")
    local brrtr_target_wan_ip_val; brrtr_target_wan_ip_val=$(get_ip_only "$m1_brrtr_wan_ip")

    log_msg "${P_ACTION} ${C_BOLD_MAGENTA}ТРЕБУЕТСЯ РУЧНОЕ ДЕЙСТВИЕ: Копирование публичного SSH-ключа Ansible${C_RESET}"
    log_msg "${P_ACTION}   Публичный ключ: ${C_CYAN}$ssh_pub_key_pth_val${C_RESET}"
    log_msg "${P_ACTION}   Используйте команду: ${C_CYAN}ssh-copy-id -i ${ssh_pub_key_pth_val} [опции_порта] пользователь@хост${C_RESET}"
    log_msg "${P_ACTION}   ${C_BOLD_YELLOW}Целевые хосты и пользователи:${C_RESET}"
    log_msg "${P_ACTION}     1. HQSRV: ${C_CYAN}${m2_brsrv_ansible_hqsrv_user}@${hqsrv_target_ip_val} -p ${hqsrv_target_ssh_port_val}${C_RESET} (Пароль: ${C_YELLOW}$DEF_SSHUSER_PASS${C_RESET})"
    log_msg "${P_ACTION}     2. HQCLI: ${C_CYAN}${m2_brsrv_ansible_hqcli_user}@${hqcli_target_ip_val}${C_RESET} (Пароль: ${C_YELLOW}$m2_brsrv_ansible_hqcli_pass_def${C_RESET}) ${C_DIM}(SSH на HQCLI должен быть включен, и HQCLI должен быть в домене)${C_RESET}"
    log_msg "${P_ACTION}     3. HQRTR: ${C_CYAN}${m2_brsrv_ansible_rtr_user}@${hqrtr_target_wan_ip_val}${C_RESET} (Пароль: ${C_YELLOW}$DEF_NET_ADMIN_PASS${C_RESET})"
    log_msg "${P_ACTION}     4. BRRTR: ${C_CYAN}${m2_brsrv_ansible_rtr_user}@${brrtr_target_wan_ip_val}${C_RESET} (Пароль: ${C_YELLOW}$DEF_NET_ADMIN_PASS${C_RESET})"
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}После успешного копирования ключа на ВСЕ указанные хосты, вернитесь в этот терминал и продолжите выполнение скрипта.${C_RESET}"
    
    touch "$flag_manual_ssh_copy_pending_val"
    return 2
}

# Функция: setup_brsrv_m2_ansible_cfg_files
# Назначение: Создает конфигурационные файлы Ansible и проверяет доступность хостов.
setup_brsrv_m2_ansible_cfg_files() {
    local vm_role_code="BRSRV"; local mod_num_val="2"
    local flag_manual_ssh_copy_pending_prev_step_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_setup_brsrv_m2_ansible_ssh_copy_id_pmt_pending_manual.flag"
    if [[ ! -f "$flag_manual_ssh_copy_pending_prev_step_val" ]]; then
        log_msg "${P_WARN} Предыдущий шаг (копирование SSH-ключей Ansible) не был отмечен как ожидающий. Убедитесь, что ключи скопированы."
    fi

    log_msg "${P_ACTION} Создание конфигурационных файлов Ansible на BRSRV..."
    
    local hqsrv_ansible_ip_val; hqsrv_ansible_ip_val=$(get_ip_only "$m1_hqsrv_lan_ip")
    local hqsrv_ansible_ssh_port_val="$DEF_SSH_PORT"
    local hqcli_ansible_ip_val; hqcli_ansible_ip_val=$(get_ip_only "$m1_hqcli_dhcp_reserved_ip_def")
    local hqrtr_ansible_wan_ip_val; hqrtr_ansible_wan_ip_val=$(get_ip_only "$m1_hqrtr_wan_ip")
    local brrtr_ansible_wan_ip_val; brrtr_ansible_wan_ip_val=$(get_ip_only "$m1_brrtr_wan_ip")
    local brsrv_ansible_self_ip_val; brsrv_ansible_self_ip_val=$(get_ip_only "$m1_brsrv_lan_ip")
    local brsrv_ansible_self_ssh_port_val="$DEF_SSH_PORT"

    mkdir -p /etc/ansible
    
    if ! cat <<EOF > /etc/ansible/hosts
[hq]
${hqsrv_ansible_ip_val} ansible_user=${m2_brsrv_ansible_hqsrv_user} ansible_port=${hqsrv_ansible_ssh_port_val}
${hqcli_ansible_ip_val} ansible_user=${m2_brsrv_ansible_hqcli_user}
${hqrtr_ansible_wan_ip_val} ansible_user=${m2_brsrv_ansible_rtr_user}

[br]
${brrtr_ansible_wan_ip_val} ansible_user=${m2_brsrv_ansible_rtr_user}
${brsrv_ansible_self_ip_val} ansible_user=${m2_brsrv_ansible_hqsrv_user} ansible_port=${brsrv_ansible_self_ssh_port_val} ansible_connection=local
EOF
    then
        log_msg "${P_ERROR} Ошибка записи в /etc/ansible/hosts."; return 1
    fi
    log_msg "${P_OK} Инвентарный файл /etc/ansible/hosts успешно создан."
    reg_sneaky_cmd "cat /etc/ansible/hosts # (содержимое выше)"

    if ! cat <<EOF > /etc/ansible/ansible.cfg
[defaults]
inventory      = /etc/ansible/hosts
host_key_checking = False
interpreter_python = auto_silent
deprecation_warnings = False
EOF
    then
        log_msg "${P_ERROR} Ошибка записи в /etc/ansible/ansible.cfg."; return 1
    fi
    log_msg "${P_OK} Конфигурационный файл /etc/ansible/ansible.cfg успешно создан."
    reg_sneaky_cmd "cat /etc/ansible/ansible.cfg # (содержимое выше)"

    log_msg "${P_INFO} Проверка доступности всех хостов через Ansible ('ansible all -m ping')..."
    if ansible all -m ping; then
        log_msg "${P_OK} Команда 'ansible all -m ping' успешно выполнена для всех хостов."
        reg_sneaky_cmd "ansible all -m ping"
        if [[ -f "$flag_manual_ssh_copy_pending_prev_step_val" ]]; then
            rm -f "$flag_manual_ssh_copy_pending_prev_step_val"
            log_msg "${P_INFO} Флаг ожидания копирования SSH-ключей Ansible удален."
        fi
        return 0
    else
        log_msg "${P_ERROR} Команда 'ansible all -m ping' не удалась для одного или нескольких хостов."
        log_msg "${P_ERROR} Убедитесь, что SSH-ключи были корректно скопированы на все целевые машины и SSH-доступ настроен."
        return 1
    fi
}

# Функция: setup_brsrv_m2_docker_mediawiki_inst_p1_compose_up
# Назначение: Установка Docker, Docker Compose и запуск MediaWiki (Часть 1).
setup_brsrv_m2_docker_mediawiki_inst_p1_compose_up() {
    log_msg "${P_ACTION} Установка Docker, Docker Compose и запуск MediaWiki (Часть 1) на BRSRV..."
    if ! ensure_pkgs "docker docker-compose" "docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose"; then
        log_msg "${P_ERROR} Не удалось установить Docker и/или Docker Compose."
        return 1
    fi

    local docker_compose_cmd_val; docker_compose_cmd_val=$(get_docker_compose_cmd)
    if [[ -z "$docker_compose_cmd_val" ]]; then
        log_msg "${P_ERROR} Команда docker-compose не найдена после установки пакетов."; return 1
    fi
    log_msg "${P_INFO} Будет использована команда: ${C_CYAN}$docker_compose_cmd_val${C_RESET}"

    if systemctl enable --now docker && systemctl is-active --quiet docker; then
        log_msg "${P_OK} Служба Docker включена и активна."
        reg_sneaky_cmd "systemctl enable --now docker"
    else
        log_msg "${P_ERROR} Не удалось запустить службу Docker."
        systemctl status docker --no-pager -l
        return 1
    fi

    local wiki_db_vol_name_val="$m2_brsrv_docker_wiki_dbvolume_name"
    local wiki_img_vol_name_val="$m2_brsrv_docker_wiki_imagesvolume_name"
    docker volume inspect "$wiki_db_vol_name_val" &>/dev/null || (docker volume create "$wiki_db_vol_name_val" && log_msg "${P_OK} Docker volume ${C_GREEN}$wiki_db_vol_name_val${C_RESET} создан.")
    docker volume inspect "$wiki_img_vol_name_val" &>/dev/null || (docker volume create "$wiki_img_vol_name_val" && log_msg "${P_OK} Docker volume ${C_GREEN}$wiki_img_vol_name_val${C_RESET} создан.")
    reg_sneaky_cmd "docker volume create $wiki_db_vol_name_val"
    reg_sneaky_cmd "docker volume create $wiki_img_vol_name_val"

    local wiki_db_pass_val; ask_param "Пароль для пользователя БД MediaWiki ('${m2_brsrv_wiki_db_user}')" "$m2_brsrv_wiki_db_pass_def" "wiki_db_pass_val"
    local wiki_ext_port_on_brsrv_def_val="$m2_nginx_wiki_backend_port_def"
    local wiki_ext_port_on_brsrv_val; ask_val_param "Порт на BRSRV для доступа к MediaWiki" "$wiki_ext_port_on_brsrv_def_val" "is_port_valid" "wiki_ext_port_on_brsrv_val"
    
    local docker_compose_pth_val="$m2_brsrv_docker_compose_pth"
    mkdir -p "$(dirname "$docker_compose_pth_val")" && chown sshuser:sshuser "$(dirname "$docker_compose_pth_val")"

    if ! cat << EOF > "$docker_compose_pth_val"
version: '3.7'
services:
  mediawiki:
    container_name: wiki
    image: mediawiki:lts
    restart: always
    ports:
      - "${wiki_ext_port_on_brsrv_val}:80"
    links:
      - mariadb:mariadb
    volumes:
      - ${wiki_img_vol_name_val}:/var/www/html/images
      # - ./LocalSettings.php:/var/www/html/LocalSettings.php 
    depends_on:
      - mariadb
  mariadb:
    container_name: mariadb_wiki
    image: mariadb:latest
    restart: always
    environment:
      MYSQL_DATABASE: mediawiki
      MYSQL_USER: ${m2_brsrv_wiki_db_user}
      MYSQL_PASSWORD: ${wiki_db_pass_val}
      MYSQL_RANDOM_ROOT_PASSWORD: 'yes'
    volumes:
      - ${wiki_db_vol_name_val}:/var/lib/mysql
volumes:
  ${wiki_img_vol_name_val}: {}
  ${wiki_db_vol_name_val}:
    external: true
EOF
    then
        log_msg "${P_ERROR} Ошибка записи в файл docker-compose: ${C_BOLD_RED}$docker_compose_pth_val${P_ERROR}."; return 1
    fi
    chown sshuser:sshuser "$docker_compose_pth_val"
    log_msg "${P_OK} Файл Docker Compose (${C_CYAN}$docker_compose_pth_val${C_GREEN}) успешно создан."
    reg_sneaky_cmd "cat $docker_compose_pth_val # (содержимое выше)"

    log_msg "${P_INFO} Запуск контейнеров MediaWiki и MariaDB с помощью '${C_CYAN}$docker_compose_cmd_val -f $docker_compose_pth_val up -d${C_RESET}'..."
    if eval "$docker_compose_cmd_val -f \"$docker_compose_pth_val\" up -d"; then
        log_msg "${P_OK} Контейнеры MediaWiki и MariaDB успешно запущены в фоновом режиме."
        reg_sneaky_cmd "$docker_compose_cmd_val -f $docker_compose_pth_val up -d"
        return 0
    else
        log_msg "${P_ERROR} Ошибка при запуске контейнеров MediaWiki/MariaDB с помощью docker-compose."
        eval "$docker_compose_cmd_val -f \"$docker_compose_pth_val\" logs" | log_msg - "/dev/tty"
        return 1
    fi
}

# Функция: setup_brsrv_m2_docker_mediawiki_inst_p2_web_setup_pmt
# Назначение: Информирует о необходимости веб-установки MediaWiki.
setup_brsrv_m2_docker_mediawiki_inst_p2_web_setup_pmt() {
    local vm_role_code="BRSRV"; local mod_num_val="2"
    local flag_manual_web_wiki_pending_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${FUNCNAME[0]}_pending_manual.flag"
    
    local brsrv_lan_ip_for_url_val; brsrv_lan_ip_for_url_val=$(get_ip_only "$m1_brsrv_lan_ip")
    local wiki_ext_port_on_brsrv_val; ask_val_param "Порт MediaWiki на BRSRV (для URL веб-установки)" "$m2_nginx_wiki_backend_port_def" "is_port_valid" "wiki_ext_port_on_brsrv_val"
    local wiki_db_pass_pmt_val; ask_param "Пароль пользователя БД MediaWiki ('${m2_brsrv_wiki_db_user}') (тот же, что и на шаге 1)" "$m2_brsrv_wiki_db_pass_def" "wiki_db_pass_pmt_val"

    log_msg "${P_ACTION} ${C_BOLD_MAGENTA}ТРЕБУЕТСЯ РУЧНОЕ ДЕЙСТВИЕ: Веб-установка MediaWiki${C_RESET}"
    log_msg "${P_ACTION}   URL для доступа: ${C_CYAN}http://${brsrv_lan_ip_for_url_val}:${wiki_ext_port_on_brsrv_val}/${C_RESET}"
    log_msg "${P_ACTION}   ${C_DIM}(Убедитесь, что DNAT на BRRTR настроен на этот IP и порт BRSRV)${C_RESET}"
    log_msg "${P_ACTION}   ${C_BOLD_YELLOW}Основные параметры для веб-установки:${C_RESET}"
    log_msg "${P_ACTION}     - Хост базы данных: ${C_YELLOW}mariadb_wiki${C_RESET}"
    log_msg "${P_ACTION}     - Имя базы данных: ${C_YELLOW}mediawiki${C_RESET}"
    log_msg "${P_ACTION}     - Пользователь базы данных: ${C_YELLOW}${m2_brsrv_wiki_db_user}${C_RESET}"
    log_msg "${P_ACTION}     - Пароль пользователя базы данных: ${C_YELLOW}${wiki_db_pass_pmt_val}${C_RESET}"
    log_msg "${P_ACTION}     - Название Вики: ${C_YELLOW}${m2_wiki_site_name}${C_RESET}"
    log_msg "${P_ACTION}     - Имя администратора: ${C_YELLOW}${m2_wiki_admin_user}${C_RESET}, Пароль: (например, ${C_YELLOW}WikiP@ssword${C_RESET})"
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}ДЕЙСТВИЯ ПОЛЬЗОВАТЕЛЯ:${C_RESET}"
    log_msg "${P_ACTION}   1. ${C_GREEN}Завершите${C_RESET} процесс веб-установки MediaWiki в браузере."
    log_msg "${P_ACTION}   2. В конце установки MediaWiki предложит ${C_GREEN}скачать файл 'LocalSettings.php'${C_RESET}. Скачайте его."
    log_msg "${P_ACTION}   3. ${C_GREEN}Скопируйте${C_RESET} этот скачанный файл 'LocalSettings.php' на сервер ${C_BOLD_MAGENTA}BRSRV${C_RESET}"
    log_msg "${P_ACTION}      в директорию: ${C_CYAN}${m2_brsrv_wiki_localsettings_pth_on_brsrv%/*}/${C_RESET}"
    log_msg "${P_ACTION}      Под именем: ${C_CYAN}$(basename "$m2_brsrv_wiki_localsettings_pth_on_brsrv")${C_RESET}"
    log_msg "${P_ACTION}   4. ${C_GREEN}Вернитесь${C_RESET} в этот терминал и продолжите выполнение скрипта."
    
    touch "$flag_manual_web_wiki_pending_val"
    return 2
}

# Функция: setup_brsrv_m2_docker_mediawiki_inst_p3_apply_localsettings
# Назначение: Применяет LocalSettings.php к MediaWiki.
setup_brsrv_m2_docker_mediawiki_inst_p3_apply_localsettings() {
    local vm_role_code="BRSRV"; local mod_num_val="2"
    local flag_manual_web_wiki_pending_prev_step_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_setup_brsrv_m2_docker_mediawiki_inst_p2_web_setup_pmt_pending_manual.flag"
    
    log_msg "${P_ACTION} Применение LocalSettings.php для MediaWiki (Часть 3) на BRSRV..."
    
    local localsettings_target_pth_val="$m2_brsrv_wiki_localsettings_pth_on_brsrv"
    local docker_compose_pth_val="$m2_brsrv_docker_compose_pth"
    local docker_compose_cmd_val; docker_compose_cmd_val=$(get_docker_compose_cmd)

    if [[ ! -f "$localsettings_target_pth_val" ]]; then
        log_msg "${P_ERROR} Файл LocalSettings.php (${C_BOLD_RED}$localsettings_target_pth_val${P_ERROR}) не найден."
        return 1
    fi
    if [[ -z "$docker_compose_cmd_val" ]]; then
        log_msg "${P_ERROR} Команда docker-compose не найдена."; return 1
    fi

    if grep -q '^[[:space:]]*#[[:space:]]*- .*LocalSettings\.php:/var/www/html/LocalSettings\.php' "$docker_compose_pth_val"; then
        sed -i 's|^[[:space:]]*#[[:space:]]*- \(.*LocalSettings\.php:/var/www/html/LocalSettings\.php\)|\ \ \ \ \ \- \1|' "$docker_compose_pth_val"
        log_msg "${P_OK} Строка монтирования LocalSettings.php раскомментирована в ${C_CYAN}$docker_compose_pth_val${C_RESET}."
        reg_sneaky_cmd "sed -i 's/# - \.\/LocalSettings.php/.../' $docker_compose_pth_val"
    elif grep -q '^[[:space:]]*- .*LocalSettings\.php:/var/www/html/LocalSettings\.php' "$docker_compose_pth_val"; then
        log_msg "${P_INFO} Строка монтирования LocalSettings.php уже раскомментирована в ${C_CYAN}$docker_compose_pth_val${C_RESET}."
    else
        log_msg "${P_WARN} Не удалось найти строку для раскомментирования LocalSettings.php в ${C_YELLOW}$docker_compose_pth_val${P_WARN}."
    fi
    
    local compose_dir_val; compose_dir_val=$(dirname "$docker_compose_pth_val")
    if [[ "$compose_dir_val" != "$(dirname "$localsettings_target_pth_val")" ]]; then
        log_msg "${P_INFO} Копирование ${C_CYAN}$localsettings_target_pth_val${C_RESET} в ${C_CYAN}${compose_dir_val}/LocalSettings.php${C_RESET}..."
        if cp "$localsettings_target_pth_val" "${compose_dir_val}/LocalSettings.php"; then
            chown sshuser:sshuser "${compose_dir_val}/LocalSettings.php"
            log_msg "${P_OK} LocalSettings.php скопирован в директорию docker-compose."
            reg_sneaky_cmd "cp $localsettings_target_pth_val ${compose_dir_val}/LocalSettings.php"
        else
            log_msg "${P_ERROR} Не удалось скопировать LocalSettings.php в ${C_BOLD_RED}${compose_dir_val}${P_ERROR}."; return 1
        fi
    fi

    log_msg "${P_INFO} Перезапуск контейнеров MediaWiki для применения LocalSettings.php..."
    if eval "$docker_compose_cmd_val -f \"$docker_compose_pth_val\" stop" && \
       eval "$docker_compose_cmd_val -f \"$docker_compose_pth_val\" up -d"; then
        log_msg "${P_OK} Контейнеры MediaWiki успешно перезапущены."
        reg_sneaky_cmd "$docker_compose_cmd_val -f $docker_compose_pth_val stop && $docker_compose_cmd_val -f $docker_compose_pth_val up -d"
        if [[ -f "$flag_manual_web_wiki_pending_prev_step_val" ]]; then
            rm -f "$flag_manual_web_wiki_pending_prev_step_val"
            log_msg "${P_INFO} Флаг ожидания ручной веб-установки MediaWiki удален."
        fi
        return 0
    else
        log_msg "${P_ERROR} Ошибка при перезапуске контейнеров MediaWiki."
        eval "$docker_compose_cmd_val -f \"$docker_compose_pth_val\" logs" | log_msg - "/dev/tty"
        return 1
    fi
}

# --- Мета-комментарий: Конец функций-шагов для BRSRV - Модуль 1 (Сценарий: default) ---