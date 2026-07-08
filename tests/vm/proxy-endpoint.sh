#!/bin/sh
# proxy-endpoint.sh — spin a disposable proxy on the host (WAN side) so a QEMU
# guest running daypass has a real upstream to route selected traffic through.
#
# Prefers microsocks (tiny SOCKS5); falls back to sing-box with a minimal socks
# inbound. Prints the proxy URL to drop into the UCI proxy section, then runs the
# endpoint in the foreground (Ctrl-C to stop). Exits 77 if no backend is present.
#
#   PORT=1080 tests/vm/proxy-endpoint.sh
#   # then: PROXY_URL="socks5://10.0.2.2:1080" tests/vm/run-qemu.sh
#   # (10.0.2.2 is the QEMU user-mode gateway = the host)
set -eu

PORT=${PORT:-1080}
BIND=${BIND:-0.0.0.0}

if command -v microsocks >/dev/null 2>&1; then
  echo ">> microsocks on ${BIND}:${PORT}"
  echo "   PROXY_URL for the guest: socks5://10.0.2.2:${PORT}"
  exec microsocks -i "$BIND" -p "$PORT"
fi

if command -v sing-box >/dev/null 2>&1; then
  cfg=$(mktemp)
  cat > "$cfg" <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    { "type": "socks", "tag": "in", "listen": "${BIND}", "listen_port": ${PORT} }
  ],
  "outbounds": [ { "type": "direct", "tag": "out" } ]
}
EOF
  echo ">> sing-box socks inbound on ${BIND}:${PORT} (config: $cfg)"
  echo "   PROXY_URL for the guest: socks5://10.0.2.2:${PORT}"
  trap 'rm -f "$cfg"' EXIT INT TERM
  exec sing-box run -c "$cfg"
fi

echo "SKIP proxy-endpoint: neither 'microsocks' nor 'sing-box' found on PATH." >&2
echo "  Install one, e.g.:  apt-get install microsocks   |   brew install microsocks" >&2
exit 77
