#!/bin/sh
# Установка ByeDPI для OpenWrt 24.x и новее
# Автоматическое определение архитектуры и версии

LOG_FILE="/tmp/byedpi_install_$(date +%s).log"
REPO_API="https://api.github.com/repos/DPITrickster/ByeDPI-OpenWrt/releases/latest"
REPO_URL="https://github.com/DPITrickster/ByeDPI-OpenWrt"

echo "=== ByeDPI Installer for OpenWrt 24.x ===" | tee "$LOG_FILE"

# Функция определения архитектуры для OpenWrt 24.x
detect_arch() {
    if [ -f "/etc/openwrt_release" ]; then
        # Для OpenWrt 24.x используем новый формат
        ARCH=$(awk -F"'" '/DISTRIB_TARGET/ {print $2}' /etc/openwrt_release 2>/dev/null)
        if [ -z "$ARCH" ]; then
            ARCH=$(awk -F"'" '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release 2>/dev/null)
        fi
        echo "Обнаружена архитектура OpenWrt: $ARCH" | tee -a "$LOG_FILE"
    else
        # Fallback для нестандартных систем
        ARCH=$(uname -m)
        echo "Определение через uname -m: $ARCH" | tee -a "$LOG_FILE"
    fi
    
    # Конвертация в формат пакетов OpenWrt 24.x
    case "$ARCH" in
        x86_64|x86-64|x64)
            ARCH="x86_64"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        armv7l|armhf)
            ARCH="arm_cortex-a7"  # или arm_cortex-a9 в зависимости от устройства
            ;;
        mips|mipsel)
            ARCH="mipsel_24kc"
            ;;
        *)
            echo "Предупреждение: Неизвестная архитектура $ARCH" | tee -a "$LOG_FILE"
            ;;
    esac
    
    echo "Нормализованная архитектура: $ARCH" | tee -a "$LOG_FILE"
    echo "$ARCH"
}

# Функция определения версии OpenWrt
detect_version() {
    if [ -f "/etc/os-release" ]; then
        VERSION=$(grep 'OPENWRT_VERSION' /etc/os-release | cut -d'"' -f2 | cut -d' ' -f1)
    elif [ -f "/etc/openwrt_release" ]; then
        VERSION=$(awk -F"'" '/DISTRIB_RELEASE/ {print $2}' /etc/openwrt_release)
    else
        VERSION="snapshot"
    fi
    
    # Определяем мажорную версию (24, 25 и т.д.)
    MAJOR_VERSION=$(echo "$VERSION" | cut -d'.' -f1)
    
    # Для OpenWrt 24.x и новее
    if [ "$MAJOR_VERSION" -ge 24 ]; then
        echo "$MAJOR_VERSION"
    else
        echo "24"  # Минимальная поддерживаемая версия
    fi
}

# Основная установка
main() {
    echo "🔍 Определение параметров системы..." | tee -a "$LOG_FILE"
    
    ARCH=$(detect_arch)
    VERSION=$(detect_version)
    
    echo "📦 Параметры сборки:" | tee -a "$LOG_FILE"
    echo "  Архитектура: $ARCH" | tee -a "$LOG_FILE"
    echo "  Версия OpenWrt: $VERSION.x" | tee -a "$LOG_FILE"
    echo "  Дата: $(date)" | tee -a "$LOG_FILE"
    
    # Получаем информацию о последнем релизе
    echo "🌐 Проверка последнего релиза ByeDPI..." | tee -a "$LOG_FILE"
    LATEST_RELEASE=$(curl -s -H "Accept: application/vnd.github.v3+json" "$REPO_API")
    
    if [ -z "$LATEST_RELEASE" ]; then
        echo "❌ Ошибка: Не удалось получить информацию о релизах" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Ищем подходящий пакет для нашей архитектуры и версии
    ASSET_URL=$(echo "$LATEST_RELEASE" | \
        grep -o "browser_download_url.*byedpi.*${ARCH}.*\.ipk" | \
        cut -d'"' -f4 | \
        grep -v "19.07\|21.02\|22.03\|23.05" | \
        head -1)
    
    # Если не нашли точное совпадение, пробуем найти универсальный
    if [ -z "$ASSET_URL" ]; then
        echo "⚠️  Точный пакет не найден, ищем универсальный..." | tee -a "$LOG_FILE"
        ASSET_URL=$(echo "$LATEST_RELEASE" | \
            grep -o 'browser_download_url.*byedpi.*\.ipk' | \
            cut -d'"' -f4 | \
            head -1)
    fi
    
    if [ -z "$ASSET_URL" ]; then
        echo "❌ Ошибка: Не найден подходящий пакет ByeDPI" | tee -a "$LOG_FILE"
        echo "Доступные ассеты:" | tee -a "$LOG_FILE"
        echo "$LATEST_RELEASE" | grep 'browser_download_url' | cut -d'"' -f4 | tee -a "$LOG_FILE"
        exit 1
    fi
    
    echo "📥 Скачивание пакета: $ASSET_URL" | tee -a "$LOG_FILE"
    
    # Скачиваем пакет
    cd /tmp
    wget --timeout=30 --tries=3 -O byedpi.ipk "$ASSET_URL"
    
    if [ $? -eq 0 ]; then
        echo "✅ Пакет успешно скачан" | tee -a "$LOG_FILE"
        echo "📦 Размер: $(du -h byedpi.ipk | cut -f1)" | tee -a "$LOG_FILE"
    else
        echo "❌ Ошибка скачивания пакета" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Устанавливаем пакет
    echo "⚙️  Установка ByeDPI..." | tee -a "$LOG_FILE"
    opkg install byedpi.ipk 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo "✅ ByeDPI успешно установлен!" | tee -a "$LOG_FILE"
        
        # Настраиваем конфигурацию
        if [ ! -f "/etc/config/byedpi" ]; then
            uci set byedpi.settings=settings
            uci set byedpi.settings.strategy="-1 -2 --http-version 1.1"
            uci set byedpi.settings.enabled="1"
            uci commit byedpi
            echo "⚙️  Конфигурация создана" | tee -a "$LOG_FILE"
        fi
        
        # Создаем симлинк для удобства
        ln -sf /usr/bin/byedpi /usr/sbin/byedpi 2>/dev/null || true
        
        echo "🎉 Установка завершена успешно!" | tee -a "$LOG_FILE"
        echo "📋 Лог сохранен в: $LOG_FILE" | tee -a "$LOG_FILE"
        
        # Показываем статус
        echo ""
        echo "=== СТАТУС ==="
        echo "ByeDPI установлен: $(which byedpi 2>/dev/null || echo 'Не найден')"
        echo "Конфиг: /etc/config/byedpi"
        echo "Стратегия по умолчанию: $(uci get byedpi.settings.strategy 2>/dev/null || echo 'Не установлена')"
        
    else
        echo "❌ Ошибка установки пакета" | tee -a "$LOG_FILE"
        echo "Проверьте зависимости:" | tee -a "$LOG_FILE"
        opkg info byedpi.ipk | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Запуск с обработкой ошибок
main "$@"
