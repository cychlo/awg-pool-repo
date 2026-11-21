include $(TOPDIR)/rules.mk

PKG_NAME:=awg-pool
PKG_VERSION:=1.2.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=local build
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/awg-pool
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=AmneziaWG interface pool failover daemon
  DEPENDS:=+curl +ca-bundle +ip-full +flock
  PKGARCH:=all
endef

define Package/awg-pool/description
  Rotates AWG endpoints across a pool of OpenWrt interfaces. Gates candidates
  on HTTPS reachability and download throughput. Configurable TLS ceiling for
  DPI-affected links. Cross-checks the pool before failing over, so blocked
  probe addresses do not cause false failover. Never modifies Forkop config.
endef

define Package/awg-pool/conffiles
/etc/config/awg-failover
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/awg-pool/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/awg-pool $(1)/usr/bin/awg-pool
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/awg-pool.init $(1)/etc/init.d/awg-pool
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/awg-failover.config $(1)/etc/config/awg-failover
endef

define Package/awg-pool/preinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
D=/etc/awg-pool
[ -f "$$D/endpoints.txt" ] && exit 0
mkdir -p "$$D"
uci -q show network 2>/dev/null | grep -E '\.endpoint_(host|port)=' > "$$D/endpoints.txt"
ip rule show > "$$D/ip-rule.txt" 2>/dev/null
cat > "$$D/restore.sh" <<'RESTORE'
#!/bin/sh
# Возврат endpoint'ов к состоянию до установки awg-pool.
D=/etc/awg-pool
[ -r "$$D/endpoints.txt" ] || { echo "Снимок не найден"; exit 1; }
/etc/init.d/awg-pool stop 2>/dev/null
while IFS= read -r line; do uci -q set "$$line" 2>/dev/null; done < "$$D/endpoints.txt"
uci commit network
for i in 0 1 2 3 4 5; do ip rule del oif "awg$$i" 2>/dev/null; done
for t in 250 251 252 240 241 242 9990 9991 9992; do ip route flush table "$$t" 2>/dev/null; done
rm -f /var/run/awg-pool.state /var/run/awg-pool.lock
/etc/init.d/network reload
echo "Endpoint'ы возвращены к снимку. Проверьте:"
uci show network | grep endpoint_host
RESTORE
chmod 0755 "$$D/restore.sh"
exit 0
endef

define Package/awg-pool/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/awg-pool enable >/dev/null 2>&1 || true
	if uci -q get awg-failover.@pool[0] >/dev/null 2>&1 && \
	   uci -q get awg-failover.@server[1] >/dev/null 2>&1; then
		/etc/init.d/awg-pool start >/dev/null 2>&1 || true
	else
		echo "awg-pool: пул не настроен. Откройте Службы -> AWG Failover."
	fi
fi
exit 0
endef

define Package/awg-pool/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/awg-pool stop >/dev/null 2>&1 || true
	/etc/init.d/awg-pool disable >/dev/null 2>&1 || true
fi
exit 0
endef

define Package/awg-pool/postrm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rm -f /var/run/awg-pool.state /var/run/awg-pool.lock 2>/dev/null
echo "awg-pool удалён. Откат настроек: /etc/awg-pool/restore.sh"
echo "Полная очистка: rm -rf /etc/awg-pool /etc/config/awg-failover"
exit 0
endef

$(eval $(call BuildPackage,awg-pool))