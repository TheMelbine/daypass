#!/bin/sh
# 02-config-yaml — UCI -> config.yaml generation, then mihomo validation.
# Reuses the CLI: '<name> generate' then '<name> check'.
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 02-config-yaml: no installed brand detected"; exit 1; }
CLI="/usr/bin/$NAME"
[ -x "$CLI" ] || { echo "SKIP 02-config-yaml: $CLI not present"; exit 77; }

if ! "$CLI" generate; then
  echo "FAIL 02-config-yaml: '$NAME generate' failed"
  exit 1
fi

cfg="/etc/$NAME/run/config.yaml"
if [ ! -f "$cfg" ]; then
  # fall back to any generated config.yaml under the home dir
  cfg=$(find "/etc/$NAME" -name config.yaml 2>/dev/null | head -1)
fi
if [ -z "$cfg" ] || [ ! -f "$cfg" ]; then
  echo "FAIL 02-config-yaml: generated config.yaml not found under /etc/$NAME"
  exit 1
fi

if "$CLI" check; then
  echo "PASS 02-config-yaml: generated $cfg and '$NAME check' validated it"
  exit 0
fi
echo "FAIL 02-config-yaml: '$NAME check' rejected the generated config"
exit 1
