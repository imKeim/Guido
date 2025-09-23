#!/bin/bash
# Файл: fx_lib/default/hq_rtr/hq_rtr_m2_fx.sh
# Содержит функции-шаги для роли HQ_RTR, Модуль 2, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для HQ_RTR - Модуль 2 (Сценарий: default) ---

# Функция: setup_hq_rtr_m2_ntp_srv
# Назначение: Настраивает HQ_RTR как NTP-сервер для внутренней сети.
setup_hq_rtr_m2_ntp_srv() {
    log_msg "${P_ACTION} Настройка NTP-сервера (chrony) на HQ_RTR..."
    if ! ensure_pkgs "chronyc" "chrony"; then
        log_msg "${P_ERROR} Пакет chrony не установлен."
        return 1
    fi

    local net_hq_srv_allow_val; net_hq_srv_allow_val=$(get_netaddr "$m1_hq_rtr_vlan_srv_ip")
    local net_hq_cli_allow_val; net_hq_cli_allow_val=$(get_netaddr "$m1_hq_rtr_vlan_cli_ip")
    
    local vlan_mgmt_id_for_ntp_val; ask_val_param "VLAN ID сети Управления (для NTP allow)" "$m1_hq_rtr_vlan_mgmt_id_def" "is_vlan_valid" "vlan_mgmt_id_for_ntp_val"
    local vlan_mgmt_ip_for_ntp_val; ask_val_param "IP и маска VLAN Управления (для NTP allow)" "$m1_hq_rtr_vlan_mgmt_ip_def" "is_ipcidr_valid" "vlan_mgmt_ip_for_ntp_val"
    local net_mgmt_allow_val; net_mgmt_allow_val=$(get_netaddr "$vlan_mgmt_ip_for_ntp_val")
    
    local net_br_lan_allow_val; net_br_lan_allow_val=$(get_netaddr "$m1_br_rtr_lan_ip")
    local net_gre_allow_val; net_gre_allow_val=$(get_netaddr "$m1_hq_rtr_gre_tunnel_ip")

    if ! cat <<EOF > /etc/chrony.conf
# Конфигурация NTP-сервера chrony для HQ_RTR
local stratum 5
allow ${net_hq_srv_allow_val}
allow ${net_hq_cli_allow_val}
allow ${net_mgmt_allow_val}
allow ${net_br_lan_allow_val}
allow ${net_gre_allow_val}
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
    then
        log_msg "${P_ERROR} Ошибка записи в /etc/chrony.conf."; return 1
    fi
    log_msg "${P_OK} Файл /etc/chrony.conf успешно сконфигурирован."
    reg_sneaky_cmd "cat /etc/chrony.conf # (содержимое выше)"

    if systemctl enable --now chronyd && systemctl restart chronyd && systemctl is-active --quiet chronyd; then
        log_msg "${P_OK} Служба chronyd (NTP-сервер) включена и активна."
        reg_sneaky_cmd "systemctl enable --now chronyd"
        return 0
    else
        log_msg "${P_ERROR} Не удалось запустить службу chronyd."
        systemctl status chronyd --no-pager -l
        return 1
    fi
}

