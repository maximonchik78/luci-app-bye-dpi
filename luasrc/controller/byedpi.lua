module("luci.controller.byedpi", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/byedpi") then
        nixio.fs.writefile("/etc/config/byedpi", "")
    end
    
    entry({"admin", "services", "byedpi"}, cbi("byedpi"), _("ByeDPI Manager"), 60).dependent = true
    
    entry({"admin", "services", "byedpi", "install"}, call("action_install")).leaf = true
    entry({"admin", "services", "byedpi", "uninstall"}, call("action_uninstall")).leaf = true
    entry({"admin", "services", "byedpi", "start"}, call("action_start")).leaf = true
    entry({"admin", "services", "byedpi", "stop"}, call("action_stop")).leaf = true
    entry({"admin", "services", "byedpi", "restart"}, call("action_restart")).leaf = true
    entry({"admin", "services", "byedpi", "strategy_test"}, call("action_strategy_test")).leaf = true
    entry({"admin", "services", "byedpi", "apply_custom"}, call("action_apply_custom")).leaf = true
    entry({"admin", "services", "byedpi", "status"}, call("action_status")).leaf = true
    entry({"admin", "services", "byedpi", "get_log"}, call("action_get_log")).leaf = true
    entry({"admin", "services", "byedpi", "clear_log"}, call("action_clear_log")).leaf = true
    entry({"admin", "services", "byedpi", "check_update"}, call("action_check_update")).leaf = true
    entry({"admin", "services", "byedpi", "test_site"}, call("action_test_site")).leaf = true
end

function action_install()
    local result = luci.sys.exec("/usr/libexec/luci-byedpi/install.sh 2>&1")
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = (result:find("ERROR") == nil and result:find("error") == nil), output = result})
end

function action_uninstall()
    luci.sys.call("pkill -f byedpi 2>/dev/null")
    luci.sys.call("sleep 1")
    local result = luci.sys.exec("opkg remove --force-remove byedpi 2>&1")
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true, output = result})
end

function action_start()
    local strategy = luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or "-1 -2 --http-version 1.1"
    strategy = strategy:gsub("%s+$", ""):gsub("^%s+", "")
    
    local pid = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null | head -1")
    if pid and pid:match("%d+") then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, message = "ByeDPI уже запущен (PID: " .. pid .. ")", pid = tonumber(pid)})
        return
    end
    
    local command = string.format("byedpi %s > /tmp/byedpi.log 2>&1 &", strategy)
    luci.sys.exec(command)
    luci.sys.exec("sleep 1")
    
    pid = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null | head -1")
    luci.http.prepare_content("application/json")
    
    if pid and pid:match("%d+") then
        luci.sys.exec("uci set byedpi.settings.enabled='1' && uci commit byedpi")
        luci.http.write_json({success = true, message = "ByeDPI успешно запущен", pid = tonumber(pid), strategy = strategy})
    else
        luci.http.write_json({success = false, message = "Не удалось запустить ByeDPI", command = command})
    end
end

function action_stop()
    local pids = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null")
    
    if pids and #pids > 0 then
        luci.sys.exec("pkill -f 'byedpi' 2>/dev/null")
        luci.sys.exec("sleep 2")
        
        local still_running = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null")
        luci.sys.exec("uci set byedpi.settings.enabled='0' && uci commit byedpi")
        
        luci.http.prepare_content("application/json")
        
        if still_running and #still_running > 0 then
            luci.sys.exec("pkill -9 -f 'byedpi' 2>/dev/null")
            luci.http.write_json({success = true, message = "ByeDPI принудительно остановлен", killed_pids = pids})
        else
            luci.http.write_json({success = true, message = "ByeDPI успешно остановлен", killed_pids = pids})
        end
    else
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, message = "ByeDPI не запущен"})
    end
end

function action_restart()
    action_stop()
    luci.sys.exec("sleep 2")
    action_start()
end

function action_strategy_test()
    local sites = luci.http.formvalue("sites") or "youtube.com,twitter.com,instagram.com,facebook.com"
    sites = sites:gsub('"', '\\"'):gsub("'", "'\"'\"'")
    
    local result = luci.sys.exec(string.format('/usr/libexec/luci-byedpi/strategy-test.sh "%s" 2>&1', sites))
    luci.http.prepare_content("application/json")
    luci.http.write_json({output = result})
end

