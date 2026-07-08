#!/bin/sh
# 04-rest-api — mihomo's external controller answers authenticated requests.
# The bearer secret is uci get <name>.main.api_secret (kept server-side).
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 04-rest-api: no installed brand detected"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "SKIP 04-rest-api: curl unavailable"; exit 77; }
command -v uci  >/dev/null 2>&1 || { echo "SKIP 04-rest-api: uci unavailable"; exit 77; }

secret=$(uci -q get "$NAME.main.api_secret")
base="http://127.0.0.1:9090"

ver=$(curl -fsS --max-time 5 -H "Authorization: Bearer ${secret}" "$base/version" 2>/dev/null)
if [ -z "$ver" ]; then
  echo "FAIL 04-rest-api: no response from $base/version (is the service running?)"
  exit 1
fi
case $ver in
  *version*|*meta*|*premium*) : ;;
  *) echo "FAIL 04-rest-api: unexpected /version payload: $ver"; exit 1 ;;
esac

# a wrong secret must be rejected (401) — confirms auth is actually enforced
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -H "Authorization: Bearer wrong-secret" "$base/configs" 2>/dev/null)
if [ "$code" = "200" ]; then
  echo "FAIL 04-rest-api: /configs accepted a bogus bearer token (auth not enforced)"
  exit 1
fi

echo "PASS 04-rest-api: /version authenticated OK, bogus token rejected (http $code)"
exit 0
