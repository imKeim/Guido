#!/bin/bash
# Файл: fx_lib/default/hqsrv/hqsrv_m2_fx.sh
# Содержит функции-шаги для роли HQSRV, Модуль 2, сценарий "default".
# Этот файл подключается (source) функцией _run_step из menu.sh.

# --- Мета-комментарий: Функции-шаги для HQSRV - Модуль 2 (Сценарий: default) ---

# Функция: setup_hqsrv_m2_ntp_cli
# Назначение: Настраивает HQSRV как NTP-клиента.
setup_hqsrv_m2_ntp_cli() {
    log_msg "${P_ACTION} Настройка NTP-клиента (chrony) на HQSRV..."
    if ! ensure_pkgs "chronyc" "chrony"; then
        log_msg "${P_ERROR} Пакет chrony не установлен."
        return 1
    fi

    local ntp_srv_ip_def_val; ntp_srv_ip_def_val=$(get_ip_only "$m1_hqrtr_vlan_srv_ip")
    local ntp_srv_ip_val; ask_val_param "IP-адрес NTP-сервера (IP HQRTR в VLAN серверов)" "$ntp_srv_ip_def_val" "is_ipcidr_valid" "ntp_srv_ip_val"
    ntp_srv_ip_val=$(get_ip_only "$ntp_srv_ip_val")

    if ! cat <<EOF > /etc/chrony.conf
# Конфигурация NTP-клиента chrony для HQSRV
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

# Функция: setup_hqsrv_m2_ssh_srv_port_update
# Назначение: Обновляет порт SSH-сервера на HQSRV.
setup_hqsrv_m2_ssh_srv_port_update() {
    log_msg "${P_ACTION} Проверка и обновление порта SSH-сервера на HQSRV..."
    if ! command -v sshd &>/dev/null; then
        log_msg "${P_ERROR} Команда sshd не найдена. Убедитесь, что OpenSSH-server установлен."
        return 1
    fi

    local target_ssh_port_val; ask_val_param "Целевой порт SSH (должен совпадать с DNAT на HQRTR)" "$DEF_SSH_PORT" "is_port_valid" "target_ssh_port_val"
    
    local cur_ssh_port_val; cur_ssh_port_val=$(sshd -T 2>/dev/null | grep -i "^port " | awk '{print $2}' | head -n 1)

    if [[ -z "$cur_ssh_port_val" ]]; then
        log_msg "${P_WARN} Не удалось определить текущий порт SSH из конфигурации. Попытка установить порт ${C_CYAN}$target_ssh_port_val${C_RESET}."
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

# Функция: setup_hqsrv_m2_raid_nfs_srv
# Назначение: Настраивает программный RAID-массив и NFS-сервер на HQSRV.
setup_hqsrv_m2_raid_nfs_srv() {
    log_msg "${P_ACTION} Настройка RAID и NFS-сервера на HQSRV..."
    if ! ensure_pkgs "mdadm fdisk mkfs.ext4 exportfs" "mdadm fdisk e2fsprogs nfs-utils nfs-kernel-server"; then
        log_msg "${P_ERROR} Не удалось установить необходимые пакеты для RAID и/или NFS."
        return 1
    fi

    local raid_level_val; ask_val_param "Уровень RAID (например, 1, 5, 6)" "$m2_hqsrv_raid_level_def" "is_not_empty_valid" "raid_level_val"
    local raid_dev_name_val="$m2_hqsrv_raid_dev_name"
    local raid_disks_str_val; ask_param "Диски для RAID (через пробел, например, /dev/sdb /dev/sdc)" "$m2_hqsrv_raid_disks_def" "raid_disks_str_val"
    
    local raid_disks_arr_val; read -ra raid_disks_arr_val <<< "$raid_disks_str_val"
    local num_raid_disks_val=${#raid_disks_arr_val[@]}

    local min_disks_req_val=0
    case "$raid_level_val" in
        0|1|4) min_disks_req_val=2 ;;
        5|6) min_disks_req_val=3 ;;
        *) log_msg "${P_ERROR} Неподдерживаемый уровень RAID: ${C_BOLD_RED}$raid_level_val${P_ERROR}."; return 1 ;;
    esac
    if [[ "$num_raid_disks_val" -lt "$min_disks_req_val" ]]; then
        log_msg "${P_ERROR} Для RAID уровня ${C_BOLD_RED}$raid_level_val${P_ERROR} требуется минимум ${C_BOLD_RED}$min_disks_req_val${P_ERROR} диска(ов), указано: $num_raid_disks_val."; return 1
    fi

    local raid_full_dev_pth_val="/dev/${raid_dev_name_val}"
    local raid_part_dev_pth_val="${raid_full_dev_pth_val}p1"
    local raid_mount_point_val="${m2_hqsrv_raid_mount_point_base}${raid_level_val}"
    local nfs_export_full_pth_val="${raid_mount_point_val}/${m2_hqsrv_nfs_export_subdir}"

    if mdadm --detail "$raid_full_dev_pth_val" &>/dev/null; then
        log_msg "${P_INFO} RAID-массив ${C_CYAN}$raid_full_dev_pth_val${C_RESET} уже существует."
    else
        log_msg "${P_INFO} Создание RAID уровня ${C_CYAN}$raid_level_val${C_RESET} на устройстве ${C_CYAN}$raid_full_dev_pth_val${C_RESET} из дисков: ${C_CYAN}$raid_disks_str_val${C_RESET}..."
        # shellcheck disable=SC2068
        if mdadm --create "$raid_full_dev_pth_val" --level="$raid_level_val" --raid-devices="$num_raid_disks_val" ${raid_disks_arr_val[@]} --force --run; then
            log_msg "${P_OK} RAID-массив ${C_GREEN}$raid_full_dev_pth_val${C_RESET} успешно создан. Ожидание синхронизации (может занять время)..."
            sleep 10
            reg_sneaky_cmd "mdadm --create $raid_full_dev_pth_val --level=$raid_level_val --raid-devices=$num_raid_disks_val ${raid_disks_arr_val[*]}"
        else
            log_msg "${P_ERROR} Не удалось создать RAID-массив ${C_BOLD_RED}$raid_full_dev_pth_val${P_ERROR}."; return 1
        fi
    fi

    mkdir -p /etc/mdadm
    if ! grep -q "ARRAY $raid_full_dev_pth_val" /etc/mdadm/mdadm.conf 2>/dev/null; then
        mdadm --detail --scan --verbose | grep "$raid_full_dev_pth_val" | uniq >> /etc/mdadm/mdadm.conf
        if [[ -f /etc/mdadm.conf && -d /etc/mdadm ]]; then cp /etc/mdadm/mdadm.conf /etc/mdadm.conf 2>/dev/null || true; fi
        log_msg "${P_OK} Конфигурация RAID для ${C_CYAN}$raid_full_dev_pth_val${C_GREEN} сохранена в /etc/mdadm/mdadm.conf."
        reg_sneaky_cmd "mdadm --detail --scan >> /etc/mdadm/mdadm.conf"
    else
        log_msg "${P_INFO} Конфигурация для ${C_CYAN}$raid_full_dev_pth_val${C_RESET} уже присутствует в /etc/mdadm/mdadm.conf."
    fi

    if [[ -b "$raid_part_dev_pth_val" ]]; then
        log_msg "${P_INFO} Раздел ${C_CYAN}$raid_part_dev_pth_val${C_RESET} на RAID-массиве уже существует."
    else
        log_msg "${P_INFO} Создание раздела на ${C_CYAN}$raid_full_dev_pth_val${C_RESET}..."
        echo -e "g\nn\n\n\n\nw\n" | fdisk "$raid_full_dev_pth_val" &>/dev/null
        partprobe "$raid_full_dev_pth_val"
        sleep 5
        if [[ -b "$raid_part_dev_pth_val" ]]; then
            log_msg "${P_OK} Раздел ${C_GREEN}$raid_part_dev_pth_val${C_RESET} успешно создан."
            reg_sneaky_cmd "echo -e 'g\\nn\\n\\n\\n\\nw\\n' | fdisk $raid_full_dev_pth_val"
        else
            log_msg "${P_ERROR} Не удалось создать раздел ${C_BOLD_RED}$raid_part_dev_pth_val${P_ERROR}."; return 1
        fi
    fi
    
    if blkid -s TYPE -o value "$raid_part_dev_pth_val" 2>/dev/null | grep -q "ext4"; then
        log_msg "${P_INFO} Раздел ${C_CYAN}$raid_part_dev_pth_val${C_RESET} уже отформатирован в ext4."
    else
        log_msg "${P_INFO} Форматирование раздела ${C_CYAN}$raid_part_dev_pth_val${C_RESET} в файловую систему ext4..."
        if mkfs.ext4 -F "$raid_part_dev_pth_val"; then
            log_msg "${P_OK} Раздел ${C_GREEN}$raid_part_dev_pth_val${C_RESET} успешно отформатирован в ext4."
            reg_sneaky_cmd "mkfs.ext4 -F $raid_part_dev_pth_val"
        else
            log_msg "${P_ERROR} Не удалось отформатировать раздел ${C_BOLD_RED}$raid_part_dev_pth_val${P_ERROR}."; return 1
        fi
    fi

    mkdir -p "$raid_mount_point_val"
    local raid_part_uuid_val; raid_part_uuid_val=$(blkid -s UUID -o value "$raid_part_dev_pth_val")
    if [[ -z "$raid_part_uuid_val" ]]; then
        log_msg "${P_ERROR} Не удалось получить UUID для раздела ${C_BOLD_RED}$raid_part_dev_pth_val${P_ERROR}."; return 1
    fi
    if ! grep -q "UUID=$raid_part_uuid_val" /etc/fstab; then
        echo "UUID=$raid_part_uuid_val $raid_mount_point_val ext4 defaults 0 2" >> /etc/fstab
        log_msg "${P_OK} Запись для монтирования ${C_CYAN}$raid_mount_point_val${C_GREEN} добавлена в /etc/fstab."
        reg_sneaky_cmd "echo 'UUID=$raid_part_uuid_val $raid_mount_point_val ext4 defaults 0 2' >> /etc/fstab"
    else
        log_msg "${P_INFO} Запись для ${C_CYAN}$raid_mount_point_val${C_RESET} уже присутствует в /etc/fstab."
    fi
    if ! mountpoint -q "$raid_mount_point_val"; then
        if ! mount -a; then
            log_msg "${P_ERROR} Ошибка монтирования ${C_BOLD_RED}$raid_mount_point_val${P_ERROR} (mount -a)."; return 1
        fi
    fi
    log_msg "${P_OK} RAID-массив ${C_GREEN}$raid_mount_point_val${C_RESET} успешно смонтирован."
    reg_sneaky_cmd "mount -a"

    mkdir -p "$nfs_export_full_pth_val"
    chown nobody:nogroup "$nfs_export_full_pth_val"
    chmod 777 "$nfs_export_full_pth_val"
    
    local nfs_cli_net_cidr_val; nfs_cli_net_cidr_val=$(get_netaddr "$m1_hqrtr_vlan_cli_ip")
    local nfs_exports_entry_val="${nfs_export_full_pth_val} ${nfs_cli_net_cidr_val}(rw,sync,no_subtree_check,no_root_squash)"
    
    if grep -q "^${nfs_export_full_pth_val}[[:space:]]" /etc/exports; then
        sed -i "s|^${nfs_export_full_pth_val}[[:space:]].*|${nfs_exports_entry_val}|" /etc/exports
        log_msg "${P_OK} Запись NFS для ${C_CYAN}$nfs_export_full_pth_val${C_GREEN} обновлена в /etc/exports."
    else
        echo "$nfs_exports_entry_val" >> /etc/exports
        log_msg "${P_OK} Запись NFS для ${C_CYAN}$nfs_export_full_pth_val${C_GREEN} добавлена в /etc/exports."
    fi
    reg_sneaky_cmd "echo '$nfs_exports_entry_val' >> /etc/exports # (или sed)"

    if exportfs -ra && systemctl enable --now nfs-kernel-server && systemctl restart nfs-kernel-server && systemctl is-active --quiet nfs-kernel-server; then
        log_msg "${P_OK} NFS-сервер успешно настроен и активен."
        reg_sneaky_cmd "exportfs -ra"
        reg_sneaky_cmd "systemctl enable --now nfs-kernel-server"
        return 0
    else
        log_msg "${P_ERROR} Ошибка настройки или запуска NFS-сервера."
        systemctl status nfs-kernel-server --no-pager -l
        return 1
    fi
}

