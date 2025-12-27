module("luci.controller.byedpi", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/byedpi") then
        -- Создаем начальную конфигурацию
        luci.sys.call("touch /etc/config/byedpi")
        luci.sys.call("uci set byedpi.settings=settings")
        luci.sys.call("uci set byedpi.settings.strategy='-1 -2 --http-version 1.1'")
        luci.sys.call("uci set byedpi.settings.enabled='0'")
        luci.sys.call("uci set byedpi.settings.auto_update='1'")
        luci.sys.call("uci commit byedpi")
    end
    
    entry({"admin", "services", "byedpi"}, firstchild(), _("ByeDPI Manager"), 60).dependent = false
    entry({"admin", "services", "byedpi", "overview"}, cbi("byedpi/overview"), _("Overview"), 10)
    entry({"admin", "services", "byedpi", "install"}, cbi("byedpi/install"), _("Install/Update"), 20)
    entry({"admin", "services", "byedpi", "strategies"}, cbi("byedpi/strategies"), _("Strategies"), 30)
    entry({"admin", "services", "byedpi", "settings"}, cbi("byedpi/settings"), _("Settings"), 40)
    entry({"admin", "services", "byedpi", "logs"}, cbi("byedpi/logs"), _("Logs"), 50)
    
    -- AJAX endpoints для управления
    entry({"admin", "services", "byedpi", "api", "status"}, call("api_status")).leaf = true
    entry({"admin", "services", "byedpi", "api", "install"}, call("api_install")).leaf = true
    entry({"admin", "services", "byedpi", "api", "test"}, call("api_test_strategies")).leaf = true
    entry({"admin", "services", "byedpi", "api", "apply"}, call("api_apply_strategy")).leaf = true
    entry({"admin", "services", "byedpi", "api", "start"}, call("api_start")).leaf = true
    entry({"admin", "services", "byedpi", "api", "stop"}, call("api_stop")).leaf = true
    entry({"admin", "services", "byedpi", "api", "restart"}, call("api_restart")).leaf = true
    entry({"admin", "services", "byedpi", "api", "uninstall"}, call("api_uninstall")).leaf = true
    entry({"admin", "services", "byedpi", "api", "get_log"}, call("api_get_log")).leaf = true
    entry({"admin", "services", "byedpi", "api", "clear_log"}, call("api_clear_log")).leaf = true
    entry({"admin", "services", "byedpi", "api", "check_update"}, call("api_check_update")).leaf = true
    entry({"admin", "services", "byedpi", "api", "save_config"}, call("api_save_config")).leaf = true
    entry({"admin", "services", "byedpi", "api", "test_site"}, call("api_test_site")).leaf = true
end

function api_status()
    local result = {
        installed = false,
        running = false,
        pid = 0,
        strategy = "",
        version = "unknown",
        architecture = "unknown",
        openwrt_version = "unknown",
        last_checked = "never"
    }
    
    -- Проверяем установлен ли ByeDPI
    if nixio.fs.access("/usr/bin/byedpi") or nixio.fs.access("/usr/sbin/byedpi") then
        result.installed = true
    end
    
    -- Проверяем запущен ли процесс
    local pid = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null | head -1")
    if pid and pid:match("%d+") then
        result.running = true
        result.pid = tonumber(pid) or 0
    end
    
    -- Получаем текущую стратегию
    result.strategy = luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null | head -1") or ""
    
    -- Получаем версию ByeDPI
    local version_output = luci.sys.exec("byedpi --version 2>/dev/null | head -1")
    if version_output and #version_output > 0 then
        result.version = version_output:gsub("%s+", " ")
    end
    
    -- Определяем архитектуру
    if nixio.fs.access("/etc/openwrt_release") then
        result.architecture = luci.sys.exec("awk -F\"'\" '/DISTRIB_TARGET/ {print $2}' /etc/openwrt_release 2>/dev/null") or
                             luci.sys.exec("awk -F\"'\" '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release 2>/dev/null") or
                             "unknown"
        result.architecture = result.architecture:gsub("%s+", "")
    end
    
    -- Определяем версию OpenWrt
    if nixio.fs.access("/etc/os-release") then
        result.openwrt_version = luci.sys.exec("grep 'OPENWRT_VERSION' /etc/os-release 2>/dev/null | cut -d'\"' -f2 | cut -d' ' -f1") or
                                luci.sys.exec("awk -F\"'\" '/DISTRIB_RELEASE/ {print $2}' /etc/openwrt_release 2>/dev/null") or
                                "unknown"
        result.openwrt_version = result.openwrt_version:gsub("%s+", "")
    end
    
    -- Время последней проверки обновлений
    local last_check = luci.sys.exec("uci get byedpi.settings.last_update_check 2>/dev/null")
    if last_check and #last_check > 0 then
        result.last_checked = last_check
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

function api_install()
    local log_file = "/tmp/byedpi_install_" .. os.time() .. ".log"
    local command = "/usr/libexec/luci-byedpi/install.sh 2>&1 | tee " .. log_file
    
    luci.http.prepare_content("application/json")
    
    -- Запускаем установку в фоне
    local pid = luci.sys.exec("(" .. command .. ") > /dev/null 2>&1 & echo $!")
    
    if pid and pid:match("%d+") then
        luci.http.write_json({
            success = true,
            pid = tonumber(pid),
            message = "Установка запущена в фоне",
            log_file = log_file
        })
    else
        luci.http.write_json({
            success = false,
            message = "Не удалось запустить установку"
        })
    end
end

function api_test_strategies()
    local sites = luci.http.formvalue("sites") or "youtube.com,twitter.com,instagram.com"
    local log_file = "/tmp/byedpi_strategy_test_" .. os.time() .. ".log"
    
    -- Экранируем кавычки и специальные символы
    sites = sites:gsub('"', '\\"'):gsub("'", "'\"'\"'")
    
    local command = string.format('/usr/libexec/luci-byedpi/strategy-test.sh "%s" 2>&1 | tee %s', sites, log_file)
    
    luci.http.prepare_content("application/json")
    
    -- Запускаем тестирование в фоне
    local pid = luci.sys.exec("(" .. command .. ") > /dev/null 2>&1 & echo $!")
    
    if pid and pid:match("%d+") then
        luci.http.write_json({
            success = true,
            pid = tonumber(pid),
            message = "Тестирование стратегий запущено",
            log_file = log_file,
            test_sites = sites
        })
    else
        luci.http.write_json({
            success = false,
            message = "Не удалось запустить тестирование"
        })
    end
end

function api_apply_strategy()
    local strategy = luci.http.formvalue("strategy") or ""
    
    -- Проверяем, что стратегия не пустая
    if #strategy == 0 then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            success = false,
            message = "Стратегия не может быть пустой"
        })
        return
    end
    
    -- Экранируем кавычки для безопасности
    strategy = strategy:gsub('"', '\\"')
    
    -- Сохраняем стратегию в конфигурации
    local result = luci.sys.exec(string.format('uci set byedpi.settings.strategy="%s" && uci commit byedpi', strategy))
    
    luci.http.prepare_content("application/json")
    
    if result and #result == 0 then
        luci.http.write_json({
            success = true,
            message = "Стратегия успешно применена",
            strategy = strategy
        })
    else
        luci.http.write_json({
            success = false,
            message = "Ошибка при применении стратегии: " .. (result or "неизвестная ошибка")
        })
    end
