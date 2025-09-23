#!/bin/bash
# Файл: scenarios/default_cfg.sh
# Содержит переменные конфигурации модулей для сценария ДЭ "default".
# Этот файл подключается (source) основным скриптом Guido.

# --- Мета-комментарий: Переменные конфигурации для сценария "default" ---

# === Блок: Параметры конфигурации для Модуля 1 (Сценарий: default) ===

# --- Общие для Модуля 1 ---
m1_ospf_auth_key_def='P@$$word'                   # Ключ аутентификации OSPF по умолчанию.

# --- ISP - Модуль 1 ---
m1_isp_wan_iface="ens18"                          # WAN-интерфейс ISP.
m1_isp_to_hq_rtr_iface="ens19"                     # Интерфейс ISP к HQ_RTR.
m1_isp_to_hq_rtr_ip="172.16.4.1/28"                # IP-адрес ISP на интерфейсе к HQ_RTR.
m1_isp_to_br_rtr_iface="ens20"                     # Интерфейс ISP к BR_RTR.
m1_isp_to_br_rtr_ip="172.16.5.1/28"                # IP-адрес ISP на интерфейсе к BR_RTR.

# --- HQ-RTR - Модуль 1 ---
m1_hq_rtr_wan_iface="ens18"                        # WAN-интерфейс HQ_RTR.
m1_hq_rtr_wan_ip="172.16.4.4/28"                   # IP-адрес WAN HQ_RTR.
m1_hq_rtr_wan_gw="172.16.4.1"                      # Шлюз WAN HQ_RTR.
m1_hq_rtr_lan_trunk_iface="ens19"                  # LAN Trunk интерфейс HQ_RTR.
m1_hq_rtr_vlan_srv_id="100"                        # VLAN ID для серверной сети HQ.
m1_hq_rtr_vlan_srv_ip="192.168.1.1/26"             # IP-адрес HQ_RTR в VLAN серверов.
m1_hq_rtr_vlan_cli_id="200"                        # VLAN ID для клиентской сети HQ.
m1_hq_rtr_vlan_cli_ip="192.168.2.1/28"             # IP-адрес HQ_RTR в VLAN клиентов.
m1_hq_rtr_vlan_mgmt_id_def="999"                   # VLAN ID для сети управления по умолчанию.
m1_hq_rtr_vlan_mgmt_ip_def="192.168.99.1/29"       # IP-адрес HQ_RTR в VLAN управления.
m1_hq_rtr_gre_iface="gre1"                         # Имя GRE-интерфейса на HQ_RTR.
m1_hq_rtr_gre_remote_ip_var="172.16.5.5"           # Удаленный IP для GRE-туннеля (WAN IP BR_RTR).
m1_hq_rtr_gre_tunnel_ip="192.168.5.1/30"           # IP-адрес GRE-туннеля на HQ_RTR.
m1_hq_rtr_dhcp_range_start_def="192.168.2.2"       # Начальный IP DHCP-диапазона на HQ_RTR.
m1_hq_rtr_dhcp_range_end_def="192.168.2.14"        # Конечный IP DHCP-диапазона на HQ_RTR.
m1_hq_rtr_dhcp_subnet_mask_def="255.255.255.240"   # Маска подсети для DHCP-диапазона.

# --- BR-RTR - Модуль 1 ---
m1_br_rtr_wan_iface="ens18"                        # WAN-интерфейс BR_RTR.
m1_br_rtr_wan_ip="172.16.5.5/28"                   # IP-адрес WAN BR_RTR.
m1_br_rtr_wan_gw="172.16.5.1"                      # Шлюз WAN BR_RTR.
m1_br_rtr_lan_iface="ens19"                        # LAN-интерфейс BR_RTR.
m1_br_rtr_lan_ip="192.168.3.1/27"                  # IP-адрес LAN BR_RTR.
m1_br_rtr_gre_iface="gre1"                         # Имя GRE-интерфейса на BR_RTR.
m1_br_rtr_gre_remote_ip_var="172.16.4.4"           # Удаленный IP для GRE-туннеля (WAN IP HQ_RTR).
m1_br_rtr_gre_tunnel_ip="192.168.5.2/30"           # IP-адрес GRE-туннеля на BR_RTR.

# --- HQ-SRV - Модуль 1 ---
m1_hq_srv_lan_iface="ens18"                        # LAN-интерфейс HQ_SRV.
m1_hq_srv_lan_ip="192.168.1.10/26"                 # IP-адрес LAN HQ_SRV.
m1_hq_srv_lan_gw="192.168.1.1"                     # Шлюз LAN HQ_SRV.
m1_hq_srv_dns_cname_moodle="moodle.$DOM_NAME"      # CNAME для Moodle.
m1_hq_srv_dns_cname_wiki="wiki.$DOM_NAME"          # CNAME для Wiki.

# --- BR-SRV - Модуль 1 ---
m1_br_srv_lan_iface="ens18"                        # LAN-интерфейс BR_SRV.
m1_br_srv_lan_ip="192.168.3.10/27"                 # IP-адрес LAN BR_SRV.
m1_br_srv_lan_gw="192.168.3.1"                     # Шлюз LAN BR_SRV.

# --- HQ-CLI - Модуль 1 ---
m1_hq_cli_lan_iface="ens18"                        # LAN-интерфейс HQ_CLI.
m1_hq_cli_tmp_static_ip="192.168.2.10/28"          # Временный статический IP для HQ_CLI.
m1_hq_cli_tmp_static_gw="192.168.2.1"              # Временный статический шлюз для HQ_CLI.
m1_hq_cli_dhcp_cli_id_def="hq-cli-exam-id"         # DHCP Client ID для HQ_CLI по умолчанию.
m1_hq_cli_dhcp_reserved_ip_def="192.168.2.10"      # Резервируемый IP для HQ_CLI по умолчанию.

