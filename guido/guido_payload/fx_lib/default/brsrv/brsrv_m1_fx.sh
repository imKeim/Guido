#!/bin/bash
# Файл: fx_lib/default/brsrv/brsrv_m1_fx.sh
# Содержит функции-шаги для роли BRSRV, Модуль 1, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для BRSRV - Модуль 1 (Сценарий: default) ---

# Функция: setup_brsrv_m1_hn
# Назначение: Устанавливает имя хоста (FQDN) для ВМ BRSRV.
setup_brsrv_m1_hn() {
    local def_fqdn_val="${EXPECTED_FQDNS["brsrv"]}"
    local target_fqdn_val
    ask_param "FQDN для BRSRV" "$def_fqdn_val" "target_fqdn_val"

    log_msg "${P_ACTION} Установка имени хоста на: ${C_CYAN}$target_fqdn_val${C_RESET}..."
    if hostnamectl set-hostname "$target_fqdn_val"; then
        log_msg "${P_OK} Имя хоста успешно установлено: ${C_GREEN}$target_fqdn_val${C_RESET}"
        log_msg "${P_INFO} ${C_DIM}Для немедленного отображения: exec bash${C_RESET}"
        reg_sneaky_cmd "hostnamectl set-hostname $target_fqdn_val"
        return 0
    else
        log_msg "${P_ERROR} Не удалось установить имя хоста ${C_BOLD_RED}$target_fqdn_val${P_ERROR}."
        return 1
    fi
}

