#!/bin/sh
# 07-stop-cleanup — stopping the service tears everything down cleanly.
# Asserts: mihomo stops, the nft table is flushed, policy routing (rule/table 105)
# is removed, and dnsmasq is restored (no server=127.0.0.42 forwarding).
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 07-stop-cleanup: no installed brand detected"; exit 1; }
[ -x "/etc/init.d/$NAME" ] || { echo "SKIP 07-stop-cleanup: /etc/init.d/$NAME missing"; exit 77; }

"/etc/init.d/$NAME" stop
i=0
while [ "$i" -lt 10 ]; do pidof mihomo >/dev/null 2>&1 || break; i=$((i + 1)); sleep 1; done

fail=""
pidof mihomo >/dev/null 2>&1 && fail="$fail mihomo-still-running"

if command -v nft >/dev/null 2>&1; then
  nft list table inet "$NAME" >/dev/null 2>&1 && fail="$fail nft-table-remains"
fi

if command -v ip >/dev/null 2>&1; then
  ip rule show 2>/dev/null | grep -q 'lookup 105' && fail="$fail ip-rule-105-remains"
  [ -n "$(ip route show table 105 2>/dev/null)" ] && fail="$fail rt-table-105-remains"
fi

# dnsmasq restored: mihomo's DNS forwarder should no longer be configured
if command -v uci >/dev/null 2>&1; then
  uci -q show dhcp 2>/dev/null | grep -q '127.0.0.42' && fail="$fail dnsmasq-still-repointed"
fi
grep -rqs '127.0.0.42' /tmp/dnsmasq.d /var/etc/dnsmasq* 2>/dev/null && fail="$fail dnsmasq-conf-remains"

if [ -n "$fail" ]; then
  echo "FAIL 07-stop-cleanup: leftovers after stop:$fail"
  exit 1
fi
echo "PASS 07-stop-cleanup: mihomo stopped; nft table, policy routing and dnsmasq all restored"
exit 0
