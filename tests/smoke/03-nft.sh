#!/bin/sh
# 03-nft — the nftables TPROXY layer installs correctly.
# Asserts table 'inet <name>' exists with the mangle/divert chains, the tproxy
# redirect, the fake-ip destination range and the tproxy mark.
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 03-nft: no installed brand detected"; exit 1; }
command -v nft >/dev/null 2>&1 || { echo "SKIP 03-nft: nft unavailable"; exit 77; }
CLI="/usr/bin/$NAME"

# ensure the firewall layer is up (idempotent)
"$CLI" fw_start 2>/dev/null || "/etc/init.d/$NAME" restart 2>/dev/null

dump=$(nft list table inet "$NAME" 2>/dev/null)
if [ -z "$dump" ]; then
  echo "FAIL 03-nft: table 'inet $NAME' not present"
  exit 1
fi

miss=""
printf '%s' "$dump" | grep -q 'tproxy'          || miss="$miss tproxy-rule"
printf '%s' "$dump" | grep -q '198.18.0.0/16'   || miss="$miss fake-ip-range"
printf '%s' "$dump" | grep -q '0x00100000'      || miss="$miss tproxy-mark"
printf '%s' "$dump" | grep -q 'chain divert'    || miss="$miss divert-chain"
printf '%s' "$dump" | grep -q 'chain mangle'    || miss="$miss mangle-chain"

if [ -n "$miss" ]; then
  echo "FAIL 03-nft: table present but missing:$miss"
  exit 1
fi
echo "PASS 03-nft: inet $NAME table has mangle/divert chains, tproxy redirect, fake-ip range and mark"
exit 0
