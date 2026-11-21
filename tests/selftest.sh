#!/bin/sh
# Моковый стенд awg-pool. Проверяет логику без реальных uci/ip/curl.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
UCIF="$T/u"; NET="$T/n"; SC="$T/s"; LOGF="$T/l"; CNTB="$T/b"

ng(){ while IFS= read -r l; do case "$l" in "$1="*) printf '%s' "${l#*=}"; return 0;; esac; done <"$NET"; return 1; }
ns(){ _b=""; while IFS= read -r l; do case "$l" in "$1="*) continue;; esac; _b="$_b$l
"; done <"$NET"; printf '%s%s=%s\n' "$_b" "$1" "$2" >"$NET"; }
nd(){ _b=""; while IFS= read -r l; do case "$l" in $1) continue;; esac; _b="$_b$l
"; done <"$NET"; printf '%s' "$_b" >"$NET"; }
us(){ _b=""; while IFS= read -r l; do case "$l" in "$1="*) _b="$_b$1='$2'
"; continue;; esac; _b="$_b$l
"; done <"$UCIF"; printf '%s' "$_b" >"$UCIF"; }
ud(){ _b=""; while IFS= read -r l; do case "$l" in $1) continue;; esac; _b="$_b$l
"; done <"$UCIF"; printf '%s' "$_b" >"$UCIF"; }

uci(){ [ "$1" = "-q" ] && shift
 case "$1" in
 show) _p="$2"; while IFS= read -r l; do case "$l" in "$_p."*) printf '%s\n' "$l";; esac; done <"$UCIF";;
 get) _p="$2"; _f=0
   while IFS= read -r l; do case "$l" in "$_p="*) _v="${l#*=}"; _v="${_v#\'}"; _v="${_v%\'}"; printf '%s\n' "$_v"; _f=1; break;; esac; done <"$UCIF"
   [ "$_f" = 1 ] || return 1;;
 batch) echo x >>"$CNTB"
   while IFS= read -r l; do case "$l" in "set "*)
     _a="${l#set }"; _k="${_a%%=*}"; _v="${_a#*=}"; us "$_k" "$_v";; esac; done;;
 esac; return 0; }

ip(){ while [ "$1" = "-4" ] || [ "$1" = "-o" ]; do shift; done
 _c="$1"; shift
 case "$_c" in
 link) _d=""; while [ $# -gt 0 ]; do [ "$1" = dev ] && _d="$2"; shift; done
   [ "$(ng "up_$_d")" = 1 ] && { printf '13: %s: <UP>\n' "$_d"; return 0; }; return 1;;
 addr) _d=""; while [ $# -gt 0 ]; do [ "$1" = dev ] && _d="$2"; shift; done
   [ "$(ng "up_$_d")" = 1 ] && [ -n "$(ng "addr_$_d")" ] && printf '13: %s inet %s/32 x\n' "$_d" "$(ng "addr_$_d")"; return 0;;
 route) _s="$1"; shift; _t=main; _d=""; _src=""
   while [ $# -gt 0 ]; do case "$1" in table) _t="$2"; shift 2;; dev) _d="$2"; shift 2;; src) _src="$2"; shift 2;; *) shift;; esac; done
   case "$_s" in
   show) [ "$_t" = main ] && printf 'default via 192.168.1.1 dev %s\n' "$(ng wan)"
     while IFS= read -r l; do case "$l" in "route=$_t "*) printf '%s\n' "${l#route=$_t }";; esac; done <"$NET";;
   replace|add) nd "route=$_t *dev $_d*"; printf 'route=%s default dev %s src %s table %s\n' "$_t" "$_d" "$_src" "$_t" >>"$NET";;
   flush) nd "route=$_t *";; esac; return 0;;
 rule) _s="$1"; shift
   case "$_s" in
   show|list) printf '0:\tfrom all lookup local\n105:\tfrom all fwmark 0x4000000 lookup forkop\n'
     while IFS= read -r l; do case "$l" in rule=*) set -- ${l#rule=}; printf '%s:\tfrom all oif %s lookup %s\n' "$1" "$2" "$3";; esac; done <"$NET"
     printf '32766:\tfrom all lookup main\n';;
   add) _o=""; _t=""; _p=200
     while [ $# -gt 0 ]; do case "$1" in oif) _o="$2"; shift 2;; lookup) _t="$2"; shift 2;; priority) _p="$2"; shift 2;; *) shift;; esac; done
     printf 'rule=%s %s %s\n' "$_p" "$_o" "$_t" >>"$NET";;
   del) _o=""; _t=""
     while [ $# -gt 0 ]; do case "$1" in oif) _o="$2"; shift 2;; lookup) _t="$2"; shift 2;; *) shift;; esac; done
     nd "rule=* $_o $_t";; esac; return 0;;
 esac; return 0; }

