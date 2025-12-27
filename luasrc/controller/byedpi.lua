module("luci.controller.byedpi", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/byedpi") then
        -- Создаем начальную конфигурацию
        luci.sys.call("touch /etc/config/byedpi")
        luci.sys.call("uci set byedpi.settings=settings")
        luci.sys.call("uci commit byedpi")
    end
    
    entry({"admin", "services", "byedpi"}, firstchild(), _("ByeDPI Manager"), 60).dependent = false
    entry({"admin", "services", "byedpi", "overview"}, cbi("byedpi/overview"), _("Overview"), 10)
    entry({"admin", "services", "byedpi", "install"}, cbi("byedpi/install"), _("Install/Update"), 20)
    entry({"admin", "services", "byedpi", "strategies"}, cbi("byedpi/strategies"), _("Strategies"), 30)
    
    -- AJAX endpoints для управления
    entry({"admin", "services", "byedpi", "api", "status"}, call("api_status")).leaf = true
    entry({"admin", "services", "byedpi", "api", "install"}, call("api_install")).leaf = true
    entry({"admin", "services", "byedpi", "api", "test"}, call("api_test_strategies")).leaf = true
    entry({"admin", "services", "byedpi", "api", "apply"}, call("api_apply_strategy")).leaf = true
    entry({"admin", "services", "byedpi", "api", "start"}, call("api_start")).leaf = true
    entry({"admin", "services", "byedpi", "api", "stop"}, call("api_stop")).leaf = true
    entry({"admin", "services", "byedpi", "api", "restart"}, call("api_restart")).leaf = true
end

function api_status()
    local result = {
        installed = nixio.fs.access("/usr/bin/byedpi") or nixio.fs.access("/usr/sbin/byedpi"),
        running = (luci.sys.call("pgrep -f byedpi >/dev/null") == 0),
        strategy = luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or "",
        version = luci.sys.exec("byedpi --version 2>/dev/null | head -1") or "unknown"
    }
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(result)
end

-- [Остальные функции остаются аналогичными, но обновлены для 24.x]
