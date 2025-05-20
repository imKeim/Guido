#!/bin/bash
# Файл: core_lib/vars.sh
# Содержит глобальные переменные и константы, не специфичные для конкретного сценария ДЭ.
# Этот файл подключается (source) основным скриптом Guido.

# --- Мета-комментарий: Глобальные переменные и константы ---

# === Блок: Критически важные пути и базовые флаги ===
# SCRIPT_PTH_DEL, SCRIPT_DIR, CORE_LIB_DIR, SCENARIOS_DIR, FX_LIB_DIR определяются в guido.sh
# FLAG_DIR_BASE определяется в guido.sh

# === Блок: Параметры текущего сценария ДЭ ===
g_cur_de_scenario_name="default" # Имя текущего активного сценария ДЭ

# === Блок: Глобальные флаги управления поведением скрипта (начальные значения) ===
g_pretty_mode_en="n" # Использование цветов (pretty mode)
g_sneaky_mode_en="n" # Скрытый режим (sneaky mode)
g_log_en="n"         # Логирование включено/выключено
g_log_pth=""         # Путь к файлу лога
g_on_exit_called=0   # Флаг для предотвращения рекурсивного вызова on_exit
# shellcheck disable=SC2034
declare -ag g_sneaky_hist_cmds=() # Массив для команд, симулируемых в истории в sneaky режиме

# === Блок: Переменные для ANSI-цветов и префиксов сообщений ===
# Эти переменные инициализируются функцией init_colors_pfx().
# Объявление здесь с # shellcheck disable=SC2034 подавляет предупреждения.
# shellcheck disable=SC2034
C_RESET=''
# shellcheck disable=SC2034
C_BOLD_BLUE=''
# shellcheck disable=SC2034
C_GREEN=''
# shellcheck disable=SC2034
C_BOLD_YELLOW=''
# shellcheck disable=SC2034
C_BOLD_RED=''
# shellcheck disable=SC2034
C_CYAN=''
# shellcheck disable=SC2034
C_BOLD_MAGENTA=''
# shellcheck disable=SC2034
C_DIM=''

# shellcheck disable=SC2034
P_INFO=''
# shellcheck disable=SC2034
P_OK=''
# shellcheck disable=SC2034
P_WARN=''
# shellcheck disable=SC2034
P_ERROR=''
# shellcheck disable=SC2034
P_PROMPT=''
# shellcheck disable=SC2034
P_ACTION=''
# shellcheck disable=SC2034
P_STEP=''
# shellcheck disable=SC2034
P_CMD='' # Оставим, если планируется использовать

# === Блок: Общие сетевые параметры и параметры системы ===
# В будущем эти значения по умолчанию могут быть переопределены файлом сценария.
DOM_NAME="au-team.irpo"                          # Основное доменное имя для инфраструктуры.
# shellcheck disable=SC2034
DEF_DNS_PRIMARY="8.8.8.8"                        # Внешний DNS-сервер по умолчанию (основной).
# shellcheck disable=SC2034
DEF_DNS_SECONDARY="1.1.1.1"                      # Внешний DNS-сервер по умолчанию (запасной).
# shellcheck disable=SC2034
DEF_TZ="Asia/Vladivostok"                        # Часовой пояс по умолчанию.

# === Блок: Параметры, связанные с идентификацией текущей ВМ ===
# g_cur_vm_role и g_eff_hn_for_role будут установлены в основном скрипте.
# shellcheck disable=SC2034
declare -A EXPECTED_FQDNS                        # Ассоциативный массив ожидаемых FQDN для каждой роли.
EXPECTED_FQDNS["isp"]="isp.$DOM_NAME"
EXPECTED_FQDNS["hqrtr"]="hq-rtr.$DOM_NAME"
EXPECTED_FQDNS["brrtr"]="br-rtr.$DOM_NAME"
EXPECTED_FQDNS["hqsrv"]="hq-srv.$DOM_NAME"
EXPECTED_FQDNS["brsrv"]="br-srv.$DOM_NAME"
EXPECTED_FQDNS["hqcli"]="hq-cli.$DOM_NAME"

# === Блок: Определения ролей ВМ ===
# shellcheck disable=SC2034
declare -ag ALL_VM_ROLES=("ISP" "HQRTR" "BRRTR" "HQSRV" "BRSRV" "HQCLI") # Упорядоченный список всех ролей.
# shellcheck disable=SC2034
declare -A VM_ROLE_DESCS=(                        # Описания для каждой роли ВМ.
    ["ISP"]="Интернет-провайдер"
    ["HQRTR"]="Маршрутизатор головного офиса"
    ["BRRTR"]="Маршрутизатор филиала"
    ["HQSRV"]="Сервер головного офиса"
    ["BRSRV"]="Сервер филиала"
    ["HQCLI"]="Клиентская машина головного офиса"
)

# === Блок: Параметры пользователей и аутентификации по умолчанию ===
# В будущем эти значения по умолчанию могут быть переопределены файлом сценария.
# shellcheck disable=SC2034
DEF_SSH_PORT="2024"                               # Порт SSH по умолчанию.
# shellcheck disable=SC2034
DEF_NET_ADMIN_UID="1010"                          # UID пользователя net_admin по умолчанию.
# shellcheck disable=SC2034
DEF_SSHUSER_UID="1010"                            # UID пользователя sshuser по умолчанию.
# shellcheck disable=SC2034
# shellcheck disable=SC2016                       # Отключаем проверку для строк с одинарными кавычками, содержащих '$'.
DEF_NET_ADMIN_PASS='P@$$word'                     # Пароль пользователя net_admin по умолчанию.
# shellcheck disable=SC2034
DEF_SSHUSER_PASS='P@ssw0rd'                       # Пароль пользователя sshuser по умолчанию.

# --- Мета-комментарий: Конец глобальных переменных и констант ---