# Функция: setup_hqsrv_m2_dns_forwarding_for_ad
# Назначение: Настраивает условную пересылку DNS-запросов для домена AD.
setup_hqsrv_m2_dns_forwarding_for_ad() {
    log_msg "${P_ACTION} Настройка условной DNS-пересылки для домена AD на HQSRV..."
    
    local samba_dc_ip_val; samba_dc_ip_val=$(get_ip_only "$m1_brsrv_lan_ip")
    local ad_dom_dns_fwd_rule_val="server=/${DOM_NAME}/${samba_dc_ip_val}"

    if grep -qF "$ad_dom_dns_fwd_rule_val" /etc/dnsmasq.conf; then
        log_msg "${P_INFO} Правило DNS-пересылки для домена AD (${C_CYAN}${DOM_NAME}${C_RESET} -> ${C_CYAN}${samba_dc_ip_val}${C_RESET}) уже присутствует в /etc/dnsmasq.conf."
    else
        echo -e "\n# Условная пересылка DNS-запросов для домена Active Directory\n${ad_dom_dns_fwd_rule_val}" >> /etc/dnsmasq.conf
        log_msg "${P_OK} Правило DNS-пересылки для домена AD (${C_CYAN}${DOM_NAME}${C_RESET} -> ${C_CYAN}${samba_dc_ip_val}${C_RESET}) добавлено в /etc/dnsmasq.conf."
        reg_sneaky_cmd "echo '$ad_dom_dns_fwd_rule_val' >> /etc/dnsmasq.conf"
    fi

    log_msg "${P_INFO} Перезапуск службы dnsmasq для применения изменений..."
    if systemctl restart dnsmasq && systemctl is-active --quiet dnsmasq; then
        log_msg "${P_OK} Служба dnsmasq успешно перезапущена."
        reg_sneaky_cmd "systemctl restart dnsmasq"
        return 0
    else
        log_msg "${P_ERROR} Не удалось перезапустить службу dnsmasq."
        systemctl status dnsmasq --no-pager -l
        return 1
    fi
}

