#!/bin/sh
# 06-routed-vs-direct — a listed domain is proxied; an unlisted one is direct.
#
# HOW TO OBSERVE (the core selective-proxy guarantee):
#   * A domain in an enabled rule-set resolves to a fake-ip (198.18.0.0/16). nft
#     matches `ip daddr 198.18.0.0/16`, sets the tproxy mark (0x00100000) and
#     TPROXYs it to mihomo -> the packet leaves via the proxy. The nft rule's
#     packet counter for the marked path increments.
#   * An unlisted domain resolves to its REAL IP, never matches the fake-ip set
#     nor subnets4, is never marked, and is routed directly by the kernel — the
#     marked-path counter does NOT move for it.
#
# This check compares the tproxy-mark rule counter before/after touching a listed
# vs an unlisted domain. Set LISTED_DOMAIN to a domain in an enabled list.
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 06-routed-vs-direct: no installed brand detected"; exit 1; }
command -v nft >/dev/null 2>&1  || { echo "SKIP 06-routed-vs-direct: nft unavailable"; exit 77; }
command -v curl >/dev/null 2>&1 || { echo "SKIP 06-routed-vs-direct: curl unavailable"; exit 77; }

LISTED_DOMAIN=${LISTED_DOMAIN:-}
DIRECT_DOMAIN=${DIRECT_DOMAIN:-example.com}

if [ -z "$LISTED_DOMAIN" ]; then
  echo "SKIP 06-routed-vs-direct: set LISTED_DOMAIN=<a domain in an enabled list> to run this comparison"
  echo "     (unlisted control domain defaults to DIRECT_DOMAIN=$DIRECT_DOMAIN)"
  exit 77
fi

# count packets that took the tproxy path (rules carrying the tproxy mark)
marked_pkts() {
  nft -a list table inet "$NAME" 2>/dev/null \
    | awk '/0x00100000/ && /packets/ { for (i=1;i<=NF;i++) if ($i=="packets") s+=$(i+1) } END { print s+0 }'
}

before=$(marked_pkts)
curl -s --max-time 8 -o /dev/null "http://$LISTED_DOMAIN/" 2>/dev/null || true
after_listed=$(marked_pkts)

curl -s --max-time 8 -o /dev/null "http://$DIRECT_DOMAIN/" 2>/dev/null || true
after_direct=$(marked_pkts)

listed_delta=$((after_listed - before))
direct_delta=$((after_direct - after_listed))

echo "  marked-path packets: +$listed_delta after listed '$LISTED_DOMAIN', +$direct_delta after unlisted '$DIRECT_DOMAIN'"
if [ "$listed_delta" -gt 0 ] && [ "$direct_delta" -eq 0 ]; then
  echo "PASS 06-routed-vs-direct: listed domain was proxied (mark counter moved), unlisted stayed direct"
  exit 0
fi
if [ "$listed_delta" -gt 0 ]; then
  echo "FAIL 06-routed-vs-direct: unlisted '$DIRECT_DOMAIN' also hit the proxy path (+$direct_delta)"
  exit 1
fi
echo "FAIL 06-routed-vs-direct: listed '$LISTED_DOMAIN' did not take the proxy path (counter did not move)"
exit 1
