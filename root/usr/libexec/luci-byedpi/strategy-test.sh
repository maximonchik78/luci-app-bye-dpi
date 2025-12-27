#!/bin/sh
# Автоподбор стратегий ByeDPI

SITES=$(echo "$1" | tr ',' ' ')
TEST_DIR="/tmp/byedpi_test"
LOG_FILE="/tmp/byedpi_strategy_test_$(date +%s).log"

mkdir -p "$TEST_DIR"

echo "=== ByeDPI Strategy Testing ===" | tee "$LOG_FILE"
echo "Test sites: $SITES" | tee -a "$LOG_FILE"
echo "Start time: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Базовые стратегии
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
    "--http-method POST --http-version 1.1"
    "-1 --ttl 64"
    "-2 --ttl 64"
    "-1 -2 --ttl 64"
    "-1 -2 -3"
    "-1 -2 -4"
    "--http-version 1.0"
    "--http-version 1.1"
)

echo "Testing ${#STRATEGIES[@]} strategies" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

RESULTS=""
SUCCESSFUL_STRATEGIES=0

for strategy in "${STRATEGIES[@]}"; do
    echo "Testing: $strategy" | tee -a "$LOG_FILE"
    success_count=0
    
    # Проверяем, запущен ли ByeDPI
    if ! pgrep -f "byedpi" >/dev/null 2>&1; then
        echo "  Starting ByeDPI with strategy: $strategy" | tee -a "$LOG_FILE"
        byedpi $strategy > /tmp/byedpi_test.log 2>&1 &
        TEST_PID=$!
        sleep 3
    fi
    
    for site in $SITES; do
        site=$(echo "$site" | xargs)
        if [ -z "$site" ]; then
            continue
        fi
        
        echo "  Checking: $site" | tee -a "$LOG_FILE"
        
        # Проверка через ByeDPI
        timeout 10 curl -s -I "https://$site" --socks5-hostname 127.0.0.1:1080 >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            success_count=$((success_count + 1))
            echo "    ✓ Success" | tee -a "$LOG_FILE"
        else
            echo "    ✗ Failed" | tee -a "$LOG_FILE"
        fi
        
        sleep 1
    done
    
    # Останавливаем тестовый процесс
    if [ -n "$TEST_PID" ]; then
        kill $TEST_PID 2>/dev/null
        wait $TEST_PID 2>/dev/null
    fi
    
    # Вычисляем процент успеха
    total_sites=$(echo "$SITES" | wc -w)
    if [ "$total_sites" -gt 0 ]; then
        success_percent=$((success_count * 100 / total_sites))
    else
        success_percent=0
    fi
    
    echo "  Success rate: $success_percent%" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    if [ $success_percent -ge 50 ]; then
        RESULTS="$RESULTS\nStrategy: $strategy - Success: $success_percent%"
        SUCCESSFUL_STRATEGIES=$((SUCCESSFUL_STRATEGIES + 1))
    fi
done

echo "=== TEST RESULTS ===" | tee -a "$LOG_FILE"
if [ -n "$RESULTS" ]; then
    echo -e "$RESULTS" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "Successful strategies found: $SUCCESSFUL_STRATEGIES" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "RECOMMENDATION: Use strategy with highest success rate." | tee -a "$LOG_FILE"
    echo "Copy command from 'Strategy' column and paste into custom strategy field." | tee -a "$LOG_FILE"
else
    echo "No strategies with success rate above 50% found." | tee -a "$LOG_FILE"
    echo "Try different test sites or check your connection." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "End time: $(date)" | tee -a "$LOG_FILE"
echo "Full log: $LOG_FILE" | tee -a "$LOG_FILE"

# Вывод результатов в консоль
if [ -n "$RESULTS" ]; then
    echo -e "$RESULTS"
fi
