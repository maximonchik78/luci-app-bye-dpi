# LuCI ByeDPI Manager

Универсальное Luci приложение для управления ByeDPI-OpenWrt.

## Возможности

- Автоматическая установка ByeDPI с определением архитектуры
- Автоподбор стратегий (как в ByeDPIManager)
- Управление кастомными стратегиями
- Тестирование доступности сайтов
- Полная интеграция с Luci
- Единый размер всех кнопок
- Поддержка OpenWrt 24.x и новее

## Установка

### 1. Сборка из исходников

```bash
git clone https://github.com/yourusername/luci-app-bye-dpi.git
cd luci-app-bye-dpi
# Добавьте пакет в дерево OpenWrt
cp -r . /path/to/openwrt/package/network/services/luci-app-bye-dpi
# Соберите пакет
make package/luci-app-bye-dpi/compile
