include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-bye-dpi
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_MAINTAINER:=Your Name <your@email.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=ByeDPI Manager for OpenWrt
LUCI_DESCRIPTION:=Universal Luci application for managing ByeDPI-OpenWrt with automatic architecture detection and strategy testing.
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-ipkg +wget-ssl +curl +byedpi +procps-ng-pkill
LUCI_PKGARCH:=all
LUCI_SECTION:=luci
LUCI_CATEGORY:=Applications

include $(TOPDIR)/feeds/luci/luci.mk

define Package/$(PKG_NAME)/conffiles
/etc/config/byedpi
endef

define Build/Compile
	$(call Build/Compile/Default)
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./luasrc/controller/byedpi.lua $(1)/usr/lib/lua/luci/controller/
	
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DATA) ./luasrc/model/cbi/byedpi.lua $(1)/usr/lib/lua/luci/model/cbi/
	
	$(INSTALL_DIR) $(1)/usr/libexec/luci-byedpi
	$(INSTALL_BIN) ./root/usr/libexec/luci-byedpi/*.sh $(1)/usr/libexec/luci-byedpi/
	
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-byedpi.json $(1)/usr/share/rpcd/acl.d/
	
	$(INSTALL_DIR) $(1)/www/luci-static/resources/byedpi
	$(INSTALL_DATA) ./htdocs/luci-static/byedpi/style.css $(1)/www/luci-static/resources/byedpi/
	
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./root/etc/config/byedpi $(1)/etc/config/byedpi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
