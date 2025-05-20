#!/bin/bash
# Файл: scenarios/default_scn.sh
# Содержит определения последовательностей шагов (массивы SCN_*)
# и основную последовательность выполнения (MAIN_SCN_SEQ) для сценария ДЭ "default".
# Этот файл подключается (source) основным скриптом Guido.

# --- Мета-комментарий: Определения сценариев для "default" ---

# === Блок: Основная последовательность выполнения ("Чемпионский путь") ===
# shellcheck disable=SC2034
declare -ag MAIN_SCN_SEQ=(
    "--- Модуль 1 ---"
    "ISP:1:Базовая сеть, NAT"
    "HQSRV:1:Базовая сеть, SSH, DNS-сервер"
    "BRSRV:1:Базовая сеть, SSH, DNS-клиент"
    "HQRTR:1:Базовая сеть, VLAN, GRE, OSPF, DHCP"
    "BRRTR:1:Базовая сеть, GRE, OSPF, DNS-клиент"
    "HQCLI:1:Этап 1: Временный IP, перезагрузка"
    "HQCLI:1:Этап 2: DHCP-клиент, DNS"
    "--- Модуль 2 ---"
    "HQRTR:2:NTP-сервер, Nginx, DNAT"
    "BRRTR:2:NTP-клиент, DNAT"
    "HQSRV:2:NTP-клиент, RAID, NFS, Moodle"
    "BRSRV:2:NTP-клиент, Samba DC, Ansible, Docker MediaWiki"
    "HQCLI:2:Этап 1: NTP, Ввод в домен, перезагрузка"
    "HQCLI:2:Этап 2: Дом. каталоги, Sudo, NFS, Браузер"
)

# === Блок: Определение сценариев выполнения для модулей и ролей ВМ (Сценарий: default) ===

# Сценарий для ISP - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_ISP_M1=(
    "setup_isp_m1_hn"
    "setup_isp_m1_net_ifaces"
    "setup_isp_m1_ip_forwarding"
    "setup_isp_m1_net_restart_init"
    "setup_isp_m1_iptables_nat"
    "setup_isp_m1_tz"
)

# Сценарий для HQRTR - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_HQRTR_M1=(
    "setup_hqrtr_m1_hn"
    "setup_hqrtr_m1_net_ifaces_wan_lan_trunk"
    "setup_hqrtr_m1_ip_forwarding"
    "setup_hqrtr_m1_net_restart_base_ip"
    "setup_hqrtr_m1_iptables_nat_mss"
    "setup_hqrtr_m1_user_net_admin"
    "setup_hqrtr_m1_vlans"
    "setup_hqrtr_m1_net_restart_vlans"
    "setup_hqrtr_m1_gre_tunnel"
    "setup_hqrtr_m1_net_restart_gre"
    "setup_hqrtr_m1_tz"
    "setup_hqrtr_m1_dns_cli_final"
    "setup_hqrtr_m1_dhcp_srv"
    "setup_hqrtr_m1_ospf"
)

# Сценарий для BRRTR - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_BRRTR_M1=(
    "setup_brrtr_m1_hn"
    "setup_brrtr_m1_net_ifaces_wan_lan"
    "setup_brrtr_m1_ip_forwarding"
    "setup_brrtr_m1_net_restart_base_ip"
    "setup_brrtr_m1_iptables_nat_mss"
    "setup_brrtr_m1_user_net_admin"
    "setup_brrtr_m1_gre_tunnel"
    "setup_brrtr_m1_net_restart_gre"
    "setup_brrtr_m1_tz"
    "setup_brrtr_m1_dns_cli_final"
    "setup_brrtr_m1_ospf"
)

# Сценарий для HQSRV - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_HQSRV_M1=(
    "setup_hqsrv_m1_hn"
    "setup_hqsrv_m1_net_iface"
    "setup_hqsrv_m1_net_restart_base_ip"
    "setup_hqsrv_m1_user_sshuser"
    "setup_hqsrv_m1_ssh_srv"
    "setup_hqsrv_m1_tz"
    "setup_hqsrv_m1_dns_srv"
    "setup_hqsrv_m1_net_restart_dns_update"
)

