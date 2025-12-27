#!/bin/sh
# Утилиты для ByeDPI на OpenWrt 24.x

# Проверка поддержки OpenWrt версии
check_openwrt_version() {
    local min_version="${1:-24}"
    local current_version
    
    if [ -f "/etc/os-release" ]; then
        current_version=$(grep 'OPENWRT_VERSION' /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1 | cut -d'.' -f1)
    elif [ -f "/etc/openwrt_release" ]; then
        current_version=$(awk -F"'" '/DISTRIB_RELEASE/ {print $2}' /etc/openwrt_release | cut -d'.' -f1)
    else
        current_version=0
    fi
    
    if [ "$current_version" -ge "$min_version" ]; then
        return 0
    else
        echo "❌ Требуется OpenWrt $min_version.x или новее. Текущая версия: $current_version"
        return 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    local deps="curl wget uci"
    local missing=""
    
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing="$missing $dep"
        fi
    done
    
    if [ -n "$missing" ]; then
        echo "⚠️  Отсутствующие зависимости:$missing"
        echo "Установите: opkg install$missing"
        return 1
    fi
    
    return 0
}

# Получение статуса ByeDPI
get_byedpi_status() {
    local pid
    local strategy
    local status="stopped"
    
    # Проверяем процесс
    if pgrep -f "byedpi" >/dev/null 2>&1; then
        pid=$(pgrep -f "byedpi")
        status="running (PID: $pid)"
    fi
    
    # Получаем текущую стратегию
    strategy=$(uci get byedpi.settings.strategy 2>/dev/null || echo "не установлена")
    
    cat <<EOF
Статус: $status
Стратегия: $strategy
Конфигурация: /etc/config/byedpi
Лог: /tmp/byedpi.log
EOF
}
