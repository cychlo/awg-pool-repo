include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-awg-pool
PKG_VERSION:=1.1.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=local build
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-awg-pool
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI support for AWG Failover (awg-pool)
  DEPENDS:=+awg-pool +luci-base
  PKGARCH:=all
endef

define Package/luci-app-awg-pool/description
  Adds Services -> AWG Failover page: service control, autostart toggle,
  live status and editing of all awg-pool parameters, pool interfaces and
  country list. Grants write access only to the awg-failover UCI package.
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/luci-app-awg-pool/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/awg-pool
	$(INSTALL_DATA) ./files/main.js $(1)/www/luci-static/resources/view/awg-pool/main.js
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./files/menu.json $(1)/usr/share/luci/menu.d/luci-app-awg-pool.json
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./files/acl.json $(1)/usr/share/rpcd/acl.d/luci-app-awg-pool.json
endef

define Package/luci-app-awg-pool/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	rm -f /tmp/luci-indexcache* 2>/dev/null
	rm -rf /tmp/luci-modulecache 2>/dev/null
	/etc/init.d/rpcd restart >/dev/null 2>&1 || true
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
fi
exit 0
endef

define Package/luci-app-awg-pool/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	rm -f /tmp/luci-indexcache* 2>/dev/null
	rm -rf /tmp/luci-modulecache 2>/dev/null
	/etc/init.d/rpcd restart >/dev/null 2>&1 || true
fi
exit 0
endef

$(eval $(call BuildPackage,luci-app-awg-pool))