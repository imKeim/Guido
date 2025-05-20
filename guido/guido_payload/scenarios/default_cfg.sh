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
m1_isp_to_hqrtr_iface="ens19"                     # Интерфейс ISP к HQRTR.
m1_isp_to_hqrtr_ip="172.16.4.1/28"                # IP-адрес ISP на интерфейсе к HQRTR.
m1_isp_to_brrtr_iface="ens20"                     # Интерфейс ISP к BRRTR.
m1_isp_to_brrtr_ip="172.16.5.1/28"                # IP-адрес ISP на интерфейсе к BRRTR.

# --- HQ-RTR - Модуль 1 ---
m1_hqrtr_wan_iface="ens18"                        # WAN-интерфейс HQRTR.
m1_hqrtr_wan_ip="172.16.4.4/28"                   # IP-адрес WAN HQRTR.
m1_hqrtr_wan_gw="172.16.4.1"                      # Шлюз WAN HQRTR.
m1_hqrtr_lan_trunk_iface="ens19"                  # LAN Trunk интерфейс HQRTR.
m1_hqrtr_vlan_srv_id="100"                        # VLAN ID для серверной сети HQ.
m1_hqrtr_vlan_srv_ip="192.168.1.1/26"             # IP-адрес HQRTR в VLAN серверов.
m1_hqrtr_vlan_cli_id="200"                        # VLAN ID для клиентской сети HQ.
m1_hqrtr_vlan_cli_ip="192.168.2.1/28"             # IP-адрес HQRTR в VLAN клиентов.
m1_hqrtr_vlan_mgmt_id_def="999"                   # VLAN ID для сети управления по умолчанию.
m1_hqrtr_vlan_mgmt_ip_def="192.168.99.1/29"       # IP-адрес HQRTR в VLAN управления.
m1_hqrtr_gre_iface="gre1"                         # Имя GRE-интерфейса на HQRTR.
m1_hqrtr_gre_remote_ip_var="172.16.5.5"           # Удаленный IP для GRE-туннеля (WAN IP BRRTR).
m1_hqrtr_gre_tunnel_ip="192.168.5.1/30"           # IP-адрес GRE-туннеля на HQRTR.
m1_hqrtr_dhcp_range_start_def="192.168.2.2"       # Начальный IP DHCP-диапазона на HQRTR.
m1_hqrtr_dhcp_range_end_def="192.168.2.14"        # Конечный IP DHCP-диапазона на HQRTR.
m1_hqrtr_dhcp_subnet_mask_def="255.255.255.240"   # Маска подсети для DHCP-диапазона.

# --- BR-RTR - Модуль 1 ---
m1_brrtr_wan_iface="ens18"                        # WAN-интерфейс BRRTR.
m1_brrtr_wan_ip="172.16.5.5/28"                   # IP-адрес WAN BRRTR.
m1_brrtr_wan_gw="172.16.5.1"                      # Шлюз WAN BRRTR.
m1_brrtr_lan_iface="ens19"                        # LAN-интерфейс BRRTR.
m1_brrtr_lan_ip="192.168.3.1/27"                  # IP-адрес LAN BRRTR.
m1_brrtr_gre_iface="gre1"                         # Имя GRE-интерфейса на BRRTR.
m1_brrtr_gre_remote_ip_var="172.16.4.4"           # Удаленный IP для GRE-туннеля (WAN IP HQRTR).
m1_brrtr_gre_tunnel_ip="192.168.5.2/30"           # IP-адрес GRE-туннеля на BRRTR.

# --- HQ-SRV - Модуль 1 ---
m1_hqsrv_lan_iface="ens18"                        # LAN-интерфейс HQSRV.
m1_hqsrv_lan_ip="192.168.1.10/26"                 # IP-адрес LAN HQSRV.
m1_hqsrv_lan_gw="192.168.1.1"                     # Шлюз LAN HQSRV.
m1_hqsrv_dns_cname_moodle="moodle.$DOM_NAME"      # CNAME для Moodle.
m1_hqsrv_dns_cname_wiki="wiki.$DOM_NAME"          # CNAME для Wiki.

# --- BR-SRV - Модуль 1 ---
m1_brsrv_lan_iface="ens18"                        # LAN-интерфейс BRSRV.
m1_brsrv_lan_ip="192.168.3.10/27"                 # IP-адрес LAN BRSRV.
m1_brsrv_lan_gw="192.168.3.1"                     # Шлюз LAN BRSRV.

# --- HQ-CLI - Модуль 1 ---
m1_hqcli_lan_iface="ens18"                        # LAN-интерфейс HQCLI.
m1_hqcli_tmp_static_ip="192.168.2.10/28"          # Временный статический IP для HQCLI.
m1_hqcli_tmp_static_gw="192.168.2.1"              # Временный статический шлюз для HQCLI.
m1_hqcli_dhcp_cli_id_def="hq-cli-exam-id"         # DHCP Client ID для HQCLI по умолчанию.
m1_hqcli_dhcp_reserved_ip_def="192.168.2.10"      # Резервируемый IP для HQCLI по умолчанию.

# === Блок: Параметры конфигурации для Модуля 2 (Сценарий: default) ===