# Сценарий для BRSRV - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_BRSRV_M1=(
    "setup_brsrv_m1_hn"
    "setup_brsrv_m1_net_iface"
    "setup_brsrv_m1_net_restart_base_ip"
    "setup_brsrv_m1_user_sshuser"
    "setup_brsrv_m1_ssh_srv"
    "setup_brsrv_m1_tz"
    "setup_brsrv_m1_dns_cli_final"
    "setup_brsrv_m1_net_restart_dns_update"
)

# Сценарий для HQCLI - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_HQCLI_M1=(
    "setup_hqcli_m1_hn"
    "setup_hqcli_m1_tmp_static_ip"
    "setup_hqcli_m1_net_restart_static_ip"
    "setup_hqcli_m1_init_reboot_after_static_ip"
    "setup_hqcli_m1_dhcp_cli_cfg"
    "setup_hqcli_m1_net_restart_dhcp"
    "setup_hqcli_m1_dns_cli_final"
    "setup_hqcli_m1_tz"
)

# --- Сценарии для Модуля 2 ---
# shellcheck disable=SC2034
SCN_ISP_M2=()

# shellcheck disable=SC2034
declare -ag SCN_HQRTR_M2=(
    "setup_hqrtr_m2_ntp_srv"
    "setup_hqrtr_m2_nginx_reverse_proxy"
    "setup_hqrtr_m2_dnat_ssh_to_hqsrv"
)

# shellcheck disable=SC2034
declare -ag SCN_BRRTR_M2=(
    "setup_brrtr_m2_ntp_cli"
    "setup_brrtr_m2_dnat_wiki_ssh_to_brsrv"
)

# shellcheck disable=SC2034
declare -ag SCN_HQSRV_M2=(
    "setup_hqsrv_m2_ntp_cli"
    "setup_hqsrv_m2_ssh_srv_port_update"
    "setup_hqsrv_m2_raid_nfs_srv"
    "setup_hqsrv_m2_dns_forwarding_for_ad"
    "setup_hqsrv_m2_moodle_inst_p1_services_db"
    "setup_hqsrv_m2_moodle_inst_p2_web_setup_pmt"
    "setup_hqsrv_m2_moodle_inst_p3_proxy_cfg"
)

# shellcheck disable=SC2034
declare -ag SCN_BRSRV_M2=(
    "setup_brsrv_m2_ntp_cli"
    "setup_brsrv_m2_ssh_srv_port_update"
    "setup_brsrv_m2_samba_dc_inst_provision"
    "setup_brsrv_m2_samba_dc_kerberos_dns_crontab"
    "setup_brsrv_m2_samba_dc_create_users_groups"
    "setup_brsrv_m2_samba_dc_import_users_csv"
    "setup_brsrv_m2_ansible_inst_ssh_key_gen"
    "setup_brsrv_m2_ansible_ssh_copy_id_pmt"
    "setup_brsrv_m2_ansible_cfg_files"
    "setup_brsrv_m2_docker_mediawiki_inst_p1_compose_up"
    "setup_brsrv_m2_docker_mediawiki_inst_p2_web_setup_pmt"
    "setup_brsrv_m2_docker_mediawiki_inst_p3_apply_localsettings"
)

# shellcheck disable=SC2034
declare -ag SCN_HQCLI_M2=(
    "setup_hqcli_m2_yabrowser_inst_bg"
    "setup_hqcli_m2_ntp_cli"
    "setup_hqcli_m2_ssh_srv_en"
    "setup_hqcli_m2_samba_ad_join"
    "setup_hqcli_m2_init_reboot_after_ad_join"
    "setup_hqcli_m2_create_domain_user_homedirs"
    "setup_hqcli_m2_sudo_for_domain_group"
    "setup_hqcli_m2_nfs_cli_mount"
    "setup_hqcli_m2_wait_yabrowser_inst"
    "setup_hqcli_m2_copy_localsettings_to_brsrv_pmt"
)

# --- Мета-комментарий: Конец определений сценариев для "default" ---