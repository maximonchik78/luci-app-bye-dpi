include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-bye-dpi
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

LUCI_TITLE:=Luci Interface for ByeDPI-OpenWrt
LUCI_DEPENDS:=+luci-compat +luci-lib-ipkg +wget-ssl +curl
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt build system will execute this
$(eval $(call BuildPackage,luci-app-bye-dpi))