end

function api_start()
    local strategy = luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or "-1 -2 --http-version 1.1"
    strategy = strategy:gsub("%s+$", ""):gsub("^%s+", "")
    
    -- Проверяем, не запущен ли уже ByeDPI
    local pid = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null | head -1")
    if pid and pid:match("%d+") then
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            success = false,
            message = "ByeDPI уже запущен (PID: " .. pid .. ")",
            pid = tonumber(pid)
        })
        return
    end
    
    -- Запускаем ByeDPI
    local command = string.format("byedpi %s > /tmp/byedpi.log 2>&1 &", strategy)
    local result = luci.sys.exec(command)
    
    -- Даем время процессу запуститься
    luci.sys.exec("sleep 1")
    
    -- Проверяем запустился ли процесс
    pid = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null | head -1")
    
    luci.http.prepare_content("application/json")
    
    if pid and pid:match("%d+") then
        -- Обновляем статус в конфиге
        luci.sys.exec("uci set byedpi.settings.enabled='1' && uci commit byedpi")
        
        luci.http.write_json({
            success = true,
            message = "ByeDPI успешно запущен",
            pid = tonumber(pid),
            strategy = strategy,
            command = command
        })
    else
        luci.http.write_json({
            success = false,
            message = "Не удалось запустить ByeDPI. Проверьте логи: /tmp/byedpi.log",
            command = command
        })
    end
