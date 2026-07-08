#!/bin/sh
# 01-service — the procd service starts and mihomo's REST API comes up.
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 01-service: no installed brand detected"; exit 1; }
command -v uci >/dev/null 2>&1 || { echo "SKIP 01-service: uci unavailable (not an OpenWrt device)"; exit 77; }

uci -q set "$NAME.main.enabled=1" && uci -q commit "$NAME"
"/etc/init.d/$NAME" enable 2>/dev/null
"/etc/init.d/$NAME" restart

# wait for mihomo (the procd instance IS mihomo, per CONTRACT)
i=0; up=0
while [ "$i" -lt 15 ]; do
  if pidof mihomo >/dev/null 2>&1; then up=1; break; fi
  i=$((i + 1)); sleep 1
done
if [ "$up" != 1 ]; then
  echo "FAIL 01-service: mihomo not running after restart"
  "/usr/bin/$NAME" status 2>/dev/null || true
  exit 1
fi

# REST API on 127.0.0.1:9090 with the server-side bearer secret
secret=$(uci -q get "$NAME.main.api_secret")
if command -v curl >/dev/null 2>&1 &&
   curl -fsS --max-time 5 -H "Authorization: Bearer ${secret}" http://127.0.0.1:9090/version >/dev/null 2>&1; then
  echo "PASS 01-service: mihomo running, REST API 127.0.0.1:9090 reachable"
  exit 0
fi
echo "FAIL 01-service: mihomo running but REST API 127.0.0.1:9090 unreachable"
exit 1
