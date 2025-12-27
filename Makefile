include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-bye-dpi
PKG_VERSION:=1.0.0
PKG_RELEASE:=$(shell date +%Y%m%d)
PKG_MAINTAINER:=Maxim Onchik <maximonchik78@github.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

LUCI_TITLE:=ByeDPI Manager for OpenWrt
LUCI_DESCRIPTION:=Universal Luci application for managing ByeDPI-OpenWrt with automatic architecture detection and strategy testing.
LUCI_DEPENDS:=+luci-base +luci-compat +luci-lib-ipkg +wget-ssl +curl +byedpi
LUCI_PKGARCH:=all

# Для OpenWrt 24.x используем новый формат
include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt build system will execute this
$(eval $(call BuildPackage,$(PKG_NAME)))