# Функция: setup_hq_rtr_m2_nginx_reverse_proxy
# Назначение: Настраивает Nginx как обратный прокси для Moodle и MediaWiki.
setup_hq_rtr_m2_nginx_reverse_proxy() {
    log_msg "${P_ACTION} Настройка Nginx как обратного прокси на HQ_RTR..."
    if ! ensure_pkgs "nginx" "nginx"; then
        log_msg "${P_ERROR} Пакет Nginx не установлен."
        return 1
    fi

    local moodle_backend_ip_val; moodle_backend_ip_val=$(get_ip_only "$m1_hq_srv_lan_ip")
    local moodle_backend_port_val="$m2_nginx_moodle_backend_port"
    
    local wiki_backend_ip_val; wiki_backend_ip_val=$(get_ip_only "$m1_br_srv_lan_ip")
    local wiki_backend_port_def_val="$m2_nginx_wiki_backend_port_def"
    local wiki_backend_port_val; ask_val_param "Порт MediaWiki на BR_SRV (для Nginx proxy_pass)" "$wiki_backend_port_def_val" "is_port_valid" "wiki_backend_port_val"

    mkdir -p /etc/nginx/sites-available.d /etc/nginx/sites-enabled.d
    reg_sneaky_cmd "mkdir -p /etc/nginx/sites-available.d /etc/nginx/sites-enabled.d"

    if ! cat <<EOF > /etc/nginx/sites-available.d/moodle.conf
server {
    listen 80;
    server_name moodle.${DOM_NAME};

    location / {
        proxy_pass http://${moodle_backend_ip_val}:${moodle_backend_port_val};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    then
        log_msg "${P_ERROR} Ошибка записи конфигурации Nginx для Moodle."; return 1
    fi
    ln -sf /etc/nginx/sites-available.d/moodle.conf /etc/nginx/sites-enabled.d/moodle.conf
    log_msg "${P_OK} Конфигурация Nginx для Moodle (moodle.${DOM_NAME}) создана и включена."
    reg_sneaky_cmd "cat /etc/nginx/sites-available.d/moodle.conf # (содержимое выше)"
    reg_sneaky_cmd "ln -sf /etc/nginx/sites-available.d/moodle.conf /etc/nginx/sites-enabled.d/moodle.conf"

    if ! cat <<EOF > /etc/nginx/sites-available.d/wiki.conf
server {
    listen 80;
    server_name wiki.${DOM_NAME};

    location / {
        proxy_pass http://${wiki_backend_ip_val}:${wiki_backend_port_val};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    then
        log_msg "${P_ERROR} Ошибка записи конфигурации Nginx для Wiki."; return 1
    fi
    ln -sf /etc/nginx/sites-available.d/wiki.conf /etc/nginx/sites-enabled.d/wiki.conf
    log_msg "${P_OK} Конфигурация Nginx для Wiki (wiki.${DOM_NAME}) создана и включена."
    reg_sneaky_cmd "cat /etc/nginx/sites-available.d/wiki.conf # (содержимое выше)"
    reg_sneaky_cmd "ln -sf /etc/nginx/sites-available.d/wiki.conf /etc/nginx/sites-enabled.d/wiki.conf"

    log_msg "${P_INFO} Проверка конфигурации Nginx (nginx -t)..."
    if nginx -t; then
        log_msg "${P_OK} Конфигурация Nginx корректна."
        if systemctl enable --now nginx && systemctl restart nginx && systemctl is-active --quiet nginx; then
            log_msg "${P_OK} Служба Nginx включена и активна."
            reg_sneaky_cmd "systemctl enable --now nginx"
            return 0
        else
            log_msg "${P_ERROR} Не удалось запустить службу Nginx."
            systemctl status nginx --no-pager -l
            return 1
        fi
    else
        log_msg "${P_ERROR} Ошибка в конфигурации Nginx (вывод 'nginx -t' см. выше)."
        return 1
    fi
}

# Функция: setup_hq_rtr_m2_dnat_ssh_to_hq_srv
# Назначение: Настраивает DNAT на HQ_RTR для проброса SSH-соединений на HQ_SRV.
setup_hq_rtr_m2_dnat_ssh_to_hq_srv() {
    log_msg "${P_ACTION} Настройка DNAT для SSH на HQ_SRV через HQ_RTR..."
    if ! ensure_pkgs "iptables" "iptables"; then
        log_msg "${P_ERROR} Пакет iptables не установлен."
        return 1
    fi

    local dnat_ext_port_val; ask_val_param "Внешний порт на HQ_RTR для DNAT SSH на HQ_SRV" "$m2_dnat_hq_rtr_to_hq_srv_ssh_port" "is_port_valid" "dnat_ext_port_val"
    local hq_srv_int_ip_val; hq_srv_int_ip_val=$(get_ip_only "$m1_hq_srv_lan_ip")
    local hq_srv_int_ssh_port_val="$DEF_SSH_PORT"
    
    local dnat_listen_iface_val; ask_param "Интерфейс HQ_RTR для приема DNAT-трафика (например, WAN или LAN Trunk)" "$m1_hq_rtr_wan_iface" "dnat_listen_iface_val"

    if ! iptables -t nat -C PREROUTING -i "$dnat_listen_iface_val" -p tcp --dport "$dnat_ext_port_val" -j DNAT --to-destination "${hq_srv_int_ip_val}:${hq_srv_int_ssh_port_val}" &>/dev/null; then
        iptables -t nat -A PREROUTING -i "$dnat_listen_iface_val" -p tcp --dport "$dnat_ext_port_val" -j DNAT --to-destination "${hq_srv_int_ip_val}:${hq_srv_int_ssh_port_val}"
        log_msg "${P_OK} Правило DNAT для SSH на HQ_SRV (порт ${C_CYAN}$dnat_ext_port_val${C_GREEN} -> ${hq_srv_int_ip_val}:${hq_srv_int_ssh_port_val}) добавлено."
        reg_sneaky_cmd "iptables -t nat -A PREROUTING -i $dnat_listen_iface_val -p tcp --dport $dnat_ext_port_val -j DNAT --to ${hq_srv_int_ip_val}:${hq_srv_int_ssh_port_val}"
    else
        log_msg "${P_INFO} Правило DNAT для SSH на HQ_SRV (порт ${C_CYAN}$dnat_ext_port_val${C_RESET}) уже существует."
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

# --- Мета-комментарий: Конец функций-шагов для HQ_RTR - Модуль 2 (Сценарий: default) ---