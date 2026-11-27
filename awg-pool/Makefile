include $(TOPDIR)/rules.mk

PKG_NAME:=awg-pool
PKG_VERSION:=1.3.2
PKG_RELEASE:=1
PKG_LICENSE:=MIT
PKG_MAINTAINER:=local build
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/awg-pool
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=AmneziaWG interface pool failover daemon
  DEPENDS:=+curl +ca-bundle +ip-full
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
# Кавычки из снимка `uci show` снимаются: uci set пишет значение буквально.
# Секции, которых больше нет (peer удалён или индексы сдвинулись), пропускаются.
D=/etc/awg-pool
[ -r "$$D/endpoints.txt" ] || { echo "Снимок не найден"; exit 1; }
/etc/init.d/awg-pool stop 2>/dev/null
while IFS= read -r line; do
    key="$${line%%=*}"; val="$${line#*=}"
    uci -q get "$${key%.*}" >/dev/null 2>&1 || continue
    case "$$val" in "'"*"'") val="$${val#\'}"; val="$${val%\'}" ;; esac
    uci -q set "$$key=$$val" 2>/dev/null
done < "$$D/endpoints.txt"
uci commit network
# Снимаем ТОЛЬКО проверочные правила интерфейсов пула и созданные ими таблицы.
# Чужие таблицы/правила не трогаем; имена интерфейсов берём из конфига,
# а не из зашитого списка awg0..awg5.
IFACES=$$(uci -q show awg-failover 2>/dev/null | sed -n "s/^awg-failover\.@pool\[[0-9]*\]\.iface=//p" | tr -d "'")
for i in $$IFACES; do
    ip rule show 2>/dev/null | sed -n "s/^\([0-9][0-9]*\):.*oif $$i .*lookup \([0-9][0-9]*\).*/\1 \2/p" | \
    while read -r pr tb; do
        ip rule del priority "$$pr" 2>/dev/null
        ip route flush table "$$tb" 2>/dev/null
    done
done
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
    # restart (а не start): при обновлении пакета procd не перезапускает
    # экземпляр с неизменившейся командой, и работал бы старый демон.
    if uci -q get "awg-failover.@pool[0]" >/dev/null 2>&1 && uci -q get "awg-failover.@server[1]" >/dev/null 2>&1; then
        /etc/init.d/awg-pool restart >/dev/null 2>&1 || true
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