ifup(){ ns "up_$1" 1; ns "addr_$1" "$(ng "bak_$1")"; return 0; }
ifdown(){ ns "up_$1" 0; ns "addr_$1" ""; nd "route=*dev $1*"; return 0; }
logger(){ shift 4; printf '%s\n' "$*" >>"$LOGF"; return 0; }
scg(){ while IFS= read -r l; do case "$l" in "$1="*) printf '%s' "${l#*=}"; return 0;; esac; done <"$SC"; printf '000 0'; }
setsc(){ _b=""; while IFS= read -r l; do case "$l" in "$1="*) continue;; esac; _b="$_b$l
"; done <"$SC"; printf '%s%s=%s\n' "$_b" "$1" "$2" >"$SC"; }

curl(){ _d=""; _f=""; _u=""
 while [ $# -gt 0 ]; do case "$1" in --interface) _d="$2"; shift 2;; -w|--write-out) _f="$2"; shift 2;;
   -o|--output|--resolve|--connect-timeout|--max-time) shift 2;; http*) _u="$1"; shift;; *) shift;; esac; done
 _e(){ case "$_f" in '%{http_code}') printf '%s' "$1";; '%{remote_ip}') printf '104.16.132.229';; *) printf '%s %s %s' "$1" "$2" "$3";; esac; }
 if [ "$_d" = "$(ng wan)" ]; then [ "$(ng wan_down)" = 1 ] && { _e 000 0 0; return 7; }; _e 200 0 0; return 0; fi
 _hr=0; _ht=0
 while IFS= read -r l; do case "$l" in rule=*" $_d "*) _hr=1;; "route=main "*) :;; route=*dev" $_d"*) _ht=1;; esac; done <"$NET"
 if [ "$(ng "up_$_d")" != 1 ] || [ "$_hr" != 1 ] || [ "$_ht" != 1 ]; then _e 000 0 0; return 7; fi
 _h="$(uci -q get "network.@amneziawg_$_d[0].endpoint_host")"
 set -- $(scg "$_h"); _c="$1"; _sp="$2"
 case "$_u" in *__down*) _wn="${_u##*bytes=}"
   [ "$_sp" -le 0 ] && { _e "$_c" 0 0; return 28; }
   _ms=$((_wn*1000/_sp))
   if [ "$_ms" -gt 8000 ]; then _sz=$((_sp*8)); _ms=8000; _rc=28; else _sz="$_wn"; _rc=0; fi
   [ "$_ms" -gt 0 ] || _ms=1
   _e "$_c" "$((_sz*1000/_ms))" "$_sz"; return "$_rc";; esac
 _e "$_c" 0 0; return 0; }

set -- --version
. "$ROOT/awg-pool/files/awg-pool" >/dev/null
STATE="$T/state"; LOCK="$T/lock"

hh(){ case "$1" in 0) printf it;; 1) printf pl;; 2) printf de;; esac; }
reset(){
 { printf 'wan=eth0\nwan_down=0\n'
   for i in 0 1 2; do printf 'up_awg%s=1\naddr_awg%s=10.0.0.%s\nbak_awg%s=10.0.0.%s\n' "$i" "$i" "$((i+1))" "$i" "$((i+1))"; done; } >"$NET"
 : >"$LOGF"; : >"$CNTB"; rm -f "$STATE"
 { for i in 0 1 2; do
     printf "network.awg%s=interface\nnetwork.awg%s.proto='amneziawg'\nnetwork.awg%s.private_key='K%s'\nnetwork.awg%s.addresses='10.0.0.%s/32'\n" "$i" "$i" "$i" "$i" "$i" "$((i+1))"
     printf "network.@amneziawg_awg%s[0]=amneziawg_awg%s\nnetwork.@amneziawg_awg%s[0].endpoint_host='%s.gw.test'\nnetwork.@amneziawg_awg%s[0].endpoint_port='443'\nnetwork.@amneziawg_awg%s[0].route_allowed_ips='0'\n" "$i" "$i" "$i" "$(hh "$i")" "$i" "$i"
   done
   printf "awg-failover.main=settings\nawg-failover.main.check_interval='5'\nawg-failover.main.health_tries='1'\nawg-failover.main.health_retry='0'\nawg-failover.main.health_timeout='1'\nawg-failover.main.speed_bytes='100000'\nawg-failover.main.speed_every='3'\nawg-failover.main.standby_every='0'\nawg-failover.main.sweep_cooldown='0'\n"
   for i in 0 1 2; do printf "awg-failover.@pool[%s]=pool\nawg-failover.@pool[%s].iface='awg%s'\n" "$i" "$i" "$i"; done
   j=0; for c in it pl de ie no; do
     printf "awg-failover.@server[%s]=server\nawg-failover.@server[%s].host='%s.gw.test'\nawg-failover.@server[%s].port='443'\n" "$j" "$j" "$c" "$j"
     j=$((j+1)); done
 } >"$UCIF"
 { for c in it pl de ie no; do printf '%s.gw.test=200 5000000\n' "$c"; done; } >"$SC"
 POOL=""; SERVERS=""; SPEED_IP=""; WAN_CACHED=""; POOL_IFACES=""; RUNNING=1
 for i in 0 1 2; do set_pt "awg$i" ""; set_pp "awg$i" ""; set_pr "awg$i" ""; done
 load_config
}
P=0; F=0
ok(){ if [ "$2" = "$3" ]; then P=$((P+1)); printf 'PASS  %s\n' "$1"; else F=$((F+1)); printf 'FAIL  %s | ждали [%s] получили [%s]\n' "$1" "$3" "$2"; fi; }
ne(){ if [ "$1" != "$2" ]; then echo 1; else echo 0; fi; }
has(){ case "$2" in *"$1"*) echo 1;; *) echo 0;; esac; }