# === Блок: Параметры конфигурации для Модуля 2 (Сценарий: default) ===

# --- HQ-RTR - Модуль 2 ---
m2_nginx_moodle_backend_port="80"                 # Порт бэкенда Moodle на HQ_SRV.
m2_nginx_wiki_backend_port_def="8080"             # Порт бэкенда Wiki на BR_SRV по умолчанию.
m2_dnat_hq_rtr_to_hq_srv_ssh_port_var="$DEF_SSH_PORT" # Порт для DNAT SSH на HQ_SRV (использует DEF_SSH_PORT).
m2_dnat_br_rtr_to_br_srv_wiki_ext_port_def="80"     # Внешний порт для DNAT Wiki на BR_SRV.
m2_dnat_br_rtr_to_br_srv_ssh_port_var="$DEF_SSH_PORT" # Порт для DNAT SSH на BR_SRV.

# --- HQ-SRV - Модуль 2 ---
m2_hq_srv_raid_level_def="5"                       # Уровень RAID по умолчанию для HQ_SRV.
m2_hq_srv_raid_dev_name="md0"                      # Имя RAID-устройства на HQ_SRV.
m2_hq_srv_raid_disks_def="/dev/sdb /dev/sdc /dev/sdd" # Диски для RAID по умолчанию.
m2_hq_srv_raid_mount_point_base="/raid"            # Базовая точка монтирования для RAID.
m2_hq_srv_nfs_export_subdir="nfs"                  # Поддиректория для NFS-экспорта на RAID.
m2_hq_srv_moodle_db_name="moodledb"                # Имя БД Moodle.
m2_hq_srv_moodle_db_user="moodle"                  # Пользователь БД Moodle.
m2_hq_srv_moodle_db_pass_def='P@ssw0rd'            # Пароль пользователя БД Moodle по умолчанию.
m2_hq_srv_mariadb_root_pass_def='P@ssw0rd'         # Пароль root для MariaDB по умолчанию.
m2_hq_srv_moodle_site_name_def="ДЕ_Площадка_9"     # Название сайта Moodle по умолчанию.
m2_hq_srv_moodle_admin_pass_def='P@ssw0rd'         # Пароль администратора Moodle по умолчанию.
m2_hq_srv_moodle_public_wwwroot="http://moodle.$DOM_NAME" # Публичный URL Moodle (через прокси).
m2_hq_srv_moodle_php_max_input_vars="5000"         # Значение max_input_vars для PHP Moodle.

# --- BR-SRV - Модуль 2 ---
m2_br_srv_samba_realm_upper="$DOM_NAME"            # Kerberos Realm для Samba AD (в верхнем регистре).
m2_br_srv_samba_domain_netbios="AU-TEAM"           # NetBIOS-имя домена Samba AD.
m2_br_srv_samba_admin_pass_def='P@ssw0rd'          # Пароль администратора Samba AD по умолчанию.
m2_br_srv_samba_user_hq_pass_def='P@ssw0rdHQ'      # Пароль для пользователей userX.hq по умолчанию.
m2_br_srv_samba_csv_user_pass_def='P@ssw0rd1'      # Пароль для пользователей из CSV по умолчанию.
m2_br_srv_ansible_ssh_key_pth="/root/.ssh/id_rsa"  # Путь к SSH-ключу Ansible.
m2_br_srv_ansible_hq_srv_user="sshuser"             # Пользователь Ansible для HQ_SRV.
m2_br_srv_ansible_hq_cli_user="user"                # Пользователь Ansible для HQ_CLI.
m2_br_srv_ansible_hq_cli_pass_def='resu'            # Пароль пользователя Ansible для HQ_CLI по умолчанию.
m2_br_srv_ansible_rtr_user="net_admin"             # Пользователь Ansible для маршрутизаторов.
m2_br_srv_docker_wiki_dbvolume_name="dbvolume"     # Имя Docker-volume для БД MediaWiki.
m2_br_srv_docker_wiki_imagesvolume_name="images"   # Имя Docker-volume для изображений MediaWiki.
m2_br_srv_docker_compose_pth="/home/sshuser/wiki.yml" # Путь к файлу docker-compose для MediaWiki.
m2_br_srv_wiki_db_user="wiki"                      # Пользователь БД MediaWiki.
m2_br_srv_wiki_db_pass_def='WikiP@ssword'          # Пароль пользователя БД MediaWiki по умолчанию.
m2_br_srv_wiki_localsettings_pth_on_brsrv="/home/sshuser/LocalSettings.php" # Путь к LocalSettings.php на BR_SRV.
m2_wiki_site_name="Моя Вики ДЭ"                   # Название сайта MediaWiki.
m2_wiki_admin_user="WikiAdminDE"                  # Имя администратора MediaWiki.

# --- HQ-CLI - Модуль 2 ---
m2_hq_cli_samba_admin_user="administrator"         # Имя администратора домена для ввода HQ_CLI.
m2_hq_cli_nfs_mount_point="/mnt/nfs"               # Точка монтирования NFS на HQ_CLI.
m2_hq_cli_sudo_group_name="hq"                     # Имя доменной группы для sudo на HQ_CLI.
m2_hq_cli_sudo_allowed_cmds="/bin/cat, /bin/grep, /usr/bin/id" # Разрешенные команды sudo.
m2_hq_cli_yabrowser_pkg_name="yandex-browser-stable" # Имя пакета Яндекс.Браузера.
m2_hq_cli_localsettings_download_pth_def="/home/user/Downloads/LocalSettings.php" # Путь для скачивания LocalSettings.php.

# --- Мета-комментарий: Конец переменных конфигурации для сценария "default" ---