end

function api_stop()
    -- Находим и останавливаем все процессы byedpi
    local pids = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null")
    
    if pids and #pids > 0 then
        -- Останавливаем процессы
        luci.sys.exec("pkill -f 'byedpi' 2>/dev/null")
        
        -- Даем время процессам завершиться
        luci.sys.exec("sleep 2")
        
        -- Проверяем, что процессы остановлены
        local still_running = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null")
        
        -- Обновляем статус в конфиге
        luci.sys.exec("uci set byedpi.settings.enabled='0' && uci commit byedpi")
        
        luci.http.prepare_content("application/json")
        
        if still_running and #still_running > 0 then
            -- Если процессы все еще есть, форсируем завершение
            luci.sys.exec("pkill -9 -f 'byedpi' 2>/dev/null")
            
            luci.http.write_json({
                success = true,
                message = "ByeDPI принудительно остановлен (использован SIGKILL)",
                killed_pids = pids
            })
        else
            luci.http.write_json({
                success = true,
                message = "ByeDPI успешно остановлен",
                killed_pids = pids
            })
        end
    else
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            success = false,
            message = "ByeDPI не запущен"
        })
    end
end

function api_restart()
    -- Сначала останавливаем
    api_stop()
    
    -- Даем время для полной остановки
    luci.sys.exec("sleep 2")
    
    -- Затем запускаем
    api_start()
end

function api_uninstall()
    -- Останавливаем ByeDPI если запущен
    luci.sys.exec("pkill -f 'byedpi' 2>/dev/null")
    luci.sys.exec("sleep 1")
    
    -- Удаляем пакет
    local result = luci.sys.exec("opkg remove --force-remove byedpi 2>&1")
    
    -- Удаляем конфигурацию
    luci.sys.exec("rm -f /etc/config/byedpi")
    
    -- Удаляем симлинки
    luci.sys.exec("rm -f /usr/sbin/byedpi 2>/dev/null")
    
    luci.http.prepare_content("application/json")
    
    if result:find("No packages removed") then
        luci.http.write_json({
            success = false,
            message = "ByeDPI не установлен или не может быть удален",
            output = result
        })
    else
        luci.http.write_json({
            success = true,
            message = "ByeDPI успешно удален",
            output = result
        })
    end
end

function api_get_log()
    local log_type = luci.http.formvalue("type") or "install"
    local lines = tonumber(luci.http.formvalue("lines")) or 100
    
    local log_file = ""
    
    if log_type == "install" then
        -- Ищем последний лог установки
        local files = luci.sys.exec("ls -t /tmp/byedpi_install_*.log 2>/dev/null | head -1")
        log_file = files:gsub("%s+", "")
    elseif log_type == "strategy" then
        -- Ищем последний лог тестирования стратегий
        local files = luci.sys.exec("ls -t /tmp/byedpi_strategy_test_*.log 2>/dev/null | head -1")
        log_file = files:gsub("%s+", "")
    elseif log_type == "service" then
        log_file = "/tmp/byedpi.log"
    else
        log_file = log_type
    end
    
    local content = ""
    
    if nixio.fs.access(log_file) then
        -- Читаем последние N строк лога
        content = luci.sys.exec(string.format("tail -n %d '%s' 2>/dev/null", lines, log_file))
        
        -- Если файл слишком большой, добавляем предупреждение
        local size = luci.sys.exec(string.format("wc -l '%s' 2>/dev/null | awk '{print $1}'", log_file))
        size = tonumber(size) or 0
        
        if size > lines then
            content = string.format("... показаны последние %d строк из %d ...\n\n", lines, size) .. content
        end
    else
        content = "Лог файл не найден: " .. log_file
    end
    
    luci.http.prepare_content("text/plain")
    luci.http.write(content)
end

function api_clear_log()
    local log_type = luci.http.formvalue("type") or "service"
    
    if log_type == "service" then
        luci.sys.exec("> /tmp/byedpi.log")
    elseif log_type == "all" then
        luci.sys.exec("rm -f /tmp/byedpi_*.log 2>/dev/null")
        luci.sys.exec("> /tmp/byedpi.log")
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = true,
        message = "Логи очищены"
    })
end

