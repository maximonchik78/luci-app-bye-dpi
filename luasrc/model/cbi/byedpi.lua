m = Map("byedpi", translate("ByeDPI Manager"), translate("Universal Luci application for managing ByeDPI-OpenWrt"))

-- Секция статуса
s = m:section(TypedSection, "status", translate("Status"))
s.anonymous = true
s:append(Template("byedpi/status"))

-- Секция установки/обновления
s = m:section(TypedSection, "install", translate("Installation"))
s.anonymous = true

btn_install = s:option(Button, "_install", translate("Install/Update ByeDPI"))
btn_install.inputtitle = translate("Install")
btn_install.inputstyle = "apply"
function btn_install.write()
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/install"))
end

-- Секция управления сервисом
s = m:section(TypedSection, "service", translate("Service Control"))
s.anonymous = true

btn_start = s:option(Button, "_start", translate("Start"))
btn_start.inputtitle = translate("Start")
btn_start.inputstyle = "apply"
function btn_start.write()
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/start"))
end

btn_stop = s:option(Button, "_stop", translate("Stop"))
btn_stop.inputtitle = translate("Stop")
btn_stop.inputstyle = "reset"
function btn_stop.write()
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/stop"))
end

btn_restart = s:option(Button, "_restart", translate("Restart"))
btn_restart.inputtitle = translate("Restart")
btn_restart.inputstyle = "reload"
function btn_restart.write()
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/restart"))
end

-- Секция стратегий
s = m:section(TypedSection, "strategies", translate("Strategies"))
s.anonymous = true

sites = s:option(Value, "test_sites", translate("Test Sites"), translate("Sites for strategy testing (comma separated)"))
sites.default = "youtube.com,twitter.com,instagram.com,facebook.com"

btn_test = s:option(Button, "_test", translate("Auto Strategy Selection"))
btn_test.inputtitle = translate("Test Strategies")
btn_test.inputstyle = "apply"
function btn_test.write()
    local sites_value = m:formvalue("cbid.byedpi.strategies.test_sites") or "youtube.com,twitter.com,instagram.com,facebook.com"
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/strategy_test") .. "?sites=" .. luci.http.urlencode(sites_value))
end

custom_strategy = s:option(TextValue, "custom_strategy", translate("Custom Strategy"), translate("Enter custom ByeDPI strategy (e.g., -1 -2 --http-version 1.1)"))
custom_strategy.rows = 5
custom_strategy.wrap = "off"
function custom_strategy.cfgvalue()
    return luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or ""
end

btn_apply = s:option(Button, "_apply", translate("Apply Custom Strategy"))
btn_apply.inputtitle = translate("Apply")
btn_apply.inputstyle = "apply"
function btn_apply.write()
    local strategy_value = m:formvalue("cbid.byedpi.strategies.custom_strategy") or ""
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/apply_custom") .. "?strategy=" .. luci.http.urlencode(strategy_value))
end

-- Секция тестирования
s = m:section(TypedSection, "testing", translate("Testing"))
s.anonymous = true

test_site = s:option(Value, "site", translate("Test Site"), translate("Test specific site access"))
test_site.default = "youtube.com"

btn_test_site = s:option(Button, "_test_site", translate("Test Site Access"))
btn_test_site.inputtitle = translate("Test")
btn_test_site.inputstyle = "apply"
function btn_test_site.write()
    local site_value = m:formvalue("cbid.byedpi.testing.site") or "youtube.com"
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/test_site") .. "?site=" .. luci.http.urlencode(site_value))
end

-- Секция логов
s = m:section(TypedSection, "logs", translate("Logs"))
s.anonymous = true

log_type = s:option(ListValue, "log_type", translate("Log Type"))
log_type:value("service", "Service Log")
log_type:value("install", "Installation Log")
log_type:value("strategy", "Strategy Test Log")
log_type.default = "service"

log_lines = s:option(Value, "log_lines", translate("Lines to Show"))
log_lines.default = "100"
log_lines.datatype = "uinteger"

btn_view_log = s:option(Button, "_view_log", translate("View Log"))
btn_view_log.inputtitle = translate("View")
btn_view_log.inputstyle = "view"
function btn_view_log.write()
    local type_value = m:formvalue("cbid.byedpi.logs.log_type") or "service"
    local lines_value = m:formvalue("cbid.byedpi.logs.log_lines") or "100"
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/get_log") .. "?type=" .. type_value .. "&lines=" .. lines_value)
end

btn_clear_log = s:option(Button, "_clear_log", translate("Clear Logs"))
btn_clear_log.inputtitle = translate("Clear")
btn_clear_log.inputstyle = "reset"
function btn_clear_log.write()
    local type_value = m:formvalue("cbid.byedpi.logs.log_type") or "service"
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/clear_log") .. "?type=" .. type_value)
end

-- Секция обновлений
s = m:section(TypedSection, "updates", translate("Updates"))
s.anonymous = true

btn_check_update = s:option(Button, "_check_update", translate("Check for Updates"))
btn_check_update.inputtitle = translate("Check")
btn_check_update.inputstyle = "reload"
function btn_check_update.write()
    luci.http.redirect(luci.dispatcher.build_url("admin/services/byedpi/check_update"))
end

return m
