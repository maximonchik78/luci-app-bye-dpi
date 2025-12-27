#!/bin/sh
# Автоматически определяет архитектуру и устанавливает ByeDPI

LOG_FILE="/tmp/byedpi_install.log"
REPO_URL="https://github.com/DPITrickster/ByeDPI-OpenWrt/releases/latest"
echo "=== Начало установки ByeDPI ===" > "$LOG_FILE"

# Определение архитектуры как в Podkop-Manager (аналогично StressOzz)
detect_arch() {
    if [ -f "/etc/openwrt_release" ]; then
        ARCH=$(awk -F"'" '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release)
        echo "Обнаружена архитектура из openwrt_release: $ARCH" >> "$LOG_FILE"
    else
        ARCH=$(uname -m)
        echo "Определение через uname -m: $ARCH" >> "$LOG_FILE"
        # Приведение к стандартным названиям OpenWrt
        case "$ARCH" in
            "x86_64") ARCH="x86_64" ;;
            "aarch64") ARCH="aarch64" ;;
            "armv7l") ARCH="arm_cortex-a9" ;;
            "mips") ARCH="mips_24kc" ;;
            *) ARCH="unknown" ;;
        esac
    fi
    echo "$ARCH"
}

ARCH=$(detect_arch)
echo "Используемая архитектура: $ARCH" >> "$LOG_FILE"

# Определение версии OpenWrt
if [ -f "/etc/openwrt_release" ]; then
    VERSION=$(awk -F"'" '/DISTRIB_RELEASE/ {print $2}' /etc/openwrt_release | cut -d. -f1,2)
    echo "Версия OpenWrt: $VERSION" >> "$LOG_FILE"
else
    VERSION="snapshot"
fi

# Формирование URL для загрузки (на основе структуры релизов из URL)
DOWNLOAD_URL=""
case "$VERSION" in
    "24.10"|"23.05"|"22.03"|"21.02"|"19.07")
        PKG_NAME="byedpi_${ARCH}_for_openwrt_${VERSION}.ipk"
        # Пытаемся найти соответствующий пакет в релизах
        LATEST_TAG=$(curl -s "https://api.github.com/repos/DPITrickster/ByeDPI-OpenWrt/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
        if [ -n "$LATEST_TAG" ]; then
            DOWNLOAD_URL="https://github.com/DPITrickster/ByeDPI-OpenWrt/releases/download/${LATEST_TAG}/byedpi_${ARCH}.ipk"
        fi
        ;;
    *)
        echo "Неизвестная версия OpenWrt, попытка найти универсальный пакет" >> "$LOG_FILE"
        DOWNLOAD_URL="https://github.com/DPITrickster/ByeDPI-OpenWrt/releases/latest/download/byedpi_${ARCH}.ipk"
        ;;
esac

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Не удалось сформировать URL для загрузки. Проверьте определение архитектуры." >> "$LOG_FILE"
    exit 1
fi

echo "Скачивание пакета с: $DOWNLOAD_URL" >> "$LOG_FILE"
cd /tmp
if wget -q --timeout=30 --tries=3 "$DOWNLOAD_URL" -O byedpi.ipk; then
    echo "Установка пакета..." >> "$LOG_FILE"
    opkg install byedpi.ipk >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        echo "SUCCESS: ByeDPI успешно установлен!" >> "$LOG_FILE"
        # Инициализация конфигурации
        uci set byedpi.settings.strategy="-1 -2 --http-version 1.1" 2>/dev/null
        uci commit byedpi 2>/dev/null
        echo "Конфигурация инициализирована" >> "$LOG_FILE"
    else
        echo "ERROR: Ошибка установки пакета" >> "$LOG_FILE"
        exit 1
    fi
else
    echo "ERROR: Не удалось скачать пакет" >> "$LOG_FILE"
    exit 1
fi

cat "$LOG_FILE"
