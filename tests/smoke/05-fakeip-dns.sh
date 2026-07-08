#!/bin/sh
# 05-fakeip-dns — dnsmasq is repointed at mihomo and fake-ip whitelisting works.
#
# Data path (CONTRACT): mihomo DNS runs fake-ip with fake-ip-filter-mode=whitelist.
# A domain that IS in an enabled rule-set gets a 198.18.0.0/16 answer; every other
# name resolves to its real IP. dnsmasq forwards to mihomo (server=127.0.0.42).
#
# LISTED_DOMAIN must be a domain present in an enabled list/user_domains; set it
# to match your config. DIRECT_DOMAIN should NOT be routed. Both are overridable.
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 05-fakeip-dns: no installed brand detected"; exit 1; }
command -v nslookup >/dev/null 2>&1 || { echo "SKIP 05-fakeip-dns: nslookup unavailable"; exit 77; }

LISTED_DOMAIN=${LISTED_DOMAIN:-}
DIRECT_DOMAIN=${DIRECT_DOMAIN:-example.com}

# is 127.0.0.42 (mihomo DNS) answering at all?
if ! nslookup "$DIRECT_DOMAIN" 127.0.0.42 >/dev/null 2>&1; then
  echo "FAIL 05-fakeip-dns: mihomo DNS at 127.0.0.42:53 not answering"
  exit 1
fi

is_fakeip() { nslookup "$1" "$2" 2>/dev/null | grep -qE '198\.18\.[0-9]+\.[0-9]+'; }

# unlisted must resolve to a REAL ip via mihomo (not fake-ip)
if is_fakeip "$DIRECT_DOMAIN" 127.0.0.42; then
  echo "FAIL 05-fakeip-dns: unlisted '$DIRECT_DOMAIN' got a fake-ip answer (whitelist leaking)"
  exit 1
fi

if [ -z "$LISTED_DOMAIN" ]; then
  echo "PASS 05-fakeip-dns: mihomo DNS up; unlisted '$DIRECT_DOMAIN' resolves to a real IP"
  echo "     (set LISTED_DOMAIN=<a domain in an enabled list> to also assert the fake-ip path)"
  exit 0
fi

if is_fakeip "$LISTED_DOMAIN" 127.0.0.42; then
  echo "PASS 05-fakeip-dns: listed '$LISTED_DOMAIN' -> fake-ip; unlisted '$DIRECT_DOMAIN' -> real IP"
  exit 0
fi
echo "FAIL 05-fakeip-dns: listed '$LISTED_DOMAIN' did NOT get a 198.18.x fake-ip answer"
echo "     (confirm the domain is in an enabled community list / user_domains and lists were updated)"
exit 1
