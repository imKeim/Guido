#!/bin/bash
# Файл: fx_lib/default/hqrtr/hqrtr_m1_fx.sh
# Содержит функции-шаги для роли HQRTR, Модуль 1, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для HQRTR - Модуль 1 (Сценарий: default) ---

# Функция: setup_hqrtr_m1_hn
# Назначение: Устанавливает имя хоста (FQDN) для ВМ HQRTR.
setup_hqrtr_m1_hn() {
    local def_fqdn_val="${EXPECTED_FQDNS["hqrtr"]}"
    local target_fqdn_val
    ask_param "FQDN для HQRTR" "$def_fqdn_val" "target_fqdn_val"

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

# Функция: setup_hqrtr_m1_net_ifaces_wan_lan_trunk
# Назначение: Настраивает WAN и LAN Trunk интерфейсы для ВМ HQRTR.
setup_hqrtr_m1_net_ifaces_wan_lan_trunk() {
    local wan_iface_val; ask_param "WAN интерфейс HQRTR" "$m1_hqrtr_wan_iface" "wan_iface_val"
    local wan_ip_val; ask_val_param "IP-адрес WAN HQRTR (CIDR)" "$m1_hqrtr_wan_ip" "is_ipcidr_valid" "wan_ip_val"
    local wan_gw_val; ask_val_param "Шлюз WAN HQRTR" "$m1_hqrtr_wan_gw" "is_ipcidr_valid" "wan_gw_val"
    local lan_trunk_iface_val; ask_param "LAN Trunk интерфейс HQRTR" "$m1_hqrtr_lan_trunk_iface" "lan_trunk_iface_val"
    local tmp_dns1_val; ask_val_param "Основной DNS (временный, для начальной настройки)" "$DEF_DNS_PRIMARY" "is_ipcidr_valid" "tmp_dns1_val"
    local tmp_dns2_val; ask_val_param "Запасной DNS (временный, для начальной настройки)" "$DEF_DNS_SECONDARY" "is_ipcidr_valid" "tmp_dns2_val"

    log_msg "${P_ACTION} Настройка WAN и LAN Trunk интерфейсов HQRTR..."
    mkdir -p "/etc/net/ifaces/${wan_iface_val}" && find "/etc/net/ifaces/${wan_iface_val}" -mindepth 1 -delete
    if ! {
        echo 'TYPE=eth' > "/etc/net/ifaces/${wan_iface_val}/options" &&
        echo "$wan_ip_val" > "/etc/net/ifaces/${wan_iface_val}/ipv4address" &&
        echo "default via $(get_ip_only "$wan_gw_val")" > "/etc/net/ifaces/${wan_iface_val}/ipv4route" &&
        cat <<EOF > "/etc/net/ifaces/${wan_iface_val}/resolv.conf"
nameserver $(get_ip_only "$tmp_dns1_val")
nameserver $(get_ip_only "$tmp_dns2_val")
EOF
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для интерфейса ${C_BOLD_RED}${wan_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${wan_iface_val}${C_GREEN} (IP: $wan_ip_val, GW: $wan_gw_val) настроен."
    reg_sneaky_cmd "echo 'TYPE=eth' > /etc/net/ifaces/${wan_iface_val}/options"
    reg_sneaky_cmd "echo '$wan_ip_val' > /etc/net/ifaces/${wan_iface_val}/ipv4address"
    reg_sneaky_cmd "echo 'default via $(get_ip_only "$wan_gw_val")' > /etc/net/ifaces/${wan_iface_val}/ipv4route"
    reg_sneaky_cmd "echo -e 'nameserver $(get_ip_only "$tmp_dns1_val")\nnameserver $(get_ip_only "$tmp_dns2_val")' > /etc/net/ifaces/${wan_iface_val}/resolv.conf"

    mkdir -p "/etc/net/ifaces/${lan_trunk_iface_val}" && find "/etc/net/ifaces/${lan_trunk_iface_val}" -mindepth 1 -delete
    if ! echo 'TYPE=eth' > "/etc/net/ifaces/${lan_trunk_iface_val}/options"; then
        log_msg "${P_ERROR} Ошибка создания файла options для интерфейса ${C_BOLD_RED}${lan_trunk_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${lan_trunk_iface_val}${C_GREEN} (Trunk) настроен для VLAN."
    reg_sneaky_cmd "echo 'TYPE=eth' > /etc/net/ifaces/${lan_trunk_iface_val}/options"
    
    return 0
}

# Функция: setup_hqrtr_m1_ip_forwarding
setup_hqrtr_m1_ip_forwarding() {
    log_msg "${P_ACTION} Включение IP форвардинга для HQRTR..."
    sed -i 's/^[#[:space:]]*net.ipv4.ip_forward[[:space:]]*=[[:space:]]*0/net.ipv4.ip_forward = 1/g' /etc/net/sysctl.conf
    if ! grep -q '^net.ipv4.ip_forward[[:space:]]*=[[:space:]]*1' /etc/net/sysctl.conf; then
        echo 'net.ipv4.ip_forward = 1' >> /etc/net/sysctl.conf
    fi
    sysctl -w net.ipv4.ip_forward=1
    reg_sneaky_cmd "sysctl -w net.ipv4.ip_forward=1"
    reg_sneaky_cmd "echo 'net.ipv4.ip_forward = 1' >> /etc/net/sysctl.conf # (или sed)"

    if [[ $(< /proc/sys/net/ipv4/ip_forward) -eq 1 ]]; then
        log_msg "${P_OK} IP форвардинг успешно включен."
        return 0
    else
        log_msg "${P_ERROR} Не удалось включить IP форвардинг."
        return 1
    fi
}

# Функция: setup_hqrtr_m1_net_restart_base_ip
setup_hqrtr_m1_net_restart_base_ip() {
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

# Функция: setup_hqrtr_m1_iptables_nat_mss
setup_hqrtr_m1_iptables_nat_mss() {
    log_msg "${P_ACTION} Настройка iptables NAT и TCP MSS clamping для HQRTR..."
    if ! ensure_pkgs "iptables" "iptables"; then
        log_msg "${P_ERROR} Пакет iptables не установлен."
        return 1
    fi

    local wan_iface_for_nat_val="$m1_hqrtr_wan_iface"
    local gre_iface_for_mss_val="$m1_hqrtr_gre_iface"

    iptables -t nat -F POSTROUTING
    iptables -t mangle -F FORWARD
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    iptables -t nat -A POSTROUTING -o "$wan_iface_for_nat_val" -j MASQUERADE
    log_msg "${P_OK} Правило MASQUERADE для ${C_CYAN}$wan_iface_for_nat_val${C_GREEN} добавлено."
    reg_sneaky_cmd "iptables -t nat -A POSTROUTING -o $wan_iface_for_nat_val -j MASQUERADE"

    iptables -t mangle -A FORWARD -o "$gre_iface_for_mss_val" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
    log_msg "${P_OK} Правило TCP MSS clamping для ${C_CYAN}$gre_iface_for_mss_val${C_GREEN} добавлено."
    reg_sneaky_cmd "iptables -t mangle -A FORWARD -o $gre_iface_for_mss_val -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu"

    if ! iptables-save > /etc/sysconfig/iptables; then
        log_msg "${P_ERROR} Не удалось сохранить правила iptables."
        return 1
    fi
    log_msg "${P_OK} Правила iptables сохранены в /etc/sysconfig/iptables."
    reg_sneaky_cmd "iptables-save > /etc/sysconfig/iptables"

    if systemctl enable --now iptables && systemctl is-active --quiet iptables; then
        log_msg "${P_OK} Служба iptables включена и активна."
        reg_sneaky_cmd "systemctl enable --now iptables"
        return 0
    else
        log_msg "${P_ERROR} Не удалось включить или запустить службу iptables."
        return 1
    fi
}

# Функция: setup_hqrtr_m1_user_net_admin
setup_hqrtr_m1_user_net_admin() {
    local username_val="net_admin"
    local target_uid_val; ask_val_param "UID для пользователя '${username_val}'" "$DEF_NET_ADMIN_UID" "is_uid_valid" "target_uid_val"
    local target_pass_val; ask_param "Пароль для пользователя '${username_val}'" "$DEF_NET_ADMIN_PASS" "target_pass_val"
    
    local sudoers_entry_val="${username_val} ALL=(ALL) NOPASSWD: ALL"

    log_msg "${P_ACTION} Настройка пользователя '${C_CYAN}${username_val}${C_RESET}'..."
    if id -u "$username_val" &>/dev/null; then
        log_msg "${P_INFO} Пользователь '${C_CYAN}${username_val}${C_RESET}' уже существует. Обновление пароля и группы..."
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

# Функция: setup_hqrtr_m1_vlans
setup_hqrtr_m1_vlans() {
    local trunk_iface_val; ask_param "Trunk интерфейс для создания VLAN'ов" "$m1_hqrtr_lan_trunk_iface" "trunk_iface_val"
    
    local vlan_srv_id_val="$m1_hqrtr_vlan_srv_id"
    local vlan_srv_ip_val; ask_val_param "IP-адрес для VLAN серверов (vlan${vlan_srv_id_val} на ${trunk_iface_val})" "$m1_hqrtr_vlan_srv_ip" "is_ipcidr_valid" "vlan_srv_ip_val"
    
    local vlan_cli_id_val="$m1_hqrtr_vlan_cli_id"
    local vlan_cli_ip_val; ask_val_param "IP-адрес для VLAN клиентов (vlan${vlan_cli_id_val} на ${trunk_iface_val})" "$m1_hqrtr_vlan_cli_ip" "is_ipcidr_valid" "vlan_cli_ip_val"

    local vlan_mgmt_id_val; ask_val_param "VLAN ID для сети Управления" "$m1_hqrtr_vlan_mgmt_id_def" "is_vlan_valid" "vlan_mgmt_id_val"
    local vlan_mgmt_ip_val; ask_val_param "IP-адрес для VLAN Управления (vlan${vlan_mgmt_id_val} на ${trunk_iface_val})" "$m1_hqrtr_vlan_mgmt_ip_def" "is_ipcidr_valid" "vlan_mgmt_ip_val"

    log_msg "${P_ACTION} Настройка VLAN-интерфейсов на ${C_CYAN}${trunk_iface_val}${C_RESET}..."

    mkdir -p "/etc/net/ifaces/vlan${vlan_srv_id_val}"
    if ! {
        cat <<EOF > "/etc/net/ifaces/vlan${vlan_srv_id_val}/options"
TYPE=vlan
HOST=${trunk_iface_val}
VID=${vlan_srv_id_val}
EOF
        echo "$vlan_srv_ip_val" > "/etc/net/ifaces/vlan${vlan_srv_id_val}/ipv4address"
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для VLAN ${C_BOLD_RED}${vlan_srv_id_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} VLAN ${C_CYAN}vlan${vlan_srv_id_val}${C_GREEN} (IP: $vlan_srv_ip_val) настроен."
    reg_sneaky_cmd "echo -e 'TYPE=vlan\nHOST=${trunk_iface_val}\nVID=${vlan_srv_id_val}' > /etc/net/ifaces/vlan${vlan_srv_id_val}/options"
    reg_sneaky_cmd "echo '$vlan_srv_ip_val' > /etc/net/ifaces/vlan${vlan_srv_id_val}/ipv4address"

    mkdir -p "/etc/net/ifaces/vlan${vlan_cli_id_val}"
    if ! {
        cat <<EOF > "/etc/net/ifaces/vlan${vlan_cli_id_val}/options"
TYPE=vlan
HOST=${trunk_iface_val}
VID=${vlan_cli_id_val}
EOF
        echo "$vlan_cli_ip_val" > "/etc/net/ifaces/vlan${vlan_cli_id_val}/ipv4address"
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для VLAN ${C_BOLD_RED}${vlan_cli_id_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} VLAN ${C_CYAN}vlan${vlan_cli_id_val}${C_GREEN} (IP: $vlan_cli_ip_val) настроен."
    reg_sneaky_cmd "echo -e 'TYPE=vlan\nHOST=${trunk_iface_val}\nVID=${vlan_cli_id_val}' > /etc/net/ifaces/vlan${vlan_cli_id_val}/options"
    reg_sneaky_cmd "echo '$vlan_cli_ip_val' > /etc/net/ifaces/vlan${vlan_cli_id_val}/ipv4address"

    mkdir -p "/etc/net/ifaces/vlan${vlan_mgmt_id_val}"
    if ! {
        cat <<EOF > "/etc/net/ifaces/vlan${vlan_mgmt_id_val}/options"
TYPE=vlan
HOST=${trunk_iface_val}
VID=${vlan_mgmt_id_val}
EOF
        echo "$vlan_mgmt_ip_val" > "/etc/net/ifaces/vlan${vlan_mgmt_id_val}/ipv4address"
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для VLAN ${C_BOLD_RED}${vlan_mgmt_id_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} VLAN ${C_CYAN}vlan${vlan_mgmt_id_val}${C_GREEN} (IP: $vlan_mgmt_ip_val) настроен."
    reg_sneaky_cmd "echo -e 'TYPE=vlan\nHOST=${trunk_iface_val}\nVID=${vlan_mgmt_id_val}' > /etc/net/ifaces/vlan${vlan_mgmt_id_val}/options"
    reg_sneaky_cmd "echo '$vlan_mgmt_ip_val' > /etc/net/ifaces/vlan${vlan_mgmt_id_val}/ipv4address"
    
    return 0
}

# Функция: setup_hqrtr_m1_net_restart_vlans
setup_hqrtr_m1_net_restart_vlans() {
    log_msg "${P_ACTION} Перезапуск сетевой службы для применения настроек VLAN..."
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

# Функция: setup_hqrtr_m1_gre_tunnel
setup_hqrtr_m1_gre_tunnel() {
    local gre_iface_name_val; ask_param "Имя GRE интерфейса" "$m1_hqrtr_gre_iface" "gre_iface_name_val"
    local gre_tunnel_ip_val; ask_val_param "IP-адрес GRE интерфейса (CIDR)" "$m1_hqrtr_gre_tunnel_ip" "is_ipcidr_valid" "gre_tunnel_ip_val"
    
    local def_tunnel_local_ip_val; def_tunnel_local_ip_val=$(get_ip_only "$m1_hqrtr_wan_ip")
    local tunnel_local_ip_val; ask_val_param "Локальный IP для туннеля (WAN IP HQRTR)" "$def_tunnel_local_ip_val" "is_ipcidr_valid" "tunnel_local_ip_val"
    tunnel_local_ip_val=$(get_ip_only "$tunnel_local_ip_val")

    local tunnel_remote_ip_val; ask_val_param "Удаленный IP для туннеля (WAN IP BRRTR)" "$m1_hqrtr_gre_remote_ip_var" "is_ipcidr_valid" "tunnel_remote_ip_val"
    tunnel_remote_ip_val=$(get_ip_only "$tunnel_remote_ip_val")

    log_msg "${P_ACTION} Настройка GRE туннеля ${C_CYAN}${gre_iface_name_val}${C_RESET}..."
    mkdir -p "/etc/net/ifaces/${gre_iface_name_val}"
    if ! {
        echo "$gre_tunnel_ip_val" > "/etc/net/ifaces/${gre_iface_name_val}/ipv4address" &&
        cat <<EOF > "/etc/net/ifaces/${gre_iface_name_val}/options"
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=${tunnel_local_ip_val}
TUNREMOTE=${tunnel_remote_ip_val}
TUNTTL=64
TUNOPTIONS='ttl 64'
EOF
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для GRE туннеля ${C_BOLD_RED}${gre_iface_name_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} GRE туннель ${C_CYAN}${gre_iface_name_val}${C_GREEN} (IP: $gre_tunnel_ip_val, Local: $tunnel_local_ip_val, Remote: $tunnel_remote_ip_val) настроен."
    reg_sneaky_cmd "echo '$gre_tunnel_ip_val' > /etc/net/ifaces/${gre_iface_name_val}/ipv4address"
    reg_sneaky_cmd "echo -e 'TYPE=iptun\nTUNTYPE=gre\nTUNLOCAL=${tunnel_local_ip_val}\nTUNREMOTE=${tunnel_remote_ip_val}\n...' > /etc/net/ifaces/${gre_iface_name_val}/options"
    
    return 0
}

# Функция: setup_hqrtr_m1_net_restart_gre
setup_hqrtr_m1_net_restart_gre() {
    log_msg "${P_ACTION} Перезапуск сетевой службы для применения настроек GRE..."
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

# Функция: setup_hqrtr_m1_tz
setup_hqrtr_m1_tz() {
    log_msg "${P_ACTION} Настройка часового пояса для HQRTR..."
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

# Функция: setup_hqrtr_m1_dns_cli_final
setup_hqrtr_m1_dns_cli_final() {
    log_msg "${P_ACTION} Финальная настройка DNS-клиента для HQRTR..."
    local vlan_srv_id_for_dns_val="$m1_hqrtr_vlan_srv_id"
    local hqsrv_dns_ip_def_val; hqsrv_dns_ip_def_val=$(get_ip_only "$m1_hqsrv_lan_ip")
    local hqsrv_dns_ip_val; ask_val_param "IP-адрес DNS-сервера (HQSRV)" "$hqsrv_dns_ip_def_val" "is_ipcidr_valid" "hqsrv_dns_ip_val"
    hqsrv_dns_ip_val=$(get_ip_only "$hqsrv_dns_ip_val")
    
    local wan_iface_to_deny_dns_val="$m1_hqrtr_wan_iface"

    mkdir -p "/etc/net/ifaces/vlan${vlan_srv_id_for_dns_val}"
    if ! cat <<EOF > "/etc/net/ifaces/vlan${vlan_srv_id_for_dns_val}/resolv.conf"
search ${DOM_NAME}
nameserver ${hqsrv_dns_ip_val}
EOF
    then
        log_msg "${P_ERROR} Ошибка создания resolv.conf для интерфейса ${C_BOLD_RED}vlan${vlan_srv_id_for_dns_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Файл resolv.conf для ${C_CYAN}vlan${vlan_srv_id_for_dns_val}${C_GREEN} настроен (DNS: $hqsrv_dns_ip_val)."
    reg_sneaky_cmd "echo -e 'search ${DOM_NAME}\nnameserver ${hqsrv_dns_ip_val}' > /etc/net/ifaces/vlan${vlan_srv_id_for_dns_val}/resolv.conf"

    set_cfg_val "/etc/resolvconf.conf" "resolv_conf_local_only" "NO" "# Разрешить resolvconf обновлять /etc/resolv.conf на HQRTR"
    set_cfg_val "/etc/resolvconf.conf" "deny_interfaces" "\"${wan_iface_to_deny_dns_val} lo.dnsmasq\"" "# Запретить обновление DNS с WAN и локального dnsmasq (если он был)"
    log_msg "${P_OK} Файл /etc/resolvconf.conf настроен."
    reg_sneaky_cmd "set_cfg_val /etc/resolvconf.conf resolv_conf_local_only NO"
    reg_sneaky_cmd "set_cfg_val /etc/resolvconf.conf deny_interfaces \"${wan_iface_to_deny_dns_val} lo.dnsmasq\""

    log_msg "${P_ACTION} Обновление конфигурации DNS (resolvconf -u) и перезапуск сети..."
    if ! (resolvconf -u && systemctl restart network); then
        log_msg "${P_ERROR} Ошибка при обновлении DNS (resolvconf -u) или перезапуске сетевой службы."; return 1
    fi
    log_msg "${P_OK} Системный DNS успешно обновлен, сетевая служба перезапущена."
    log_msg "${P_INFO} ${C_DIM}Ожидание 5 секунд для стабилизации...${C_RESET}"; sleep 5
    reg_sneaky_cmd "resolvconf -u"
    reg_sneaky_cmd "systemctl restart network"
    
    return 0
}

# Функция: setup_hqrtr_m1_dhcp_srv
setup_hqrtr_m1_dhcp_srv() {
    log_msg "${P_ACTION} Настройка DHCP-сервера (dnsmasq) на HQRTR..."
    if ! ensure_pkgs "dnsmasq" "dnsmasq"; then
        log_msg "${P_ERROR} Пакет dnsmasq не установлен и не может быть установлен."
        return 1
    fi

    local vlan_cli_id_for_dhcp_val="$m1_hqrtr_vlan_cli_id"
    local listen_addr_def_val; listen_addr_def_val=$(get_ip_only "$m1_hqrtr_vlan_cli_ip")
    local range_start_def_val="$m1_hqrtr_dhcp_range_start_def"
    local range_end_def_val="$m1_hqrtr_dhcp_range_end_def"
    local range_mask_def_val="$m1_hqrtr_dhcp_subnet_mask_def"
    local hqcli_cli_id_def_val="$m1_hqcli_dhcp_cli_id_def"
    local hqcli_reserved_ip_def_val="$m1_hqcli_dhcp_reserved_ip_def"
    local dns_srv_for_cli_def_val; dns_srv_for_cli_def_val=$(get_ip_only "$m1_hqsrv_lan_ip")

    local listen_addr_val; ask_val_param "IP-адрес для прослушивания DHCP (IP HQRTR в VLAN ${vlan_cli_id_for_dhcp_val})" "$listen_addr_def_val" "is_ipcidr_valid" "listen_addr_val"
    listen_addr_val=$(get_ip_only "$listen_addr_val")
    local range_start_val; ask_val_param "Начальный IP-адрес DHCP-диапазона" "$range_start_def_val" "is_ipcidr_valid" "range_start_val"; range_start_val=$(get_ip_only "$range_start_val")
    local range_end_val; ask_val_param "Конечный IP-адрес DHCP-диапазона" "$range_end_def_val" "is_ipcidr_valid" "range_end_val"; range_end_val=$(get_ip_only "$range_end_val")
    local range_mask_val; ask_param "Маска подсети для DHCP-диапазона" "$range_mask_def_val" "range_mask_val"
    local hqcli_cli_id_val; ask_param "Client ID для резервации IP HQCLI" "$hqcli_cli_id_def_val" "hqcli_cli_id_val"
    local hqcli_reserved_ip_val; ask_val_param "Резервируемый IP-адрес для HQCLI" "$hqcli_reserved_ip_def_val" "is_ipcidr_valid" "hqcli_reserved_ip_val"; hqcli_reserved_ip_val=$(get_ip_only "$hqcli_reserved_ip_val")
    local dns_srv_for_cli_val; ask_val_param "IP DNS-сервера для DHCP-клиентов (HQSRV)" "$dns_srv_for_cli_def_val" "is_ipcidr_valid" "dns_srv_for_cli_val"; dns_srv_for_cli_val=$(get_ip_only "$dns_srv_for_cli_val")

    cp /etc/dnsmasq.conf "/etc/dnsmasq.conf.bak.$(date +%F_%T)" 2>/dev/null || true
    cat <<EOF > /etc/dnsmasq.conf
# Конфигурация DHCP-сервера dnsmasq для HQRTR
interface=vlan${vlan_cli_id_for_dhcp_val}
listen-address=${listen_addr_val}
port=0
no-resolv
dhcp-authoritative
dhcp-range=interface:vlan${vlan_cli_id_for_dhcp_val},${range_start_val},${range_end_val},${range_mask_val},6h
dhcp-host=id:${hqcli_cli_id_val},hq-cli,${hqcli_reserved_ip_val},infinite
dhcp-option=6,${dns_srv_for_cli_val}
dhcp-option=15,${DOM_NAME}
EOF
    log_msg "${P_OK} Файл /etc/dnsmasq.conf успешно сконфигурирован."
    reg_sneaky_cmd "cat /etc/dnsmasq.conf # (содержимое выше)"

    if systemctl enable --now dnsmasq && systemctl restart dnsmasq && systemctl is-active --quiet dnsmasq; then
        log_msg "${P_OK} Служба dnsmasq (DHCP-сервер) включена и активна."
        reg_sneaky_cmd "systemctl enable --now dnsmasq"
        return 0
    else
        log_msg "${P_ERROR} Не удалось запустить службу dnsmasq."
        systemctl status dnsmasq --no-pager -l
        return 1
    fi
}

# Функция: setup_hqrtr_m1_ospf
setup_hqrtr_m1_ospf() {
    log_msg "${P_ACTION} Настройка OSPF-маршрутизации (FRR) на HQRTR..."
    if ! ensure_pkgs "vtysh" "frr"; then
        log_msg "${P_ERROR} Пакет FRR (frr) не установлен и не может быть установлен."
        return 1
    fi

    local gre_iface_for_ospf_val="$m1_hqrtr_gre_iface"
    local vlan_srv_id_for_ospf_val="$m1_hqrtr_vlan_srv_id"
    local vlan_cli_id_for_ospf_val="$m1_hqrtr_vlan_cli_id"
    local vlan_mgmt_id_def_for_ospf_val="$m1_hqrtr_vlan_mgmt_id_def"
    local router_id_def_val; router_id_def_val=$(get_ip_only "$m1_hqrtr_gre_tunnel_ip")
    local ospf_auth_key_def_val="$m1_ospf_auth_key_def"

    local vlan_mgmt_id_for_ospf_val; ask_val_param "VLAN ID сети Управления для OSPF" "$vlan_mgmt_id_def_for_ospf_val" "is_vlan_valid" "vlan_mgmt_id_for_ospf_val"
    local router_id_val; ask_val_param "Router ID для OSPF (рекомендуется IP GRE-туннеля)" "$router_id_def_val" "is_ipcidr_valid" "router_id_val"; router_id_val=$(get_ip_only "$router_id_val")
    local ospf_auth_key_val; ask_param "Ключ аутентификации OSPF (MD5)" "$ospf_auth_key_def_val" "ospf_auth_key_val"
    local ospf_auth_key_frr_fmt_val="${ospf_auth_key_val}"

    sed -i 's/^[#[:space:]]*ospfd[[:space:]]*=[[:space:]]*no/ospfd=yes/g' /etc/frr/daemons
    if ! grep -q "^ospfd=yes" /etc/frr/daemons; then
        echo "ospfd=yes" >> /etc/frr/daemons
    fi
    log_msg "${P_OK} Демон OSPFd включен в /etc/frr/daemons."
    reg_sneaky_cmd "sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons"

    cat <<EOF > /etc/frr/frr.conf
!
! FRRouting configuration file for HQRTR
!
hostname $(hostname -f)
log file /var/log/frr/frr.log debugging
!
! OSPF Configuration
!
interface ${gre_iface_for_ospf_val}
 description GRE Tunnel to Branch Router (BRRTR)
 ip ospf area 0.0.0.0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 ${ospf_auth_key_frr_fmt_val}
 no ip ospf passive-interface
exit
!
interface vlan${vlan_srv_id_for_ospf_val}
 description HQ Servers LAN (VLAN ${vlan_srv_id_for_ospf_val})
 ip ospf area 0.0.0.0
exit
!
interface vlan${vlan_cli_id_for_ospf_val}
 description HQ Clients LAN (VLAN ${vlan_cli_id_for_ospf_val})
 ip ospf area 0.0.0.0
exit
!
interface vlan${vlan_mgmt_id_for_ospf_val}
 description Management LAN (VLAN ${vlan_mgmt_id_for_ospf_val})
 ip ospf area 0.0.0.0
exit
!
router ospf
 ospf router-id ${router_id_val}
 passive-interface default
 no passive-interface ${gre_iface_for_ospf_val}
 area 0.0.0.0 authentication message-digest
exit
!
line vty
!
EOF
    log_msg "${P_OK} Файл /etc/frr/frr.conf для OSPF успешно сконфигурирован."
    reg_sneaky_cmd "cat /etc/frr/frr.conf # (содержимое выше)"

    if systemctl enable --now frr && systemctl restart frr && systemctl is-active --quiet frr; then
        log_msg "${P_OK} Служба FRR (OSPF) включена и активна."
        reg_sneaky_cmd "systemctl enable --now frr"
        return 0
    else
        log_msg "${P_ERROR} Не удалось запустить службу FRR."
        systemctl status frr --no-pager -l
        return 1
    fi
}

# --- Мета-комментарий: Конец функций-шагов для HQRTR - Модуль 1 (Сценарий: default) ---