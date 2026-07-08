#!/bin/sh
# verify-pkg.sh — host-side artifact verification for daypass packages.
#
#   scripts/verify-pkg.sh [OUT_DIR]        (default OUT_DIR: out)
#
# For every out/<brand>-<format>/ dir it unpacks all .apk/.ipk into one merged
# install tree and asserts:
#   1. the tree uses brand-named paths:
#        /etc/config/<brand>, /etc/init.d/<brand>, .../view/<brand>/,
#        .../menu.d/luci-app-<brand>.json, .../rpcd/ucode/luci.<brand>
#   2. ZERO remaining __TOKEN__ placeholders anywhere in the payload
#   3. the OTHER brand's package/display name never appears in INSTALLED files
#      (package control metadata legitimately carries Conflicts:/replaces:, so
#       control dotfiles / control.tar are excluded from this scan)
#   4. shell scripts pass 'sh -n'
#   5. JSON files parse (jq, or python3 fallback)
#
# Exits nonzero on any failure. Needs: tar, ar (for classic ipk), od/dd, grep,
# sed, find; jq or python3 for JSON.
set -u

OUT=${1:-out}
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT"

FAILS=0
ok()  { printf '  PASS %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; FAILS=$((FAILS + 1)); }

# --- brand metadata from branding/*.mk -------------------------------------
brand_pkg_of()  { sed -n 's/^BRAND_PKG[[:space:]]*:=[[:space:]]*//p'  "branding/$1.mk" 2>/dev/null | sed 's/[[:space:]]*$//' | head -1; }
brand_name_of() { sed -n 's/^BRAND_NAME[[:space:]]*:=[[:space:]]*//p' "branding/$1.mk" 2>/dev/null | sed 's/[[:space:]]*$//' | head -1; }
all_brands() { for f in branding/*.mk; do b=${f##*/}; b=${b%.mk}; [ "$b" = brand ] && continue; echo "$b"; done; }

# --- unpack one package into $2/rootfs (+ $2/control for classic ipk) -------
unpack_pkg() {
  file=$1; dest=$2
  mkdir -p "$dest/rootfs"
  magic=$(dd if="$file" bs=8 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
  case $magic in
    213c617263683e0a*)   # "!<arch>\n" -> classic ipk (ar of control.tar/data.tar)
      command -v ar >/dev/null 2>&1 || { bad "'ar' not installed; cannot unpack $file"; return 1; }
      tmp=$(mktemp -d)
      ( cd "$tmp" && ar x "$file" )
      for d in "$tmp"/data.tar.*;    do [ -e "$d" ] && tar -xf "$d" -C "$dest/rootfs"; done
      mkdir -p "$dest/control"
      for c in "$tmp"/control.tar.*; do [ -e "$c" ] && tar -xf "$c" -C "$dest/control"; done
      rm -rf "$tmp"
      ;;
    1f8b*)               # gzip -> apk (one tar; control lives as .PKGINFO dotfiles) or tarball-ipk
      tar -xf "$file" -C "$dest/rootfs" || { bad "cannot untar $file"; return 1; }
      ;;
    *)                   # let tar autodetect xz/zstd
      tar -xf "$file" -C "$dest/rootfs" 2>/dev/null || { bad "unknown package format: $file"; return 1; }
      ;;
  esac
  return 0
}

merge_into() {  # merge_into SRC_ROOTFS DEST_ROOTFS
  ( cd "$1" && tar -cf - . ) | ( cd "$2" && tar -xf - )
}

json_ok() {
  if command -v jq >/dev/null 2>&1; then jq -e . "$1" >/dev/null 2>&1
  elif command -v python3 >/dev/null 2>&1; then python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" >/dev/null 2>&1
  else return 2
  fi
}

[ -d "$OUT" ] || { echo "verify-pkg: '$OUT' not found" >&2; exit 1; }

DIRS=$(find "$OUT" -type f \( -name '*.apk' -o -name '*.ipk' \) -exec dirname {} \; | sort -u)
[ -n "$DIRS" ] || { echo "verify-pkg: no .apk/.ipk artifacts under '$OUT'" >&2; exit 1; }

