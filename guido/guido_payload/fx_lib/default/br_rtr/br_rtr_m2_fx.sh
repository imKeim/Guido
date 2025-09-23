#!/bin/bash
# Файл: fx_lib/default/br_rtr/br_rtr_m2_fx.sh
# Содержит функции-шаги для роли BR_RTR, Модуль 2, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для BR_RTR - Модуль 2 (Сценарий: default) ---

# Функция: setup_br_rtr_m2_ntp_cli
# Назначение: Настраивает BR_RTR как NTP-клиента.
setup_br_rtr_m2_ntp_cli() {
    log_msg "${P_ACTION} Настройка NTP-клиента (chrony) на BR_RTR..."
    if ! ensure_pkgs "chronyc" "chrony"; then
        log_msg "${P_ERROR} Пакет chrony не установлен."
        return 1
    fi

    local ntp_srv_ip_def_val; ntp_srv_ip_def_val=$(get_ip_only "$m1_hq_rtr_gre_tunnel_ip")
    local ntp_srv_ip_val; ask_val_param "IP-адрес NTP-сервера (IP HQ_RTR в GRE-туннеле)" "$ntp_srv_ip_def_val" "is_ipcidr_valid" "ntp_srv_ip_val"
    ntp_srv_ip_val=$(get_ip_only "$ntp_srv_ip_val")

    if ! cat <<EOF > /etc/chrony.conf
# Конфигурация NTP-клиента chrony для BR_RTR
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

# Функция: setup_br_rtr_m2_dnat_wiki_ssh_to_br_srv
# Назначение: Настраивает DNAT на BR_RTR для Wiki и SSH на BR_SRV.
setup_br_rtr_m2_dnat_wiki_ssh_to_br_srv() {
    log_msg "${P_ACTION} Настройка DNAT для Wiki и SSH на BR_SRV через BR_RTR..."
    if ! ensure_pkgs "iptables" "iptables"; then
        log_msg "${P_ERROR} Пакет iptables не установлен."
        return 1
    fi

    local br_srv_int_ip_val; br_srv_int_ip_val=$(get_ip_only "$m1_br_srv_lan_ip")
    
    local dnat_listen_iface_val; ask_param "Интерфейс BR_RTR для приема DNAT-трафика (LAN-интерфейс)" "$m1_br_rtr_lan_iface" "dnat_listen_iface_val"

    local dnat_wiki_ext_port_val; ask_val_param "Внешний порт на BR_RTR для DNAT Wiki" "$m2_dnat_br_rtr_to_br_srv_wiki_ext_port_def" "is_port_valid" "dnat_wiki_ext_port_val"
    local wiki_int_port_def_val="$m2_nginx_wiki_backend_port_def"
    local wiki_int_port_val; ask_val_param "Внутренний порт MediaWiki на BR_SRV" "$wiki_int_port_def_val" "is_port_valid" "wiki_int_port_val"

    local dnat_ssh_port_on_br_rtr_val; ask_val_param "Порт на BR_RTR для DNAT SSH на BR_SRV" "$m2_dnat_br_rtr_to_br_srv_ssh_port_var" "is_port_valid" "dnat_ssh_port_on_br_rtr_val"
    local br_srv_int_ssh_port_val="$DEF_SSH_PORT"

    if ! iptables -t nat -C PREROUTING -i "$dnat_listen_iface_val" -p tcp --dport "$dnat_wiki_ext_port_val" -j DNAT --to-destination "${br_srv_int_ip_val}:${wiki_int_port_val}" &>/dev/null; then
        iptables -t nat -A PREROUTING -i "$dnat_listen_iface_val" -p tcp --dport "$dnat_wiki_ext_port_val" -j DNAT --to-destination "${br_srv_int_ip_val}:${wiki_int_port_val}"
        log_msg "${P_OK} Правило DNAT для Wiki (порт ${C_CYAN}$dnat_wiki_ext_port_val${C_GREEN} -> ${br_srv_int_ip_val}:${wiki_int_port_val}) добавлено."
        reg_sneaky_cmd "iptables -t nat -A PREROUTING -i $dnat_listen_iface_val -p tcp --dport $dnat_wiki_ext_port_val -j DNAT --to ${br_srv_int_ip_val}:${wiki_int_port_val}"
    else
        log_msg "${P_INFO} Правило DNAT для Wiki (порт ${C_CYAN}$dnat_wiki_ext_port_val${C_RESET}) уже существует."
    fi

    if ! iptables -t nat -C PREROUTING -i "$dnat_listen_iface_val" -p tcp --dport "$dnat_ssh_port_on_br_rtr_val" -j DNAT --to-destination "${br_srv_int_ip_val}:${br_srv_int_ssh_port_val}" &>/dev/null; then
        iptables -t nat -A PREROUTING -i "$dnat_listen_iface_val" -p tcp --dport "$dnat_ssh_port_on_br_rtr_val" -j DNAT --to-destination "${br_srv_int_ip_val}:${br_srv_int_ssh_port_val}"
        log_msg "${P_OK} Правило DNAT для SSH (порт ${C_CYAN}$dnat_ssh_port_on_br_rtr_val${C_GREEN} -> ${br_srv_int_ip_val}:${br_srv_int_ssh_port_val}) добавлено."
        reg_sneaky_cmd "iptables -t nat -A PREROUTING -i $dnat_listen_iface_val -p tcp --dport $dnat_ssh_port_on_br_rtr_val -j DNAT --to ${br_srv_int_ip_val}:${br_srv_int_ssh_port_val}"
    else
        log_msg "${P_INFO} Правило DNAT для SSH (порт ${C_CYAN}$dnat_ssh_port_on_br_rtr_val${C_RESET}) уже существует."
    fi
    
    if ! iptables-save > /etc/sysconfig/iptables; then
        log_msg "${P_ERROR} Не удалось сохранить правила iptables."
        return 1
    fi
    log_msg "${P_OK} Правила iptables (включая DNAT) сохранены."
    reg_sneaky_cmd "iptables-save > /etc/sysconfig/iptables"

    if systemctl restart iptables && systemctl is-active --quiet iptables; then
        log_msg "${P_OK} Служба iptables перезапущена."
        reg_sneaky_cmd "systemctl restart iptables"
        return 0
    else
        log_msg "${P_ERROR} Не удалось перезапустить службу iptables."
        systemctl status iptables --no-pager -l
        return 1
    fi
}

# --- Мета-комментарий: Конец функций-шагов для BR_RTR - Модуль 2 (Сценарий: default) ---