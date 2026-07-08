#!/bin/sh
# daypass installer for OpenWrt. Usage (on the router):
#   sh <(wget -qO- https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh)
# or
#   wget -qO /tmp/daypass-install.sh https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh && sh /tmp/daypass-install.sh
#
# Downloads the latest release (mihomo core + daypass + luci-app-daypass, matching
# the router's architecture) and installs them. mihomo is NOT in the official
# OpenWrt feed, so we ship it ourselves. Modeled on itdoginfo/podkop's installer.

set -u

# --- brand / source (the only brand-specific bits) ---
GH_OWNER="TheMelbine"
GH_REPO="daypass"
PKG="daypass"                    # core package name == /etc/config/<PKG>, /etc/init.d/<PKG>
BRAND="Daypass"

API="https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/releases/latest"
DOWNLOAD_DIR="/tmp/${PKG}-install"
COUNT=3

# Package-manager abstraction (opkg on 24.10, apk on 25.12+).
PKG_IS_APK=0
command -v apk >/dev/null 2>&1 && PKG_IS_APK=1
if [ "$PKG_IS_APK" -eq 1 ]; then EXT="apk"; else EXT="ipk"; fi

msg() { echo ">>> $*"; }
die() { echo "!!! $*" >&2; exit 1; }

pkg_installed() {
	if [ "$PKG_IS_APK" -eq 1 ]; then apk list --installed 2>/dev/null | grep -q "^$1-"; else opkg list-installed 2>/dev/null | grep -q "^$1 "; fi
}
pkg_update() {
	if [ "$PKG_IS_APK" -eq 1 ]; then apk update; else opkg update; fi
}
pkg_install_feed() {
	# install a dependency from the official feed; ignore "already installed"
	if [ "$PKG_IS_APK" -eq 1 ]; then apk add "$@" 2>/dev/null; else opkg install "$@" 2>/dev/null; fi
	return 0
}
pkg_install_file() {
	if [ "$PKG_IS_APK" -eq 1 ]; then apk add --allow-untrusted "$1"; else opkg install --force-reinstall "$1"; fi
}
pkg_remove() {
	if [ "$PKG_IS_APK" -eq 1 ]; then apk del "$1" 2>/dev/null; else opkg remove --force-depends "$1" 2>/dev/null; fi
	return 0
}

check_system() {
	[ -f /etc/openwrt_release ] || die "This does not look like OpenWrt."
	local model ver space
	model=$(cat /tmp/sysinfo/model 2>/dev/null || echo unknown)
	ARCH=$(. /etc/openwrt_release 2>/dev/null; echo "$DISTRIB_ARCH")
	ver=$(sed -n "s/^DISTRIB_RELEASE=.\\([0-9]*\\).*/\\1/p" /etc/openwrt_release)
	msg "Router: $model | arch: ${ARCH:-?} | OpenWrt: ${ver:-?} | pkg: $EXT"

	[ -n "$ARCH" ] || die "Could not detect DISTRIB_ARCH from /etc/openwrt_release."

	# flash space (need ~20MB: mihomo ~15MB + our packages)
	space=$(df /overlay 2>/dev/null | awk 'NR==2 {print $4}')
	if [ -n "$space" ] && [ "$space" -lt 20480 ]; then
		die "Not enough free space on /overlay: $((space/1024))MB (need ~20MB)."
	fi

	nslookup openwrt.org >/dev/null 2>&1 || die "DNS is not working — fix connectivity first."
}

install_deps() {
	msg "Updating package lists..."
	pkg_update || die "package list update failed"
	msg "Installing runtime dependencies from the official feed..."
	# firewall4 is default on 24.10/25.12; the rest are the daypass runtime deps.
	pkg_install_feed kmod-nft-tproxy ip-full ca-bundle curl jsonfilter \
		ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus
}

# Download every release asset matching our packages for this arch.
download_release() {
	rm -rf "$DOWNLOAD_DIR"; mkdir -p "$DOWNLOAD_DIR"

	local body
	body=$(wget -qO- "$API" 2>/dev/null || curl -fsSL "$API" 2>/dev/null)
	[ -n "$body" ] || die "Could not fetch release info from GitHub (is the repo public / are you rate-limited?)."
	echo "$body" | grep -q '"message": *"Not Found"' && die "No published release yet for ${GH_OWNER}/${GH_REPO}."

	# asset URLs for our format
	local urls
	urls=$(echo "$body" | grep -o "https://[^\"[:space:]]*\\.${EXT}")
	[ -n "$urls" ] || die "Release has no .$EXT assets."

	# Keep: mihomo for THIS arch, plus the arch-independent (_all / -all) daypass packages.
	local got=0 url name
	for url in $urls; do
		name=$(basename "$url")
		case "$name" in
			mihomo[_-]*)
				# only the asset matching our arch
				echo "$name" | grep -q "$ARCH" || continue ;;
			${PKG}[_-]*|luci-app-${PKG}[_-]*|luci-i18n-${PKG}-*) : ;;
			*) continue ;;
		esac
		_fetch "$url" "$DOWNLOAD_DIR/$name" && got=$((got+1))
	done
	[ "$got" -gt 0 ] || die "Nothing matched arch '$ARCH' — is a build for your arch published?"
}

_fetch() {
	local url="$1" out="$2" i=0
	while [ "$i" -lt "$COUNT" ]; do
		msg "Downloading $(basename "$out") ($((i+1))/$COUNT)..."
		if wget -qO "$out" "$url" 2>/dev/null || curl -fsSL -o "$out" "$url" 2>/dev/null; then
			[ -s "$out" ] && return 0
		fi
		rm -f "$out"; i=$((i+1))
	done
	msg "failed: $(basename "$out")"; return 1
}

install_packages() {
	# order matters: mihomo (dependency) -> core -> luci-app
	local f
	for pat in "mihomo" "${PKG}" "luci-app-${PKG}"; do
		f=$(ls "$DOWNLOAD_DIR"/${pat}[_-]*."$EXT" 2>/dev/null | head -1)
		[ -n "$f" ] || { [ "$pat" = "mihomo" ] && die "mihomo package missing from release"; continue; }
		msg "Installing $(basename "$f")..."
		pkg_install_file "$f" || die "install failed: $(basename "$f")"
	done

	# optional Russian LuCI translation
	local ru
	ru=$(ls "$DOWNLOAD_DIR"/luci-i18n-${PKG}-ru*."$EXT" 2>/dev/null | head -1)
	if [ -n "$ru" ]; then
		printf ">>> Install Russian LuCI translation? [y/N] "
		read -r ans
		case "$ans" in y|Y) pkg_install_file "$ru" || true ;; esac
	fi
}

finish() {
	rm -rf "$DOWNLOAD_DIR"
	msg ""
	msg "${BRAND} installed."
	msg "1) Open LuCI -> Services -> ${BRAND}, paste your vless:// / ss:// / trojan:// link,"
	msg "   pick the lists to route, and enable the service."
	msg "2) Or via CLI: edit /etc/config/${PKG}, then: /etc/init.d/${PKG} enable && /etc/init.d/${PKG} start"
	msg ""
}

main() {
	check_system
	install_deps
	download_release
	install_packages
	finish
}

main