reset; preflight >/dev/null 2>&1; bring_up_pool
ok "пул=3 стран=5" "$POOL_N/$SERVER_N" "3/5"
ok "раздельные таблицы" "$(get_pt awg0)/$(get_pt awg1)/$(get_pt awg2)" "250/251/252"
ok "по правилу на интерфейс" "$(grep -c '^rule=' "$NET")" "3"
C="$(candidates awg0 | tr '\n' ' ')"
ok "разнообразие: pl исключён" "$(has pl.gw.test "$C")" "0"
ok "разнообразие: de исключён" "$(has de.gw.test "$C")" "0"

reset; preflight >/dev/null 2>&1; bring_up_pool; setsc it.gw.test "000 0"
rotate awg0 >/dev/null 2>&1
ok "мёртвая страна заменена" "$(ne "$(cur_host awg0)" it.gw.test)" "1"

reset; preflight >/dev/null 2>&1; bring_up_pool; setsc it.gw.test "200 102400"
rotate awg0 >/dev/null 2>&1
ok "медленная страна отбракована" "$(ne "$(cur_host awg0)" it.gw.test)" "1"

reset; preflight >/dev/null 2>&1; bring_up_pool
: >"$CNTB"; apply_host awg0 it.gw.test
ok "A6 нет commit без изменений" "$(grep -c x "$CNTB")" "0"
apply_host awg0 ie.gw.test
ok "A6 commit при изменении" "$(grep -c x "$CNTB")" "1"

reset; preflight >/dev/null 2>&1; bring_up_pool
for c in it pl de ie no; do mark_dead "$c.gw.test"; done
ok "A7 кандидатов нет" "$(candidates awg0 | grep -c .)" "0"
rotate awg0 >/dev/null 2>&1; rc=$?
ok "A7 перебор после сброса cooldown" "$rc" "0"

reset; preflight >/dev/null 2>&1; bring_up_pool
ifdown awg0; on_exit
ok "A1 интерфейс поднят при выходе" "$(ng up_awg0)" "1"
ok "A1 правила сняты" "$(grep -c '^rule=' "$NET")" "0"

reset; preflight >/dev/null 2>&1; bring_up_pool; RUNNING=0
rotate awg0 >/dev/null 2>&1
ok "A2 перебор прерван" "$(grep -c 'прерван по сигналу' "$LOGF")" "1"

reset; ud 'awg-failover.@pool*'
load_config; ok "A3 пустой пул -> rc=1" "$?" "1"
ok "A3 процесс жив" "alive" "alive"

reset; us network.awg1.private_key K0
( preflight ) >/dev/null 2>&1
ok "дубли ключей отклонены" "$(grep -c 'совпадают private_key' "$LOGF")" "1"

reset; preflight >/dev/null 2>&1; bring_up_pool; setsc it.gw.test "000 0"
( cmd_once ) >/dev/null 2>&1
ok "резервы не тронуты" "$(cur_host awg1)/$(cur_host awg2)" "pl.gw.test/de.gw.test"

reset; preflight >/dev/null 2>&1; bring_up_pool; ns wan_down 1
( cmd_once ) >/dev/null 2>&1; rc=$?
ok "WAN down: без смены" "$rc/$(cur_host awg0)" "0/it.gw.test"

printf '\nИТОГО PASS=%s FAIL=%s\n' "$P" "$F"
[ "$F" = 0 ] || exit 1