function action_apply_custom()
    local strategy = luci.http.formvalue("strategy") or ""
    
    if #strategy == 0 then
        luci.http.prepare_content("application/json")
        luci.http.write_json({success = false, message = "Стратегия не может быть пустой"})
        return
    end
    
    strategy = strategy:gsub('"', '\\"')
    local result = luci.sys.exec(string.format('uci set byedpi.settings.strategy="%s" && uci commit byedpi', strategy))
    
    luci.http.prepare_content("application/json")
    
    if result and #result == 0 then
        luci.http.write_json({success = true, message = "Стратегия успешно применена", strategy = strategy})
    else
        luci.http.write_json({success = false, message = "Ошибка при применении стратегии"})
    end
end

function action_status()
    local is_installed = nixio.fs.access("/usr/bin/byedpi") or nixio.fs.access("/usr/sbin/byedpi")
    local pid = luci.sys.exec("pgrep -f 'byedpi' 2>/dev/null | head -1")
    local is_running = (pid and pid:match("%d+"))
    
    local strategy = luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or ""
    local version = luci.sys.exec("byedpi --version 2>/dev/null | head -1") or "unknown"
    
    local architecture = "unknown"
    if nixio.fs.access("/etc/openwrt_release") then
        architecture = luci.sys.exec("awk -F\"'\" '/DISTRIB_TARGET/ {print $2}' /etc/openwrt_release 2>/dev/null") or
                      luci.sys.exec("awk -F\"'\" '/DISTRIB_ARCH/ {print $2}' /etc/openwrt_release 2>/dev/null") or
                      "unknown"
        architecture = architecture:gsub("%s+", "")
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        installed = is_installed,
        running = is_running,
        pid = is_running and tonumber(pid) or 0,
        strategy = strategy,
        version = version,
        architecture = architecture,
        config = "/etc/config/byedpi"
    })
end

function action_get_log()
    local log_type = luci.http.formvalue("type") or "service"
    local lines = tonumber(luci.http.formvalue("lines")) or 100
    
    local log_file = ""
    if log_type == "service" then
        log_file = "/tmp/byedpi.log"
    elseif log_type == "install" then
        local files = luci.sys.exec("ls -t /tmp/byedpi_install_*.log 2>/dev/null | head -1")
        log_file = files:gsub("%s+", "")
    elseif log_type == "strategy" then
        local files = luci.sys.exec("ls -t /tmp/byedpi_strategy_test_*.log 2>/dev/null | head -1")
        log_file = files:gsub("%s+", "")
    end
    
    local content = ""
    if nixio.fs.access(log_file) then
        content = luci.sys.exec(string.format("tail -n %d '%s' 2>/dev/null", lines, log_file))
    else
        content = "Лог файл не найден: " .. log_file
    end
    
    luci.http.prepare_content("text/plain")
    luci.http.write(content)
end

function action_clear_log()
    local log_type = luci.http.formvalue("type") or "service"
    
    if log_type == "service" then
        luci.sys.exec("> /tmp/byedpi.log")
    elseif log_type == "all" then
        luci.sys.exec("rm -f /tmp/byedpi_*.log 2>/dev/null")
        luci.sys.exec("> /tmp/byedpi.log")
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true, message = "Логи очищены"})
end

function action_check_update()
    local current_version = luci.sys.exec("byedpi --version 2>/dev/null | head -1 | grep -o '[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+'") or "0.0.0"
    current_version = current_version:gsub("%s+", "")
    
    local latest_version = luci.sys.exec("curl -s 'https://api.github.com/repos/DPITrickster/ByeDPI-OpenWrt/releases/latest' | grep 'tag_name' | cut -d'\"' -f4")
    
    luci.http.prepare_content("application/json")
    
    if latest_version and #latest_version > 0 then
        latest_version = latest_version:gsub("^v", ""):gsub("%s+", "")
        
        local needs_update = false
        local cv_parts = {}
        local lv_parts = {}
        
        for part in current_version:gmatch("%d+") do
            table.insert(cv_parts, tonumber(part))
        end
        
        for part in latest_version:gmatch("%d+") do
            table.insert(lv_parts, tonumber(part))
        end
        
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
        
        luci.sys.exec(string.format('uci set byedpi.settings.last_update_check="%s" && uci commit byedpi', os.date("%Y-%m-%d %H:%M:%S")))
        
        luci.http.write_json({
            success = true,
            current_version = current_version,
            latest_version = latest_version,
            needs_update = needs_update,
            message = needs_update and "Доступно обновление" or "У вас актуальная версия"
        })
    else
        luci.http.write_json({
            success = false,
            message = "Не удалось проверить обновления"
        })
    end
end

function action_test_site()
    local site = luci.http.formvalue("site") or "youtube.com"
    local timeout = tonumber(luci.http.formvalue("timeout")) or 10
    
    site = site:gsub("^https?://", ""):gsub("/.*$", "")
    
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
    
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        success = success,
        site = site,
        http_code = http_code,
        result = result:gsub("%s+$", ""),
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    })
end
