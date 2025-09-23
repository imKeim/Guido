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
    "HQ_SRV:1:Базовая сеть, SSH, DNS-сервер"
    "BR_SRV:1:Базовая сеть, SSH, DNS-клиент"
    "HQ_RTR:1:Базовая сеть, VLAN, GRE, OSPF, DHCP"
    "BR_RTR:1:Базовая сеть, GRE, OSPF, DNS-клиент"
    "HQ_CLI:1:Этап 1: Временный IP, перезагрузка"
    "HQ_CLI:1:Этап 2: DHCP-клиент, DNS"
    "--- Модуль 2 ---"
    "HQ_RTR:2:NTP-сервер, Nginx, DNAT"
    "BR_RTR:2:NTP-клиент, DNAT"
    "HQ_SRV:2:NTP-клиент, RAID, NFS, Moodle"
    "BR_SRV:2:NTP-клиент, Samba DC, Ansible, Docker MediaWiki"
    "HQ_CLI:2:Этап 1: NTP, Ввод в домен, перезагрузка"
    "HQ_CLI:2:Этап 2: Дом. каталоги, Sudo, NFS, Браузер"
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

# Сценарий для HQ_RTR - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_HQ_RTR_M1=(
    "setup_hq_rtr_m1_hn"
    "setup_hq_rtr_m1_net_ifaces_wan_lan_trunk"
    "setup_hq_rtr_m1_ip_forwarding"
    "setup_hq_rtr_m1_net_restart_base_ip"
    "setup_hq_rtr_m1_iptables_nat_mss"
    "setup_hq_rtr_m1_user_net_admin"
    "setup_hq_rtr_m1_vlans"
    "setup_hq_rtr_m1_net_restart_vlans"
    "setup_hq_rtr_m1_gre_tunnel"
    "setup_hq_rtr_m1_net_restart_gre"
    "setup_hq_rtr_m1_tz"
    "setup_hq_rtr_m1_dns_cli_final"
    "setup_hq_rtr_m1_dhcp_srv"
    "setup_hq_rtr_m1_ospf"
)

# Сценарий для BR_RTR - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_BR_RTR_M1=(
    "setup_br_rtr_m1_hn"
    "setup_br_rtr_m1_net_ifaces_wan_lan"
    "setup_br_rtr_m1_ip_forwarding"
    "setup_br_rtr_m1_net_restart_base_ip"
    "setup_br_rtr_m1_iptables_nat_mss"
    "setup_br_rtr_m1_user_net_admin"
    "setup_br_rtr_m1_gre_tunnel"
    "setup_br_rtr_m1_net_restart_gre"
    "setup_br_rtr_m1_tz"
    "setup_br_rtr_m1_dns_cli_final"
    "setup_br_rtr_m1_ospf"
)

# Сценарий для HQ_SRV - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_HQ_SRV_M1=(
    "setup_hq_srv_m1_hn"
    "setup_hq_srv_m1_net_iface"
    "setup_hq_srv_m1_net_restart_base_ip"
    "setup_hq_srv_m1_user_sshuser"
    "setup_hq_srv_m1_ssh_srv"
    "setup_hq_srv_m1_tz"
    "setup_hq_srv_m1_dns_srv"
    "setup_hq_srv_m1_net_restart_dns_update"
)

# Сценарий для BR_SRV - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_BR_SRV_M1=(
    "setup_br_srv_m1_hn"
    "setup_br_srv_m1_net_iface"
    "setup_br_srv_m1_net_restart_base_ip"
    "setup_br_srv_m1_user_sshuser"
    "setup_br_srv_m1_ssh_srv"
    "setup_br_srv_m1_tz"
    "setup_br_srv_m1_dns_cli_final"
    "setup_br_srv_m1_net_restart_dns_update"
)

# Сценарий для HQ_CLI - Модуль 1
# shellcheck disable=SC2034
declare -ag SCN_HQ_CLI_M1=(
    "setup_hq_cli_m1_hn"
    "setup_hq_cli_m1_tmp_static_ip"
    "setup_hq_cli_m1_net_restart_static_ip"
    "setup_hq_cli_m1_init_reboot_after_static_ip"
    "setup_hq_cli_m1_dhcp_cli_cfg"
    "setup_hq_cli_m1_net_restart_dhcp"
    "setup_hq_cli_m1_dns_cli_final"
    "setup_hq_cli_m1_tz"
)

# --- Сценарии для Модуля 2 ---
# shellcheck disable=SC2034
SCN_ISP_M2=()

# shellcheck disable=SC2034
declare -ag SCN_HQ_RTR_M2=(
    "setup_hq_rtr_m2_ntp_srv"
    "setup_hq_rtr_m2_nginx_reverse_proxy"
    "setup_hq_rtr_m2_dnat_ssh_to_hq_srv"
)

# shellcheck disable=SC2034
declare -ag SCN_BR_RTR_M2=(
    "setup_br_rtr_m2_ntp_cli"
    "setup_br_rtr_m2_dnat_wiki_ssh_to_br_srv"
)

# shellcheck disable=SC2034
declare -ag SCN_HQ_SRV_M2=(
    "setup_hq_srv_m2_ntp_cli"
    "setup_hq_srv_m2_ssh_srv_port_update"
    "setup_hq_srv_m2_raid_nfs_srv"
    "setup_hq_srv_m2_dns_forwarding_for_ad"
    "setup_hq_srv_m2_moodle_inst_p1_services_db"
    "setup_hq_srv_m2_moodle_inst_p2_web_setup_pmt"
    "setup_hq_srv_m2_moodle_inst_p3_proxy_cfg"
)

# shellcheck disable=SC2034
declare -ag SCN_BR_SRV_M2=(
    "setup_br_srv_m2_ntp_cli"
    "setup_br_srv_m2_ssh_srv_port_update"
    "setup_br_srv_m2_samba_dc_inst_provision"
    "setup_br_srv_m2_samba_dc_kerberos_dns_crontab"
    "setup_br_srv_m2_samba_dc_create_users_groups"
    "setup_br_srv_m2_samba_dc_import_users_csv"
    "setup_br_srv_m2_ansible_inst_ssh_key_gen"
    "setup_br_srv_m2_ansible_ssh_copy_id_pmt"
    "setup_br_srv_m2_ansible_cfg_files"
    "setup_br_srv_m2_docker_mediawiki_inst_p1_compose_up"
    "setup_br_srv_m2_docker_mediawiki_inst_p2_web_setup_pmt"
    "setup_br_srv_m2_docker_mediawiki_inst_p3_apply_localsettings"
)

# shellcheck disable=SC2034
declare -ag SCN_HQ_CLI_M2=(
    "setup_hq_cli_m2_yabrowser_inst_bg"
    "setup_hq_cli_m2_ntp_cli"
    "setup_hq_cli_m2_ssh_srv_en"
    "setup_hq_cli_m2_samba_ad_join"
    "setup_hq_cli_m2_init_reboot_after_ad_join"
    "setup_hq_cli_m2_create_domain_user_homedirs"
    "setup_hq_cli_m2_sudo_for_domain_group"
    "setup_hq_cli_m2_nfs_cli_mount"
    "setup_hq_cli_m2_wait_yabrowser_inst"
    "setup_hq_cli_m2_copy_localsettings_to_brsrv_pmt"
)

# --- Мета-комментарий: Конец определений сценариев для "default" ---
