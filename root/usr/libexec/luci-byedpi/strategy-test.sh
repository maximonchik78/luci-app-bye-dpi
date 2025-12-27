#!/bin/sh
# Автоподбор стратегий как в ByeDPIManager и ByeByeDPI

SITES=$(echo "$1" | tr ',' ' ') # Сайты для проверки через запятую
TEST_DIR="/tmp/byedpi_test"
mkdir -p "$TEST_DIR"

# Базовые стратегии из ByeDPIManager и оригинального ByeDPI
STRATEGIES=(
    "-1"
    "-2"
    "-3"
    "-4"
    "-1 -2"
    "-1 -3"
    "-2 -3"
    "-1 --http-version 1.1"
    "-2 --http-version 1.1"
    "-1 -2 --http-version 1.1"
    "--ttl 64 --http-version 1.1"
    "--http-method GET --http-version 1.0"
)

echo "=== Начало тестирования стратегий ==="
echo "Проверяемые сайты: $SITES"
echo "Тестируемые стратегии: ${#STRATEGIES[@]} вариантов"
echo ""

RESULTS=""
for strategy in "${STRATEGIES[@]}"; do
    echo "Тестирование: $strategy"
    success_count=0
    
    for site in $SITES; do
        # Запускаем ByeDPI с тестовой стратегией и проверяем доступность сайта
        timeout 10 curl -s -I "https://$site" --socks5-hostname 127.0.0.1:1080 >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            success_count=$((success_count + 1))
        fi
        sleep 1
    done
    
    # Вычисляем процент успеха как в ByeDPIManager
    total_sites=$(echo "$SITES" | wc -w)
    success_percent=$((success_count * 100 / total_sites))
    
    if [ $success_percent -ge 50 ]; then
        RESULTS="$RESULTS\nСтратегия: $strategy - Успех: $success_percent%"
        echo "  Успех: $success_percent%" >> /tmp/byedpi_test.log
    fi
done

echo "=== РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ ==="
if [ -n "$RESULTS" ]; then
    echo -e "$RESULTS"
    echo ""
    echo "РЕКОМЕНДАЦИЯ: Используйте стратегию с наивысшим процентом успеха."
    echo "Скопируйте команду из колонки 'Стратегия' и вставьте в поле кастомной стратегии."
else
    echo "Не найдено стратегий с успехом более 50%."
    echo "Попробуйте другие сайты для проверки или проверьте подключение."
fi
