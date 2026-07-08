#!/bin/sh
# 08-luci-menu — the LuCI app is installed and its rpcd ubus object answers.
# Asserts the brand-named LuCI files exist and (if rpcd is up) luci.<name>
# version() returns {app, core}.
NAME="${NAME:-$(for c in /etc/config/*; do b=${c##*/}; [ -x "/usr/bin/$b" ] && [ -x "/etc/init.d/$b" ] && { echo "$b"; break; }; done)}"
[ -n "${NAME:-}" ] || { echo "FAIL 08-luci-menu: no installed brand detected"; exit 1; }

menu="/usr/share/luci/menu.d/luci-app-$NAME.json"
rpcd="/usr/share/rpcd/ucode/luci.$NAME"
view=$(find /www/luci-static -type d -path "*/view/$NAME" 2>/dev/null | head -1)

if [ ! -f "$menu" ] && [ ! -f "$rpcd" ] && [ -z "$view" ]; then
  echo "SKIP 08-luci-menu: no LuCI app installed for $NAME (luci-app package not present)"
  exit 77
fi

miss=""
[ -f "$menu" ] || miss="$miss menu.d/luci-app-$NAME.json"
[ -f "$rpcd" ] || miss="$miss rpcd/ucode/luci.$NAME"
[ -n "$view" ] || miss="$miss www/.../view/$NAME/"
if [ -n "$miss" ]; then
  echo "FAIL 08-luci-menu: LuCI files missing:$miss"
  exit 1
fi

# rpcd object (best-effort — needs rpcd running with the plugin loaded)
if command -v ubus >/dev/null 2>&1; then
  out=$(ubus call "luci.$NAME" version 2>/dev/null)
  case $out in
    *app*core*|*core*app*)
      echo "PASS 08-luci-menu: LuCI files present; ubus luci.$NAME version -> $out"
      exit 0 ;;
    *)
      echo "FAIL 08-luci-menu: files present but 'ubus call luci.$NAME version' did not return {app,core}: '$out'"
      exit 1 ;;
  esac
fi

echo "PASS 08-luci-menu: LuCI files present (menu.d, rpcd/ucode, view/$NAME); ubus not available to probe"
exit 0
