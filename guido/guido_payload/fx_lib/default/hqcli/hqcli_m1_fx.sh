#!/bin/bash
# Файл: fx_lib/default/hqcli/hqcli_m1_fx.sh
# Содержит функции-шаги для роли HQCLI, Модуль 1, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для HQCLI - Модуль 1 (Сценарий: default) ---

# Функция: setup_hqcli_m1_hn
# Назначение: Устанавливает имя хоста (FQDN) для ВМ HQCLI.
setup_hqcli_m1_hn() {
    local def_fqdn_val="${EXPECTED_FQDNS["hqcli"]}"
    local target_fqdn_val
    ask_param "FQDN для HQCLI" "$def_fqdn_val" "target_fqdn_val"

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

# Функция: setup_hqcli_m1_tmp_static_ip
# Назначение: Настраивает временный статический IP-адрес для HQCLI.
setup_hqcli_m1_tmp_static_ip() {
    local lan_iface_val; ask_param "LAN интерфейс HQCLI" "$m1_hqcli_lan_iface" "lan_iface_val"
    local tmp_static_ip_val; ask_val_param "Временный статический IP HQCLI (CIDR)" "$m1_hqcli_tmp_static_ip" "is_ipcidr_valid" "tmp_static_ip_val"
    local tmp_static_gw_val; ask_val_param "Временный статический шлюз HQCLI" "$m1_hqcli_tmp_static_gw" "is_ipcidr_valid" "tmp_static_gw_val"
    local tmp_dns1_val; ask_val_param "Основной DNS (временный)" "$DEF_DNS_PRIMARY" "is_ipcidr_valid" "tmp_dns1_val"
    local tmp_dns2_val; ask_val_param "Запасной DNS (временный)" "$DEF_DNS_SECONDARY" "is_ipcidr_valid" "tmp_dns2_val"

    log_msg "${P_ACTION} Настройка временного статического IP для HQCLI..."
    mkdir -p "/etc/net/ifaces/${lan_iface_val}" && find "/etc/net/ifaces/${lan_iface_val}" -mindepth 1 -delete
    if ! {
        echo 'TYPE=eth' > "/etc/net/ifaces/${lan_iface_val}/options" &&
        echo "$tmp_static_ip_val" > "/etc/net/ifaces/${lan_iface_val}/ipv4address" &&
        echo "default via $(get_ip_only "$tmp_static_gw_val")" > "/etc/net/ifaces/${lan_iface_val}/ipv4route" &&
        cat <<EOF > "/etc/net/ifaces/${lan_iface_val}/resolv.conf"
nameserver $(get_ip_only "$tmp_dns1_val")
nameserver $(get_ip_only "$tmp_dns2_val")
EOF
    }; then
        log_msg "${P_ERROR} Ошибка создания конфигурационных файлов для интерфейса ${C_BOLD_RED}${lan_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${lan_iface_val}${C_GREEN} (IP: $tmp_static_ip_val, GW: $tmp_static_gw_val) временно настроен."
    reg_sneaky_cmd "echo 'TYPE=eth' > /etc/net/ifaces/${lan_iface_val}/options"
    reg_sneaky_cmd "echo '$tmp_static_ip_val' > /etc/net/ifaces/${lan_iface_val}/ipv4address"
    reg_sneaky_cmd "echo 'default via $(get_ip_only "$tmp_static_gw_val")' > /etc/net/ifaces/${lan_iface_val}/ipv4route"
    reg_sneaky_cmd "echo -e 'nameserver $(get_ip_only "$tmp_dns1_val")\nnameserver $(get_ip_only "$tmp_dns2_val")' > /etc/net/ifaces/${lan_iface_val}/resolv.conf"
    
    return 0
}

# Функция: setup_hqcli_m1_net_restart_static_ip
setup_hqcli_m1_net_restart_static_ip() {
    log_msg "${P_ACTION} Перезапуск сетевой службы для применения временного статического IP..."
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

# Функция: setup_hqcli_m1_init_reboot_after_static_ip
setup_hqcli_m1_init_reboot_after_static_ip() {
    local vm_role_code="HQCLI"; local mod_num_val="1"
    local flag_reboot_initiated_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${FUNCNAME[0]}_reboot_initiated.flag"
    
    log_msg "${P_ACTION} ${C_BOLD_MAGENTA}ВНИМАНИЕ: Машина будет перезагружена для корректного применения сетевых настроек.${C_RESET}"
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}После перезагрузки, пожалуйста, войдите снова под пользователем root и запустите этот скрипт повторно.${C_RESET}"
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}Скрипт должен автоматически продолжить выполнение с нужного места.${C_RESET}"
    pause_pmt "Нажмите Enter для инициации перезагрузки через 5 секунд..."
    
    log_msg "${P_INFO} Инициирую перезагрузку через 5 секунд..."
    sleep 5
    touch "$flag_reboot_initiated_val"
    reg_sneaky_cmd "reboot # Инициирована перезагрузка HQCLI"

    if reboot; then
        return 2 
    else
        log_msg "${P_ERROR} Команда 'reboot' не удалась. Пожалуйста, перезагрузите машину вручную."
        rm -f "$flag_reboot_initiated_val"
        return 1
    fi
}