for dir in $DIRS; do
  base=${dir##*/}                 # <brand>-<format>
  format=${base##*-}             # apk | ipk
  brand=${base%-"$format"}       # <brand>

  echo "== $base (brand=$brand format=$format) =="

  if [ -f "branding/$brand.mk" ]; then pkg=$(brand_pkg_of "$brand"); else pkg=$brand; fi
  [ -n "$pkg" ] || pkg=$brand

  work=$(mktemp -d)
  merged="$work/merged"; mkdir -p "$merged/rootfs"

  for f in "$dir"/*."$format"; do
    [ -e "$f" ] || continue
    printf '  unpack %s\n' "$(basename "$f")"
    one="$work/$(basename "$f").d"
    unpack_pkg "$f" "$one" || continue
    merge_into "$one/rootfs" "$merged/rootfs"
    [ -d "$one/control" ] && { mkdir -p "$merged/control"; merge_into "$one/control" "$merged/control"; }
  done

  R="$merged/rootfs"

  # 1. brand-named paths (aggregate across all packages of this brand/format)
  find "$R" -path "*/etc/config/$pkg"           2>/dev/null | grep -q . && ok "/etc/config/$pkg"           || bad "missing /etc/config/$pkg"
  find "$R" -path "*/etc/init.d/$pkg"           2>/dev/null | grep -q . && ok "/etc/init.d/$pkg"           || bad "missing /etc/init.d/$pkg"
  find "$R" -type d -path "*/view/$pkg"         2>/dev/null | grep -q . && ok "view/$pkg/"                 || bad "missing .../view/$pkg/"
  find "$R" -path "*/menu.d/luci-app-$pkg.json" 2>/dev/null | grep -q . && ok "menu.d/luci-app-$pkg.json"  || bad "missing menu.d/luci-app-$pkg.json"
  find "$R" -path "*/rpcd/ucode/luci.$pkg"      2>/dev/null | grep -q . && ok "rpcd/ucode/luci.$pkg"       || bad "missing rpcd/ucode/luci.$pkg"

  # 2. zero __TOKEN__ placeholders anywhere in the payload (data + control)
  toks=$(grep -ralE '__[A-Z][A-Z0-9_]*__' "$merged" 2>/dev/null || true)
  if [ -n "$toks" ]; then
    bad "unreplaced __TOKEN__ placeholders:"
    printf '%s\n' "$toks" | sed "s|$merged/||; s|^|        |"
    grep -rhoaE '__[A-Z][A-Z0-9_]*__' "$merged" 2>/dev/null | sort -u | sed 's|^|        token: |'
  else
    ok "no __TOKEN__ placeholders"
  fi

  # 3. sibling-brand leakage in INSTALLED files (exclude control dotfiles/metadata)
  other_hit=0
  for ob in $(all_brands); do
    [ "$ob" = "$brand" ] && continue
    op=$(brand_pkg_of "$ob"); on=$(brand_name_of "$ob")
    hits=""
    [ -n "$op" ] && hits="$hits
$(grep -ralF --exclude='.*' -- "$op" "$R" 2>/dev/null || true)
$(find "$R" -path "*$op*" ! -name '.*' 2>/dev/null || true)"
    [ -n "$on" ] && hits="$hits
$(grep -ralF --exclude='.*' -- "$on" "$R" 2>/dev/null || true)"
    hits=$(printf '%s\n' "$hits" | grep -v '^[[:space:]]*$' | sort -u)
    if [ -n "$hits" ]; then
      bad "sibling brand '$op'/'$on' (from $ob) leaks into installed files:"
      printf '%s\n' "$hits" | sed "s|$merged/||; s|^|        |"
      other_hit=1
    fi
  done
  [ "$other_hit" = 0 ] && ok "no sibling-brand leakage"

  # 4. shell syntax (detect by shebang)
  sh_fail=0
  for f in $(find "$merged" -type f 2>/dev/null); do
    first=$(head -1 "$f" 2>/dev/null || true)
    case $first in
      '#!'*sh*)
        if ! err=$(sh -n "$f" 2>&1); then
          bad "sh -n: ${f#"$merged"/}"; printf '%s\n' "$err" | sed 's|^|        |'; sh_fail=1
        fi ;;
    esac
  done
  [ "$sh_fail" = 0 ] && ok "shell scripts pass sh -n"

  # 5. JSON validity
  json_fail=0; json_seen=0
  for j in $(find "$merged" -type f -name '*.json' 2>/dev/null); do
    json_seen=1
    if json_ok "$j"; then :; else
      rc=$?
      if [ "$rc" = 2 ]; then echo "  WARN no jq/python3 — skipping JSON parse"; break; fi
      bad "invalid JSON: ${j#"$merged"/}"; json_fail=1
    fi
  done
  [ "$json_fail" = 0 ] && [ "$json_seen" = 1 ] && ok "JSON files parse"

  rm -rf "$work"
  echo
done

if [ "$FAILS" -gt 0 ]; then
  echo "verify-pkg: $FAILS failure(s)"
  exit 1
fi
echo "verify-pkg: all checks passed"