# --- HQ-RTR - Модуль 2 ---
m2_nginx_moodle_backend_port="80"                 # Порт бэкенда Moodle на HQSRV.
m2_nginx_wiki_backend_port_def="8080"             # Порт бэкенда Wiki на BRSRV по умолчанию.
m2_dnat_hqrtr_to_hqsrv_ssh_port_var="$DEF_SSH_PORT" # Порт для DNAT SSH на HQSRV (использует DEF_SSH_PORT).
m2_dnat_brrtr_to_brsrv_wiki_ext_port_def="80"     # Внешний порт для DNAT Wiki на BRSRV.
m2_dnat_brrtr_to_brsrv_ssh_port_var="$DEF_SSH_PORT" # Порт для DNAT SSH на BRSRV.

# --- HQ-SRV - Модуль 2 ---
m2_hqsrv_raid_level_def="5"                       # Уровень RAID по умолчанию для HQSRV.
m2_hqsrv_raid_dev_name="md0"                      # Имя RAID-устройства на HQSRV.
m2_hqsrv_raid_disks_def="/dev/sdb /dev/sdc /dev/sdd" # Диски для RAID по умолчанию.
m2_hqsrv_raid_mount_point_base="/raid"            # Базовая точка монтирования для RAID.
m2_hqsrv_nfs_export_subdir="nfs"                  # Поддиректория для NFS-экспорта на RAID.
m2_hqsrv_moodle_db_name="moodledb"                # Имя БД Moodle.
m2_hqsrv_moodle_db_user="moodle"                  # Пользователь БД Moodle.
m2_hqsrv_moodle_db_pass_def='P@ssw0rd'            # Пароль пользователя БД Moodle по умолчанию.
m2_hqsrv_mariadb_root_pass_def='P@ssw0rd'         # Пароль root для MariaDB по умолчанию.
m2_hqsrv_moodle_site_name_def="ДЕ_Площадка_9"     # Название сайта Moodle по умолчанию.
m2_hqsrv_moodle_admin_pass_def='P@ssw0rd'         # Пароль администратора Moodle по умолчанию.
m2_hqsrv_moodle_public_wwwroot="http://moodle.$DOM_NAME" # Публичный URL Moodle (через прокси).
m2_hqsrv_moodle_php_max_input_vars="5000"         # Значение max_input_vars для PHP Moodle.

# --- BR-SRV - Модуль 2 ---
m2_brsrv_samba_realm_upper="$DOM_NAME"            # Kerberos Realm для Samba AD (в верхнем регистре).
m2_brsrv_samba_domain_netbios="AU-TEAM"           # NetBIOS-имя домена Samba AD.
m2_brsrv_samba_admin_pass_def='P@ssw0rd'          # Пароль администратора Samba AD по умолчанию.
m2_brsrv_samba_user_hq_pass_def='P@ssw0rdHQ'      # Пароль для пользователей userX.hq по умолчанию.
m2_brsrv_samba_csv_user_pass_def='P@ssw0rd1'      # Пароль для пользователей из CSV по умолчанию.
m2_brsrv_ansible_ssh_key_pth="/root/.ssh/id_rsa"  # Путь к SSH-ключу Ansible.
m2_brsrv_ansible_hqsrv_user="sshuser"             # Пользователь Ansible для HQSRV.
m2_brsrv_ansible_hqcli_user="user"                # Пользователь Ansible для HQCLI.
m2_brsrv_ansible_hqcli_pass_def='resu'            # Пароль пользователя Ansible для HQCLI по умолчанию.
m2_brsrv_ansible_rtr_user="net_admin"             # Пользователь Ansible для маршрутизаторов.
m2_brsrv_docker_wiki_dbvolume_name="dbvolume"     # Имя Docker-volume для БД MediaWiki.
m2_brsrv_docker_wiki_imagesvolume_name="images"   # Имя Docker-volume для изображений MediaWiki.
m2_brsrv_docker_compose_pth="/home/sshuser/wiki.yml" # Путь к файлу docker-compose для MediaWiki.
m2_brsrv_wiki_db_user="wiki"                      # Пользователь БД MediaWiki.
m2_brsrv_wiki_db_pass_def='WikiP@ssword'          # Пароль пользователя БД MediaWiki по умолчанию.
m2_brsrv_wiki_localsettings_pth_on_brsrv="/home/sshuser/LocalSettings.php" # Путь к LocalSettings.php на BRSRV.
m2_wiki_site_name="Моя Вики ДЭ"                   # Название сайта MediaWiki.
m2_wiki_admin_user="WikiAdminDE"                  # Имя администратора MediaWiki.

# --- HQ-CLI - Модуль 2 ---
m2_hqcli_samba_admin_user="administrator"         # Имя администратора домена для ввода HQCLI.
m2_hqcli_nfs_mount_point="/mnt/nfs"               # Точка монтирования NFS на HQCLI.
m2_hqcli_sudo_group_name="hq"                     # Имя доменной группы для sudo на HQCLI.
m2_hqcli_sudo_allowed_cmds="/bin/cat, /bin/grep, /usr/bin/id" # Разрешенные команды sudo.
m2_hqcli_yabrowser_pkg_name="yandex-browser-stable" # Имя пакета Яндекс.Браузера.
m2_hqcli_localsettings_download_pth_def="/home/user/Downloads/LocalSettings.php" # Путь для скачивания LocalSettings.php.

# --- Мета-комментарий: Конец переменных конфигурации для сценария "default" ---