# Функция: setup_brsrv_m1_net_iface
# Назначение: Настраивает LAN-интерфейс для ВМ BRSRV.
setup_brsrv_m1_net_iface() {
    local lan_iface_val; ask_param "LAN интерфейс BRSRV" "$m1_brsrv_lan_iface" "lan_iface_val"
    local lan_ip_val; ask_val_param "IP-адрес LAN BRSRV (CIDR)" "$m1_brsrv_lan_ip" "is_ipcidr_valid" "lan_ip_val"
    local lan_gw_val; ask_val_param "Шлюз LAN BRSRV" "$m1_brsrv_lan_gw" "is_ipcidr_valid" "lan_gw_val"

    log_msg "${P_ACTION} Настройка LAN интерфейса BRSRV..."
    mkdir -p "/etc/net/ifaces/${lan_iface_val}" && find "/etc/net/ifaces/${lan_iface_val}" -mindepth 1 -delete
    if ! {
        echo 'TYPE=eth' > "/etc/net/ifaces/${lan_iface_val}/options" &&
        echo "$lan_ip_val" > "/etc/net/ifaces/${lan_iface_val}/ipv4address" &&
        echo "default via $(get_ip_only "$lan_gw_val")" > "/etc/net/ifaces/${lan_iface_val}/ipv4route";
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для интерфейса ${C_BOLD_RED}${lan_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${lan_iface_val}${C_GREEN} (IP: $lan_ip_val, GW: $lan_gw_val) настроен."
    reg_sneaky_cmd "echo 'TYPE=eth' > /etc/net/ifaces/${lan_iface_val}/options"
    reg_sneaky_cmd "echo '$lan_ip_val' > /etc/net/ifaces/${lan_iface_val}/ipv4address"
    reg_sneaky_cmd "echo 'default via $(get_ip_only "$lan_gw_val")' > /etc/net/ifaces/${lan_iface_val}/ipv4route"
    
    return 0
}

# Функция: setup_brsrv_m1_net_restart_base_ip
setup_brsrv_m1_net_restart_base_ip() {
    log_msg "${P_ACTION} Перезапуск сетевой службы для применения настроек IP..."
    if systemctl restart network; then
        log_msg "${P_OK} Сетевая служба успешно перезапущена."
        log_msg "${P_INFO} ${C_DIM}Ожидание 5 секунд для стабилизации сети...${C_RESET}"
        sleep 5
        reg_sneaky_cmd "systemctl restart network"
        return 0
    else
        log_msg "${P_ERROR} Не удалось перезапустить сетевую службу."
        return 1
    fi
}

# Функция: setup_brsrv_m1_user_sshuser
setup_brsrv_m1_user_sshuser() {
    local username_val="sshuser"
    local target_uid_val; ask_val_param "UID для пользователя '${username_val}'" "$DEF_SSHUSER_UID" "is_uid_valid" "target_uid_val"
    local target_pass_val; ask_param "Пароль для пользователя '${username_val}'" "$DEF_SSHUSER_PASS" "target_pass_val"
    
    local sudoers_entry_val="${username_val} ALL=(ALL) NOPASSWD: ALL"

    log_msg "${P_ACTION} Настройка пользователя '${C_CYAN}${username_val}${C_RESET}'..."
    if id -u "$username_val" &>/dev/null; then
        log_msg "${P_INFO} Пользователь '${C_CYAN}${username_val}${C_RESET}' уже существует. Обновление..."
        echo "${username_val}:${target_pass_val}" | chpasswd
        usermod -aG wheel "$username_val"
        reg_sneaky_cmd "echo \"${username_val}:***\" | chpasswd # Пароль обновлен"
    else
        useradd "$username_val" -u "$target_uid_val" -U -m -s /bin/bash
        if [[ $? -ne 0 ]]; then log_msg "${P_ERROR} Не удалось создать пользователя '$username_val'."; return 1; fi
        echo "${username_val}:${target_pass_val}" | chpasswd
        usermod -aG wheel "$username_val"
        log_msg "${P_OK} Пользователь '${C_GREEN}${username_val}${C_RESET}' успешно создан."
        reg_sneaky_cmd "useradd $username_val -u $target_uid_val -U -m -s /bin/bash"
        reg_sneaky_cmd "echo \"${username_val}:***\" | chpasswd"
    fi

    if ! grep -qF "$sudoers_entry_val" /etc/sudoers; then
        echo -e "\n${sudoers_entry_val}" >> /etc/sudoers
        log_msg "${P_OK} Права sudo для '${C_GREEN}${username_val}${C_RESET}' настроены."
        reg_sneaky_cmd "echo '$sudoers_entry_val' >> /etc/sudoers"
    else
        log_msg "${P_INFO} Права sudo для '${C_CYAN}${username_val}${C_RESET}' уже настроены."
    fi
    return 0
}

# Функция: setup_brsrv_m1_ssh_srv
setup_brsrv_m1_ssh_srv() {
    log_msg "${P_ACTION} Настройка SSH-сервера на BRSRV..."
    if ! ensure_pkgs "sshd" "openssh-server"; then
        log_msg "${P_ERROR} Пакет openssh-server не установлен."
        return 1
    fi

    local ssh_port_val; ask_val_param "Порт для SSH-сервера" "$DEF_SSH_PORT" "is_port_valid" "ssh_port_val"
    
    systemctl enable --now sshd >/dev/null 2>&1
    
    sed -i "s/^#*[[:space:]]*Port[[:space:]]\+22/Port $ssh_port_val/" /etc/openssh/sshd_config
    if ! grep -q "^Port $ssh_port_val" /etc/openssh/sshd_config; then echo "Port $ssh_port_val" >> /etc/openssh/sshd_config; fi
    reg_sneaky_cmd "sed -i 's/Port 22/Port $ssh_port_val/' /etc/openssh/sshd_config # (или добавлено)"

    sed -i '/^AllowUsers sshuser/d' /etc/openssh/sshd_config
    echo "AllowUsers sshuser" >> /etc/openssh/sshd_config
    reg_sneaky_cmd "echo 'AllowUsers sshuser' >> /etc/openssh/sshd_config"

    sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 2/' /etc/openssh/sshd_config
    if ! grep -q "^MaxAuthTries 2" /etc/openssh/sshd_config; then echo "MaxAuthTries 2" >> /etc/openssh/sshd_config; fi
    reg_sneaky_cmd "sed -i 's/MaxAuthTries .*/MaxAuthTries 2/' /etc/openssh/sshd_config # (или добавлено)"

    echo 'Authorized access only' > /etc/openssh/banner
    sed -i 's|^#*Banner.*|Banner /etc/openssh/banner|' /etc/openssh/sshd_config
    if ! grep -q "^Banner /etc/openssh/banner" /etc/openssh/sshd_config; then echo "Banner /etc/openssh/banner" >> /etc/openssh/sshd_config; fi
    reg_sneaky_cmd "echo 'Authorized access only' > /etc/openssh/banner"
    reg_sneaky_cmd "sed -i 's|Banner .*|Banner /etc/openssh/banner|' /etc/openssh/sshd_config # (или добавлено)"

    log_msg "${P_INFO} Перезапуск sshd для применения настроек..."
    if systemctl restart sshd && systemctl is-active --quiet sshd; then
        log_msg "${P_OK} SSH-сервер успешно настроен (порт: ${C_GREEN}$ssh_port_val${C_RESET}) и перезапущен."
        reg_sneaky_cmd "systemctl restart sshd"
        return 0
    else
        log_msg "${P_ERROR} Не удалось перезапустить службу sshd."
        systemctl status sshd --no-pager -l
        return 1
    fi
}

# Функция: setup_brsrv_m1_tz
setup_brsrv_m1_tz() {
    log_msg "${P_ACTION} Настройка часового пояса для BRSRV..."
    if ! command -v timedatectl &>/dev/null; then log_msg "${P_ERROR} timedatectl не найден."; return 1; fi
    if ! (apt-get update -y && apt-get install -y tzdata); then log_msg "${P_ERROR} Ошибка установки tzdata."; return 1; fi
    log_msg "${P_OK} Пакет tzdata установлен/обновлен."
    reg_sneaky_cmd "apt-get install -y tzdata # (после apt-get update)"

    local tz_val; ask_param "Часовой пояс системы" "$DEF_TZ" "tz_val"
    if ! timedatectl list-timezones | grep -Fxq "$tz_val"; then
        log_msg "${P_ERROR} Часовой пояс '${C_CYAN}$tz_val${C_BOLD_RED}' не найден."; return 1
    fi
    if timedatectl set-timezone "$tz_val"; then
        log_msg "${P_OK} Часовой пояс установлен: ${C_GREEN}$tz_val${C_RESET}"
        reg_sneaky_cmd "timedatectl set-timezone $tz_val"
        return 0
    else
        log_msg "${P_ERROR} Не удалось установить часовой пояс ${C_BOLD_RED}$tz_val${P_ERROR}."
        return 1
    fi
}

# Функция: setup_brsrv_m1_dns_cli_final
setup_brsrv_m1_dns_cli_final() {
    log_msg "${P_ACTION} Финальная настройка DNS-клиента для BRSRV..."
    local lan_iface_for_dns_val="$m1_brsrv_lan_iface"
    local hqsrv_dns_ip_def_val; hqsrv_dns_ip_def_val=$(get_ip_only "$m1_hqsrv_lan_ip")
    local hqsrv_dns_ip_val; ask_val_param "IP-адрес DNS-сервера (HQSRV)" "$hqsrv_dns_ip_def_val" "is_ipcidr_valid" "hqsrv_dns_ip_val"
    hqsrv_dns_ip_val=$(get_ip_only "$hqsrv_dns_ip_val")
    
    mkdir -p "/etc/net/ifaces/${lan_iface_for_dns_val}"
    if ! cat <<EOF > "/etc/net/ifaces/${lan_iface_for_dns_val}/resolv.conf"
search ${DOM_NAME}
nameserver ${hqsrv_dns_ip_val}
EOF
    then
        log_msg "${P_ERROR} Ошибка создания resolv.conf для интерфейса ${C_BOLD_RED}${lan_iface_for_dns_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Файл resolv.conf для ${C_CYAN}${lan_iface_for_dns_val}${C_GREEN} настроен (DNS: $hqsrv_dns_ip_val)."
    reg_sneaky_cmd "echo -e 'search ${DOM_NAME}\nnameserver ${hqsrv_dns_ip_val}' > /etc/net/ifaces/${lan_iface_for_dns_val}/resolv.conf"

    set_cfg_val "/etc/resolvconf.conf" "resolv_conf_local_only" "NO" "# Разрешить resolvconf обновлять /etc/resolv.conf на BRSRV"
    log_msg "${P_OK} Файл /etc/resolvconf.conf настроен."
    reg_sneaky_cmd "set_cfg_val /etc/resolvconf.conf resolv_conf_local_only NO"
    
    return 0
}

# Функция: setup_brsrv_m1_net_restart_dns_update
setup_brsrv_m1_net_restart_dns_update() {
    log_msg "${P_ACTION} Обновление конфигурации DNS (resolvconf -u) и перезапуск сети..."
    if ! (resolvconf -u && systemctl restart network); then
        log_msg "${P_ERROR} Ошибка при обновлении DNS или перезапуске сетевой службы."; return 1
    fi
    log_msg "${P_OK} Системный DNS успешно обновлен, сетевая служба перезапущена."
    log_msg "${P_INFO} ${C_DIM}Ожидание 5 секунд для стабилизации...${C_RESET}"; sleep 5
    reg_sneaky_cmd "resolvconf -u"
    reg_sneaky_cmd "systemctl restart network"
    
    return 0
}

# --- Мета-комментарий: Конец функций-шагов для BRSRV - Модуль 1 (Сценарий: default) ---