function api_check_update()
    -- Получаем текущую версию
    local current_version = luci.sys.exec("byedpi --version 2>/dev/null | head -1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+'") or "0.0.0"
    current_version = current_version:gsub("%s+", "")
    
    -- Проверяем последнюю версию на GitHub
    local latest_version = luci.sys.exec("curl -s 'https://api.github.com/repos/DPITrickster/ByeDPI-OpenWrt/releases/latest' | grep 'tag_name' | cut -d'\"' -f4")
    
    if latest_version and #latest_version > 0 then
        latest_version = latest_version:gsub("^v", ""):gsub("%s+", "")
        
        -- Сохраняем время проверки
        luci.sys.exec(string.format('uci set byedpi.settings.last_update_check="%s" && uci commit byedpi', os.date("%Y-%m-%d %H:%M:%S")))
        
        -- Сравниваем версии
        local needs_update = false
        local cv_parts = {}
        local lv_parts = {}
        
        for part in current_version:gmatch("%d+") do
            table.insert(cv_parts, tonumber(part))
        end
        
        for part in latest_version:gmatch("%d+") do
            table.insert(lv_parts, tonumber(part))
        end
        
        -- Простое сравнение версий
        if #cv_parts == 3 and #lv_parts == 3 then
            for i = 1, 3 do
                if lv_parts[i] > cv_parts[i] then
                    needs_update = true
                    break
                elseif lv_parts[i] < cv_parts[i] then
                    break
                end
            end
        end
        
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            success = true,
            current_version = current_version,
            latest_version = latest_version,
            needs_update = needs_update,
            update_available = needs_update,
            message = needs_update and "Доступно обновление" or "У вас актуальная версия"
        })
    else
        luci.http.prepare_content("application/json")
        luci.http.write_json({
            success = false,
            message = "Не удалось проверить обновления",
            error = "Network error"
        })
    end
end

function api_save_config()
    local config = {}
    
    -- Получаем все параметры из запроса
    for key in pairs(luci.http.formvalue()) do
        if key ~= "token" then
            local value = luci.http.formvalue(key)
            config[key] = value
            
            -- Сохраняем в конфигурации
            if key:match("^byedpi%.") then
                local uci_key = key:gsub("byedpi%.", "")
                local section, option = uci_key:match("([^%.]+)%.([^%.]+)")
                
                if section and option then
                    luci.sys.exec(string.format('uci set byedpi.%s.%s="%s"', section, option, value))
                end
            end
        end
    end
    
    -- Применяем изменения
    luci.sys.exec("uci commit byedpi")
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = true,
        message = "Конфигурация сохранена",
        config = config
    })
end

function api_test_site()
    local site = luci.http.formvalue("site") or "youtube.com"
    local timeout = tonumber(luci.http.formvalue("timeout")) or 10
    
    -- Экранируем URL
    site = site:gsub("^https?://", ""):gsub("/.*$", "")
    
    -- Проверяем доступность сайта через ByeDPI если он запущен
    local command = string.format("timeout %d curl -s -I 'https://%s' --socks5-hostname 127.0.0.1:1080 2>&1 | head -1", timeout, site)
    local result = luci.sys.exec(command)
    
    local success = false
    local http_code = "0"
    
    if result:match("HTTP/[0-9%.]+ 2[0-9][0-9]") then
        success = true
        http_code = result:match("HTTP/[0-9%.]+ ([0-9][0-9][0-9])")
    elseif result:match("HTTP/[0-9%.]+") then
        http_code = result:match("HTTP/[0-9%.]+ ([0-9][0-9][0-9])")
    end
    
    -- Проверяем также без ByeDPI для сравнения
    local command_direct = string.format("timeout %d curl -s -I 'https://%s' 2>&1 | head -1", timeout, site)
    local result_direct = luci.sys.exec(command_direct)
    
    local direct_success = false
    local direct_http_code = "0"
    
    if result_direct:match("HTTP/[0-9%.]+ 2[0-9][0-9]") then
        direct_success = true
        direct_http_code = result_direct:match("HTTP/[0-9%.]+ ([0-9][0-9][0-9])")
    elseif result_direct:match("HTTP/[0-9%.]+") then
        direct_http_code = result_direct:match("HTTP/[0-9%.]+ ([0-9][0-9][0-9])")
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = success,
        site = site,
        http_code = http_code,
        result = result:gsub("%s+$", ""),
        direct_success = direct_success,
        direct_http_code = direct_http_code,
        direct_result = result_direct:gsub("%s+$", ""),
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        command = command
    })
end
