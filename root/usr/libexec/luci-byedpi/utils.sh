#!/bin/sh
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
        echo "❌ Requires OpenWrt $min_version.x or newer. Current: $current_version"
        return 1
    fi
}

check_dependencies() {
    local deps="curl wget uci"
    local missing=""
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing="$missing $dep"
        fi
    done
    if [ -n "$missing" ]; then
        echo "⚠️  Missing dependencies:$missing"
        echo "Install: opkg install$missing"
        return 1
    fi
    return 0
}

get_byedpi_status() {
    local pid
    local strategy
    local status="stopped"
    if pgrep -f "byedpi" >/dev/null 2>&1; then
        pid=$(pgrep -f "byedpi")
        status="running (PID: $pid)"
    fi
    strategy=$(uci get byedpi.settings.strategy 2>/dev/null || echo "not set")
    cat <<EOF
Status: $status
Strategy: $strategy
Configuration: /etc/config/byedpi
Log: /tmp/byedpi.log
EOF
}

check_site_access() {
    local site="$1"
    local timeout="${2:-10}"
    if [ -z "$site" ]; then
        echo "Usage: check_site_access <site> [timeout]"
        return 1
    fi
    site=$(echo "$site" | sed 's|^https\?://||' | sed 's|/.*$||')
    echo "Checking access to: $site"
    echo "Through ByeDPI:"
    timeout "$timeout" curl -s -I "https://$site" --socks5-hostname 127.0.0.1:1080 2>&1 | head -1
    echo "Direct connection:"
    timeout "$timeout" curl -s -I "https://$site" 2>&1 | head -1
}

cleanup_logs() {
    rm -f /tmp/byedpi_*.log 2>/dev/null
    > /tmp/byedpi.log
    echo "Logs cleaned up"
}

get_system_info() {
    echo "=== System Information ==="
    if [ -f "/etc/openwrt_release" ]; then
        echo "OpenWrt Release:"
        cat /etc/openwrt_release
    fi
    echo ""
    echo "Architecture: $(uname -m)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime)"
    if command -v opkg >/dev/null 2>&1; then
        echo ""
        echo "ByeDPI package:"
        opkg list-installed | grep byedpi || echo "Not installed"
    fi
}
