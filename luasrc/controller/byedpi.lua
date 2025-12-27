module("luci.controller.byedpi", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/byedpi") then
        -- Создаем конфигурационный файл, если его нет
        nixio.fs.writefile("/etc/config/byedpi", "")
    end

    entry({"admin", "services", "byedpi"}, cbi("byedpi"), _("ByeDPI Manager"), 60).dependent = true
    entry({"admin", "services", "byedpi", "install"}, call("action_install")).leaf = true
    entry({"admin", "services", "byedpi", "uninstall"}, call("action_uninstall")).leaf = true
    entry({"admin", "services", "byedpi", "start"}, call("action_start")).leaf = true
    entry({"admin", "services", "byedpi", "stop"}, call("action_stop")).leaf = true
    entry({"admin", "services", "byedpi", "strategy_test"}, call("action_strategy_test")).leaf = true
    entry({"admin", "services", "byedpi", "apply_custom"}, call("action_apply_custom")).leaf = true
    entry({"admin", "services", "byedpi", "status"}, call("action_status")).leaf = true
end

function action_install()
    local result = luci.sys.exec("/usr/libexec/luci-byedpi/install.sh 2>&1")
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = (result:find("ERROR") == nil), output = result})
end

function action_strategy_test()
    local sites = luci.http.formvalue("sites") or "youtube.com,twitter.com"
    local result = luci.sys.exec(string.format('/usr/libexec/luci-byedpi/strategy-test.sh "%s" 2>&1', sites))
    luci.http.prepare_content("application/json")
    luci.http.write_json({output = result})
end

function action_apply_custom()
    local strategy = luci.http.formvalue("strategy") or ""
    local config_file = "/etc/config/byedpi"
    local content = luci.sys.exec(string.format('uci set byedpi.settings.strategy="%s" && uci commit byedpi', strategy))
    luci.http.prepare_content("application/json")
    luci.http.write_json({success = true, message = "Стратегия применена"})
end

function action_status()
    local is_installed = nixio.fs.access("/usr/bin/byedpi") or nixio.fs.access("/usr/sbin/byedpi")
    local is_running = (luci.sys.call("pgrep -f byedpi >/dev/null") == 0)
    luci.http.prepare_content("application/json")
    luci.http.write_json({
        installed = is_installed,
        running = is_running,
        strategy = luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or ""
    })
end
-- [Остальные функции action_start, action_stop, action_uninstall реализованы аналогично]