# Функция: setup_hqcli_m1_dhcp_cli_cfg
setup_hqcli_m1_dhcp_cli_cfg() {
    local vm_role_code="HQCLI"; local mod_num_val="1"
    local flag_reboot_marker_prev_step_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_setup_hqcli_m1_init_reboot_after_static_ip_reboot_initiated.flag"
    if [[ ! -f "$flag_reboot_marker_prev_step_val" ]]; then
        log_msg "${P_WARN} Предыдущий шаг (инициация перезагрузки) не был завершен штатно или его флаг отсутствует."
        log_msg "${P_WARN} Продолжение настройки DHCP может быть некорректным, если статический IP не был применен."
        pause_pmt "Нажмите Enter, если уверены, что хотите продолжить."
    fi

    log_msg "${P_ACTION} Настройка HQCLI на получение IP-адреса по DHCP..."
    if ! ensure_pkgs "dhcpcd" "dhcpcd"; then
        log_msg "${P_ERROR} Пакет dhcpcd не установлен."
        return 1
    fi

    local lan_iface_val; ask_param "LAN интерфейс HQCLI (для DHCP)" "$m1_hqcli_lan_iface" "lan_iface_val"
    local cli_id_val; ask_param "Client ID для DHCP (должен совпадать с резервацией на HQRTR)" "$m1_hqcli_dhcp_cli_id_def" "cli_id_val"

    mkdir -p "/etc/net/ifaces/${lan_iface_val}" && find "/etc/net/ifaces/${lan_iface_val}" -mindepth 1 -delete
    if ! cat <<EOF > "/etc/net/ifaces/${lan_iface_val}/options"
BOOTPROTO=dhcp
TYPE=eth
EOF
    then
        log_msg "${P_ERROR} Ошибка создания файла options для интерфейса ${C_BOLD_RED}${lan_iface_val}${P_ERROR}."; return 1
    fi
    rm -f "/etc/net/ifaces/${lan_iface_val}/ipv4address" "/etc/net/ifaces/${lan_iface_val}/ipv4route" "/etc/net/ifaces/${lan_iface_val}/resolv.conf"
    log_msg "${P_OK} Файлы конфигурации для интерфейса ${C_CYAN}${lan_iface_val}${C_GREEN} очищены и настроены на DHCP."
    reg_sneaky_cmd "echo -e 'BOOTPROTO=dhcp\nTYPE=eth' > /etc/net/ifaces/${lan_iface_val}/options"
    reg_sneaky_cmd "rm -f /etc/net/ifaces/${lan_iface_val}/ipv4address ..."

    sed -i "s/^[[:space:]]*#\?[[:space:]]*clientid.*/clientid $cli_id_val/" /etc/dhcpcd.conf
    if ! grep -q "^clientid $cli_id_val" /etc/dhcpcd.conf; then
        echo "clientid $cli_id_val" >> /etc/dhcpcd.conf
    fi
    sed -i 's/^[[:space:]]*duid/#duid/' /etc/dhcpcd.conf
    log_msg "${P_OK} Файл /etc/dhcpcd.conf настроен (clientid: ${C_CYAN}$cli_id_val${C_RESET})."
    reg_sneaky_cmd "sed -i 's/clientid.*/clientid $cli_id_val/' /etc/dhcpcd.conf # (или добавлено)"

    if [[ -f "$flag_reboot_marker_prev_step_val" ]]; then
        rm -f "$flag_reboot_marker_prev_step_val"
        log_msg "${P_INFO} Флаг перезагрузки '${C_CYAN}$flag_reboot_marker_prev_step_val${C_RESET}' успешно удален."
    fi
    return 0
}

# Функция: setup_hqcli_m1_net_restart_dhcp
setup_hqcli_m1_net_restart_dhcp() {
    log_msg "${P_ACTION} Перезапуск сетевой службы для получения IP по DHCP..."
    if systemctl restart network; then
        log_msg "${P_OK} Сетевая служба успешно перезапущена."
        log_msg "${P_INFO} ${C_DIM}Ожидание 10 секунд для получения адреса по DHCP...${C_RESET}"
        sleep 10
        log_msg "${P_INFO} Текущий IP-адрес интерфейса ${C_CYAN}$m1_hqcli_lan_iface${C_RESET} (ip addr show $m1_hqcli_lan_iface):"
        ip addr show "$m1_hqcli_lan_iface" | log_msg - "/dev/tty"
        reg_sneaky_cmd "systemctl restart network"
        return 0
    else
        log_msg "${P_ERROR} Не удалось перезапустить сетевую службу."
        return 1
    fi
}

# Функция: setup_hqcli_m1_dns_cli_final
setup_hqcli_m1_dns_cli_final() {
    log_msg "${P_ACTION} Финальная настройка DNS-клиента для HQCLI (через resolvconf)..."
    set_cfg_val "/etc/resolvconf.conf" "resolv_conf_local_only" "NO" "# Разрешить resolvconf обновлять /etc/resolv.conf на HQCLI"
    log_msg "${P_OK} Файл /etc/resolvconf.conf настроен."
    reg_sneaky_cmd "set_cfg_val /etc/resolvconf.conf resolv_conf_local_only NO"

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

# Функция: setup_hqcli_m1_tz
setup_hqcli_m1_tz() {
    log_msg "${P_ACTION} Настройка часового пояса для HQCLI..."
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

# --- Мета-комментарий: Функции-шаги для HQCLI - Модуль 1 (Сценарий: default) ---