# Функция: setup_hqsrv_m2_moodle_inst_p1_services_db
# Назначение: Установка Moodle (Часть 1: Пакеты, БД, файлы).
setup_hqsrv_m2_moodle_inst_p1_services_db() {
    log_msg "${P_ACTION} Установка Moodle (Часть 1: Пакеты, БД, файлы) на HQSRV..."
    
    local moodle_req_pkgs_val="apache2 mariadb-server php8.2 apache2-mod_php8.2 php8.2-gd php8.2-curl php8.2-intl php8.2-mysqli php8.2-xml php8.2-xmlrpc php8.2-zip php8.2-soap php8.2-mbstring php8.2-opcache php8.2-json php8.2-ldap php8.2-xmlreader php8.2-fileinfo php8.2-sodium unzip curl"
    local moodle_check_cmds_val="apachectl mysql php unzip curl"
    if ! ensure_pkgs "$moodle_check_cmds_val" "$moodle_req_pkgs_val"; then
        log_msg "${P_ERROR} Не удалось установить все необходимые пакеты для Moodle."
        return 1
    fi

    if systemctl enable --now httpd2.service mysqld.service && systemctl is-active --quiet httpd2.service && systemctl is-active --quiet mysqld.service; then
        log_msg "${P_OK} Службы Apache (httpd2) и MariaDB (mysqld) включены и активны."
        reg_sneaky_cmd "systemctl enable --now httpd2.service mysqld.service"
    else
        log_msg "${P_ERROR} Ошибка при запуске или включении служб Apache/MariaDB."
        systemctl status httpd2.service mysqld.service --no-pager -l
        return 1
    fi

    local mariadb_root_pass_val; ask_param "Пароль для пользователя root MariaDB" "$m2_hqsrv_mariadb_root_pass_def" "mariadb_root_pass_val"
    
    if mysql -u root -p"$mariadb_root_pass_val" -e "SELECT 1;" &>/dev/null; then
        log_msg "${P_INFO} Пароль root для MariaDB ('${C_CYAN}$mariadb_root_pass_val${P_INFO}') уже установлен и подходит. Пропуск 'mysql_secure_installation'."
    elif mysql -u root -e "SELECT 1;" &>/dev/null; then
        log_msg "${P_INFO} Пароль root для MariaDB не установлен или не подходит. Запуск 'mysql_secure_installation'..."
        local secure_inst_script_answers_val; secure_inst_script_answers_val=$(printf '\ny\n%s\n%s\ny\ny\ny\ny\n' "$mariadb_root_pass_val" "$mariadb_root_pass_val")
        if echo -e "${secure_inst_script_answers_val}" | mysql_secure_installation; then
            log_msg "${P_OK} Скрипт 'mysql_secure_installation' успешно выполнен."
            reg_sneaky_cmd "mysql_secure_installation # (с автоматическими ответами)"
        else
            log_msg "${P_ERROR} Ошибка выполнения 'mysql_secure_installation'."; return 1
        fi
    else
        log_msg "${P_WARN} Не удалось подключиться к MariaDB как root. Возможно, пароль уже установлен и отличается."
    fi

    local moodle_db_name_val="$m2_hqsrv_moodle_db_name"
    local moodle_db_user_val="$m2_hqsrv_moodle_db_user"
    local moodle_db_pass_val; ask_param "Пароль для пользователя БД Moodle ('${moodle_db_user_val}')" "$m2_hqsrv_moodle_db_pass_def" "moodle_db_pass_val"
    
    local moodle_db_sql_cmds_val
    moodle_db_sql_cmds_val=$(cat <<EOF
CREATE DATABASE IF NOT EXISTS \`${moodle_db_name_val}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${moodle_db_user_val}'@'localhost' IDENTIFIED BY '${moodle_db_pass_val}';
GRANT ALL PRIVILEGES ON \`${moodle_db_name_val}\`.* TO '${moodle_db_user_val}'@'localhost';
FLUSH PRIVILEGES;
EOF
)
    log_msg "${P_INFO} Создание базы данных '${C_CYAN}$moodle_db_name_val${C_RESET}' и пользователя '${C_CYAN}$moodle_db_user_val${C_RESET}'..."
    if echo "$moodle_db_sql_cmds_val" | mysql -u root -p"$mariadb_root_pass_val"; then
        log_msg "${P_OK} База данных и пользователь для Moodle успешно созданы/обновлены."
        reg_sneaky_cmd "mysql -u root -p*** -e \"CREATE DATABASE ...; CREATE USER ...; GRANT ...;\""
    else
        log_msg "${P_ERROR} Ошибка при создании базы данных или пользователя для Moodle."; return 1
    fi

    log_msg "${P_INFO} Скачивание последней стабильной версии Moodle 4.0.x (stable400)..."
    local moodle_dl_zip_url_val="https://download.moodle.org/download.php/direct/stable400/moodle-latest-400.zip"
    
    if curl -L "$moodle_dl_zip_url_val" -o /tmp/moodle.zip; then
        log_msg "${P_OK} Moodle успешно скачан в /tmp/moodle.zip."
        rm -f /var/www/html/index.html
        unzip -o /tmp/moodle.zip -d /var/www/html
        if [ -d /var/www/html/moodle ]; then
            mv /var/www/html/moodle/* /var/www/html/ && rmdir /var/www/html/moodle
        fi
        chown -R apache2:apache2 /var/www/html
        rm -f /tmp/moodle.zip
        log_msg "${P_OK} Moodle распакован в /var/www/html и права установлены."
        reg_sneaky_cmd "curl -L $moodle_dl_zip_url_val -o /tmp/moodle.zip; unzip ...; chown ..."
    else
        log_msg "${P_ERROR} Ошибка скачивания или распаковки Moodle."; return 1
    fi

    mkdir -p /var/www/moodledata
    chown apache2:apache2 /var/www/moodledata
    chmod 770 /var/www/moodledata
    log_msg "${P_OK} Директория данных Moodle (/var/www/moodledata) создана и настроена."
    reg_sneaky_cmd "mkdir -p /var/www/moodledata; chown ...; chmod ..."

    local php_ini_pth_val="/etc/php/8.2/apache2-mod_php/php.ini"
    local php_max_input_vars_val="$m2_hqsrv_moodle_php_max_input_vars"
    if grep -q 'max_input_vars' "$php_ini_pth_val"; then
        sed -i "s/^[;[:space:]]*max_input_vars[[:space:]]*=.*$/max_input_vars = $php_max_input_vars_val/" "$php_ini_pth_val"
    else
        echo "max_input_vars = $php_max_input_vars_val" >> "$php_ini_pth_val"
    fi
    log_msg "${P_OK} Параметр 'max_input_vars' в ${C_CYAN}$php_ini_pth_val${C_GREEN} установлен на ${C_CYAN}$php_max_input_vars_val${C_RESET}."
    reg_sneaky_cmd "sed -i 's/max_input_vars.*/max_input_vars = $php_max_input_vars_val/' $php_ini_pth_val"

    log_msg "${P_INFO} Перезапуск Apache (httpd2) для применения настроек PHP..."
    if systemctl restart httpd2.service; then
        log_msg "${P_OK} Служба Apache (httpd2) успешно перезапущена."
        reg_sneaky_cmd "systemctl restart httpd2.service"
        return 0
    else
        log_msg "${P_ERROR} Ошибка при перезапуске службы Apache (httpd2)."; return 1
    fi
}

# Функция: setup_hqsrv_m2_moodle_inst_p2_web_setup_pmt
# Назначение: Информирует о необходимости веб-установки Moodle.
setup_hqsrv_m2_moodle_inst_p2_web_setup_pmt() {
    local vm_role_code="HQSRV"; local mod_num_val="2"
    local flag_manual_web_setup_pending_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_${FUNCNAME[0]}_pending_manual.flag"
    
    local hqsrv_ip_for_url_val; hqsrv_ip_for_url_val=$(get_ip_only "$m1_hqsrv_lan_ip")
    local moodle_db_name_pmt_val="$m2_hqsrv_moodle_db_name"
    local moodle_db_user_pmt_val="$m2_hqsrv_moodle_db_user"
    local moodle_db_pass_pmt_val; ask_param "Пароль пользователя БД Moodle ('${moodle_db_user_pmt_val}') (тот же, что и на шаге 1)" "$m2_hqsrv_moodle_db_pass_def" "moodle_db_pass_pmt_val"
    
    local moodle_site_name_pmt_val="$m2_hqsrv_moodle_site_name_def"
    local moodle_admin_pass_pmt_val="$m2_hqsrv_moodle_admin_pass_def"

    log_msg "${P_ACTION} ${C_BOLD_MAGENTA}ТРЕБУЕТСЯ РУЧНОЕ ДЕЙСТВИЕ: Веб-установка Moodle${C_RESET}"
    log_msg "${P_ACTION}   Откройте в браузере URL: ${C_CYAN}http://${hqsrv_ip_for_url_val}/${C_RESET}"
    log_msg "${P_ACTION}   Следуйте инструкциям на экране. Основные параметры:"
    log_msg "${P_ACTION}     - Язык: ${C_YELLOW}ru (Русский)${C_RESET}"
    log_msg "${P_ACTION}     - Веб-адрес: ${C_YELLOW}http://${hqsrv_ip_for_url_val}${C_RESET}"
    log_msg "${P_ACTION}     - Каталог Moodle: ${C_YELLOW}/var/www/html${C_RESET}"
    log_msg "${P_ACTION}     - Каталог данных: ${C_YELLOW}/var/www/moodledata${C_RESET}"
    log_msg "${P_ACTION}     - Драйвер базы данных: ${C_YELLOW}MariaDB (native/mysqli)${C_RESET}"
    log_msg "${P_ACTION}     - Сервер базы данных: ${C_YELLOW}localhost${C_RESET}"
    log_msg "${P_ACTION}     - Имя базы данных: ${C_YELLOW}${moodle_db_name_pmt_val}${C_RESET}"
    log_msg "${P_ACTION}     - Пользователь базы данных: ${C_YELLOW}${moodle_db_user_pmt_val}${C_RESET}"
    log_msg "${P_ACTION}     - Пароль базы данных: ${C_YELLOW}${moodle_db_pass_pmt_val}${C_RESET}"
    log_msg "${P_ACTION}     - Префикс таблиц: ${C_YELLOW}mdl_${C_RESET}"
    log_msg "${P_ACTION}   На странице настройки сайта:"
    log_msg "${P_ACTION}     - Полное имя сайта: ${C_YELLOW}${moodle_site_name_pmt_val}${C_RESET}"
    log_msg "${P_ACTION}     - Короткое имя сайта: (например, ${C_YELLOW}Площадка9${C_RESET})"
    log_msg "${P_ACTION}     - Пароль администратора: ${C_YELLOW}${moodle_admin_pass_pmt_val}${C_RESET}"
    log_msg "${P_ACTION} ${C_BOLD_YELLOW}После успешного завершения веб-установки, вернитесь в этот терминал и продолжите выполнение скрипта.${C_RESET}"
    
    touch "$flag_manual_web_setup_pending_val"
    return 2
}

# Функция: setup_hqsrv_m2_moodle_inst_p3_proxy_cfg
# Назначение: Обновляет config.php Moodle для работы через прокси.
setup_hqsrv_m2_moodle_inst_p3_proxy_cfg() {
    local vm_role_code="HQSRV"; local mod_num_val="2"
    local flag_manual_pending_prev_step_val="${FLAG_DIR_BASE}/${vm_role_code}_M${mod_num_val}_setup_hqsrv_m2_moodle_inst_p2_web_setup_pmt_pending_manual.flag"
    
    log_msg "${P_ACTION} Настройка Moodle для работы через обратный прокси (Часть 3)..."
    if [[ ! -f "/var/www/html/config.php" ]]; then
        log_msg "${P_ERROR} Файл /var/www/html/config.php не найден. Убедитесь, что веб-установка Moodle завершена."
        return 1
    fi

    local moodle_public_wwwroot_val; ask_param "Публичный WWWROOT Moodle (URL через прокси)" "$m2_hqsrv_moodle_public_wwwroot" "moodle_public_wwwroot_val"
    
    local tmp_moodle_cfg_pth_val; tmp_moodle_cfg_pth_val=$(mktemp)
    if [[ -z "$tmp_moodle_cfg_pth_val" ]]; then log_msg "${P_ERROR} Не удалось создать временный файл."; return 1; fi

    sed "s|^\$CFG->wwwroot\s*=\s*'.*';|\$CFG->wwwroot = '${moodle_public_wwwroot_val//\//\\/}';|" "/var/www/html/config.php" > "$tmp_moodle_cfg_pth_val"
    # echo "\$CFG->sslproxy = true;" >> "$tmp_moodle_cfg_pth_val"; # Если нужно

    if mv "$tmp_moodle_cfg_pth_val" "/var/www/html/config.php"; then
        log_msg "${P_OK} Параметр \$CFG->wwwroot в /var/www/html/config.php обновлен на: ${C_GREEN}$moodle_public_wwwroot_val${C_RESET}."
        reg_sneaky_cmd "sed -i 's|wwwroot.*|wwwroot = \"$moodle_public_wwwroot_val\";|' /var/www/html/config.php"
        if [[ -f "$flag_manual_pending_prev_step_val" ]]; then
            rm -f "$flag_manual_pending_prev_step_val"
            log_msg "${P_INFO} Флаг ожидания ручной веб-установки Moodle удален."
        fi
        return 0
    else
        log_msg "${P_ERROR} Ошибка при обновлении файла /var/www/html/config.php."
        rm -f "$tmp_moodle_cfg_pth_val"
        return 1
    fi
}

# --- Мета-комментарий: Конец функций-шагов для HQSRV - Модуль 2 (Сценарий: default) ---