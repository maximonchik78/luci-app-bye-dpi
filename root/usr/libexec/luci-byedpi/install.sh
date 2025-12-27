#!/bin/sh
LOG_FILE="/tmp/byedpi_install_$(date +%s).log"
REPO_API="https://api.github.com/repos/DPITrickster/ByeDPI-OpenWrt/releases/latest"
echo "=== ByeDPI Installer for OpenWrt ===" | tee "$LOG_FILE"

detect_arch() {
    if [ -f "/etc/openwrt_release" ]; then
        ARCH=$(awk -F"'" '/DISTRIB_TARGET/ {print $2}' /etc/openwrt_release 2>/dev/null)
        if [ -z "$ARCH" ]; then
            ARCH=$(awk -F"'" '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release 2>/dev/null)
        fi
        echo "Detected architecture: $ARCH" | tee -a "$LOG_FILE"
    else
        ARCH=$(uname -m)
        echo "Detected via uname: $ARCH" | tee -a "$LOG_FILE"
    fi
    case "$ARCH" in
        x86_64|x86-64|x64) ARCH="x86_64" ;;
        aarch64|arm64) ARCH="aarch64" ;;
        armv7l|armhf) ARCH="arm_cortex-a7" ;;
        mips|mipsel) ARCH="mipsel_24kc" ;;
        *) echo "Warning: Unknown architecture $ARCH" | tee -a "$LOG_FILE" ;;
    esac
    echo "Normalized architecture: $ARCH" | tee -a "$LOG_FILE"
    echo "$ARCH"
}

detect_version() {
    if [ -f "/etc/os-release" ]; then
        VERSION=$(grep 'OPENWRT_VERSION' /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1)
    elif [ -f "/etc/openwrt_release" ]; then
        VERSION=$(awk -F"'" '/DISTRIB_RELEASE/ {print $2}' /etc/openwrt_release)
    else
        VERSION="snapshot"
    fi
    MAJOR_VERSION=$(echo "$VERSION" | cut -d'.' -f1)
    if [ "$MAJOR_VERSION" -ge 24 ]; then
        echo "$MAJOR_VERSION"
    else
        echo "24"
    fi
}

main() {
    echo "🔍 Detecting system parameters..." | tee -a "$LOG_FILE"
    ARCH=$(detect_arch)
    VERSION=$(detect_version)
    echo "📦 Build parameters:" | tee -a "$LOG_FILE"
    echo "  Architecture: $ARCH" | tee -a "$LOG_FILE"
    echo "  OpenWrt version: $VERSION.x" | tee -a "$LOG_FILE"
    echo "  Date: $(date)" | tee -a "$LOG_FILE"
    echo "🌐 Checking latest ByeDPI release..." | tee -a "$LOG_FILE"
    LATEST_RELEASE=$(curl -s -H "Accept: application/vnd.github.v3+json" "$REPO_API")
    if [ -z "$LATEST_RELEASE" ]; then
        echo "❌ Error: Failed to get release info" | tee -a "$LOG_FILE"
        exit 1
    fi
    ASSET_URL=$(echo "$LATEST_RELEASE" | \
        grep -o "browser_download_url.*byedpi.*${ARCH}.*\.ipk" | \
        cut -d'"' -f4 | \
        head -1)
    if [ -z "$ASSET_URL" ]; then
        echo "⚠️  Exact package not found, looking for universal..." | tee -a "$LOG_FILE"
        ASSET_URL=$(echo "$LATEST_RELEASE" | \
            grep -o 'browser_download_url.*byedpi.*\.ipk' | \
            cut -d'"' -f4 | \
            head -1)
    fi
    if [ -z "$ASSET_URL" ]; then
        echo "❌ Error: No suitable ByeDPI package found" | tee -a "$LOG_FILE"
        echo "Available assets:" | tee -a "$LOG_FILE"
        echo "$LATEST_RELEASE" | grep 'browser_download_url' | cut -d'"' -f4 | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "📥 Downloading package: $ASSET_URL" | tee -a "$LOG_FILE"
    cd /tmp
    wget --timeout=30 --tries=3 -O byedpi.ipk "$ASSET_URL"
    if [ $? -eq 0 ]; then
        echo "✅ Package downloaded successfully" | tee -a "$LOG_FILE"
        echo "📦 Size: $(du -h byedpi.ipk | cut -f1)" | tee -a "$LOG_FILE"
    else
        echo "❌ Package download failed" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "⚙️  Installing ByeDPI..." | tee -a "$LOG_FILE"
    opkg install byedpi.ipk 2>&1 | tee -a "$LOG_FILE"
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ ByeDPI installed successfully!" | tee -a "$LOG_FILE"
        if [ ! -f "/etc/config/byedpi" ]; then
            uci set byedpi.settings=settings
            uci set byedpi.settings.strategy="-1 -2 --http-version 1.1"
            uci set byedpi.settings.enabled="1"
            uci commit byedpi
            echo "⚙️  Configuration created" | tee -a "$LOG_FILE"
        fi
        ln -sf /usr/bin/byedpi /usr/sbin/byedpi 2>/dev/null || true
        echo "🎉 Installation completed successfully!" | tee -a "$LOG_FILE"
        echo "📋 Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
        echo ""
        echo "=== STATUS ==="
        echo "ByeDPI installed at: $(which byedpi 2>/dev/null || echo 'Not found')"
        echo "Config: /etc/config/byedpi"
        echo "Default strategy: $(uci get byedpi.settings.strategy 2>/dev/null || echo 'Not set')"
    else
        echo "❌ Package installation failed" | tee -a "$LOG_FILE"
        echo "Check dependencies:" | tee -a "$LOG_FILE"
        opkg info byedpi.ipk | tee -a "$LOG_FILE"
        exit 1
    fi
}
main
