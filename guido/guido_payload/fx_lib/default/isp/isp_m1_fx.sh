#!/bin/bash
# Файл: fx_lib/default/isp/isp_m1_fx.sh
# Содержит функции-шаги для роли ISP, Модуль 1, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для ISP - Модуль 1 (Сценарий: default) ---

# Функция: setup_isp_m1_hn
# Назначение: Устанавливает имя хоста (FQDN) для ВМ ISP.
setup_isp_m1_hn() {
    local def_fqdn_val="${EXPECTED_FQDNS["isp"]}"
    local target_fqdn_val
    ask_param "FQDN для ISP" "$def_fqdn_val" "target_fqdn_val"

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

# Функция: setup_isp_m1_net_ifaces
setup_isp_m1_net_ifaces() {
    local wan_iface_val; ask_param "WAN интерфейс ISP (для DHCP)" "$m1_isp_wan_iface" "wan_iface_val"
    local to_hq_rtr_iface_val; ask_param "Интерфейс ISP к HQ_RTR" "$m1_isp_to_hq_rtr_iface" "to_hq_rtr_iface_val"
    local ip_to_hq_rtr_iface_val; ask_val_param "IP-адрес ISP для линка к HQ_RTR (CIDR)" "$m1_isp_to_hq_rtr_ip" "is_ipcidr_valid" "ip_to_hq_rtr_iface_val"
    local to_br_rtr_iface_val; ask_param "Интерфейс ISP к BR_RTR" "$m1_isp_to_br_rtr_iface" "to_br_rtr_iface_val"
    local ip_to_br_rtr_iface_val; ask_val_param "IP-адрес ISP для линка к BR_RTR (CIDR)" "$m1_isp_to_br_rtr_ip" "is_ipcidr_valid" "ip_to_br_rtr_iface_val"

    log_msg "${P_ACTION} Настройка сетевых интерфейсов ISP..."
    mkdir -p "/etc/net/ifaces/${wan_iface_val}" && find "/etc/net/ifaces/${wan_iface_val}" -mindepth 1 -delete
    if ! cat <<EOF > "/etc/net/ifaces/${wan_iface_val}/options"
BOOTPROTO=dhcp
TYPE=eth
EOF
    then
        log_msg "${P_ERROR} Ошибка создания файла options для интерфейса ${C_BOLD_RED}${wan_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${wan_iface_val}${C_GREEN} (DHCP) настроен."
    reg_sneaky_cmd "echo -e 'BOOTPROTO=dhcp\nTYPE=eth' > /etc/net/ifaces/${wan_iface_val}/options"

    mkdir -p "/etc/net/ifaces/${to_hq_rtr_iface_val}" && find "/etc/net/ifaces/${to_hq_rtr_iface_val}" -mindepth 1 -delete
    if ! { echo 'TYPE=eth' > "/etc/net/ifaces/${to_hq_rtr_iface_val}/options" &&
          echo "$ip_to_hq_rtr_iface_val" > "/etc/net/ifaces/${to_hq_rtr_iface_val}/ipv4address"; }; then
        log_msg "${P_ERROR} Ошибка настройки интерфейса ${C_BOLD_RED}${to_hq_rtr_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${to_hq_rtr_iface_val}${C_GREEN} (IP: $ip_to_hq_rtr_iface_val) настроен."
    reg_sneaky_cmd "echo 'TYPE=eth' > /etc/net/ifaces/${to_hq_rtr_iface_val}/options"
    reg_sneaky_cmd "echo '$ip_to_hq_rtr_iface_val' > /etc/net/ifaces/${to_hq_rtr_iface_val}/ipv4address"

    mkdir -p "/etc/net/ifaces/${to_br_rtr_iface_val}" && find "/etc/net/ifaces/${to_br_rtr_iface_val}" -mindepth 1 -delete
    if ! { echo 'TYPE=eth' > "/etc/net/ifaces/${to_br_rtr_iface_val}/options" &&
           echo "$ip_to_br_rtr_iface_val" > "/etc/net/ifaces/${to_br_rtr_iface_val}/ipv4address"; }; then
        log_msg "${P_ERROR} Ошибка настройки интерфейса ${C_BOLD_RED}${to_br_rtr_iface_val}${P_ERROR}."; return 1
    fi
    log_msg "${P_OK} Интерфейс ${C_CYAN}${to_br_rtr_iface_val}${C_GREEN} (IP: $ip_to_br_rtr_iface_val) настроен."
    reg_sneaky_cmd "echo 'TYPE=eth' > /etc/net/ifaces/${to_br_rtr_iface_val}/options"
    reg_sneaky_cmd "echo '$ip_to_br_rtr_iface_val' > /etc/net/ifaces/${to_br_rtr_iface_val}/ipv4address"

    return 0
}

# Функция: setup_isp_m1_ip_forwarding
setup_isp_m1_ip_forwarding() {
    log_msg "${P_ACTION} Включение IP форвардинга..."
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

# Функция: setup_isp_m1_net_restart_init
setup_isp_m1_net_restart_init() {
    log_msg "${P_ACTION} Перезапуск сетевой службы..."
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

# Функция: setup_isp_m1_iptables_nat
setup_isp_m1_iptables_nat() {
    log_msg "${P_ACTION} Настройка iptables NAT (MASQUERADE)..."
    if ! ensure_pkgs "iptables" "iptables"; then
        log_msg "${P_ERROR} Пакет iptables не установлен и не может быть установлен."
        return 1
    fi

    local wan_iface_for_nat_val="$m1_isp_wan_iface" # Используем значение по умолчанию из vars.sh

    iptables -t nat -F POSTROUTING
    iptables -t nat -A POSTROUTING -o "$wan_iface_for_nat_val" -j MASQUERADE
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    log_msg "${P_OK} Правила iptables для NAT (MASQUERADE на $wan_iface_for_nat_val) применены."
    reg_sneaky_cmd "iptables -t nat -A POSTROUTING -o $wan_iface_for_nat_val -j MASQUERADE"

    if ! iptables-save > /etc/sysconfig/iptables; then
        log_msg "${P_ERROR} Не удалось сохранить правила iptables в /etc/sysconfig/iptables."
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

# Функция: setup_isp_m1_tz
setup_isp_m1_tz() {
    log_msg "${P_ACTION} Настройка часового пояса..."
    log_msg "${P_INFO} Обеспечение наличия 'timedatectl' и установка/обновление 'tzdata'..."
    if ! command -v timedatectl &>/dev/null; then
        log_msg "${P_ERROR} Команда 'timedatectl' не найдена. Это критично."
        return 1
    fi
    if ! (apt-get update -y && apt-get install -y tzdata); then
        log_msg "${P_ERROR} Не удалось установить или обновить пакет 'tzdata'."
        return 1
    fi
    log_msg "${P_OK} Пакет 'tzdata' успешно установлен/обновлен."
    reg_sneaky_cmd "apt-get install -y tzdata # (после apt-get update)"

    local tz_val; ask_param "Часовой пояс системы" "$DEF_TZ" "tz_val"

    if ! timedatectl list-timezones | grep -Fxq "$tz_val"; then
        log_msg "${P_ERROR} Часовой пояс '${C_CYAN}$tz_val${C_BOLD_RED}' не найден в системе."
        log_msg "${P_INFO} Доступные пояса: ${C_CYAN}timedatectl list-timezones${C_RESET}"
        return 1
    fi

    if timedatectl set-timezone "$tz_val"; then
        log_msg "${P_OK} Часовой пояс успешно установлен: ${C_GREEN}$tz_val${C_RESET}"
        reg_sneaky_cmd "timedatectl set-timezone $tz_val"
        return 0
    else
        log_msg "${P_ERROR} Не удалось установить часовой пояс ${C_BOLD_RED}$tz_val${P_ERROR}."
        return 1
    fi
}

# --- Мета-комментарий: Конец функций-шагов для ISP - Модуль 1 (Сценарий: default) ---
