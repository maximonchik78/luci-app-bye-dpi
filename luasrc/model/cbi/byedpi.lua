m = Map("byedpi", translate("ByeDPI Manager"), translate("Управление ByeDPI для обхода DPI"))

-- Секция статуса
s = m:section(TypedSection, "status", "")
s.anonymous = true
s:append(Template("byedpi/status_overview"))

-- Секция установки
s = m:section(TypedSection, "install", translate("Установка ByeDPI"))
s.anonymous = true
btn_install = s:option(Button, "_install", translate("Автоустановка"))
btn_install.inputtitle = translate("Установить/Обновить")
btn_install.inputstyle = "apply"
btn_install.template = "byedpi/install_button"

-- Секция управления сервисом
s = m:section(TypedSection, "service", translate("Управление сервисом"))
s.anonymous = true
btn_start = s:option(Button, "_start", translate("Запуск"))
btn_stop = s:option(Button, "_stop", translate("Остановка"))
btn_restart = s:option(Button, "_restart", translate("Перезапуск"))

-- Секция стратегий
s = m:section(TypedSection, "strategy", translate("Управление стратегиями"))
s.anonymous = true

-- Автоподбор стратегий
sites = s:option(Value, "test_sites", translate("Сайты для проверки"), translate("Через запятую, как в ByeDPIManager"))
sites.default = "youtube.com,twitter.com,instagram.com,facebook.com"
btn_test = s:option(Button, "_test_strategies", translate("Автоподбор стратегий"))
btn_test.inputtitle = translate("Запустить тест")
btn_test.template = "byedpi/test_button"

-- Поле для кастомной стратегии
custom_strategy = s:option(TextValue, "custom_strategy", translate("Текущая/Кастомная стратегия"), translate("Вставьте свою стратегию как в ByeDPI (например, -1 -2 --http-version 1.1)"))
custom_strategy.rows = 5
custom_strategy.wrap = "off"
function custom_strategy.cfgvalue()
    return luci.sys.exec("uci get byedpi.settings.strategy 2>/dev/null") or ""
end
btn_apply = s:option(Button, "_apply_custom", translate("Применить кастомную стратегию"))
btn_apply.inputtitle = translate("Применить")

return m
