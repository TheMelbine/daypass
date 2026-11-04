#!/bin/sh
# daypass installer for OpenWrt. Usage (on the router):
#   sh <(wget -qO- https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh)
# or
#   wget -qO /tmp/daypass-install.sh https://raw.githubusercontent.com/TheMelbine/daypass/master/install.sh && sh /tmp/daypass-install.sh
#
# Options (pass after the command above):
#   --preset ru-direct   RU sites go direct, everything else through the proxy
#   --key <link>         subscription URL or vless:// / ss:// / trojan:// link;
#                        the service starts right away when a key is given
#   --update             update an installed router: keeps its config, skips the
#                        download when already on the latest release
#   --force              with --update: reinstall even when up to date
# Example:
#   sh <(wget -qO- .../install.sh) --preset ru-direct --key 'https://example.com/sub'
#
# Downloads the latest release (mihomo core + daypass + luci-app-daypass, matching
# the router's architecture) and installs them. mihomo is NOT in the official
# OpenWrt feed, so we ship it ourselves.

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

PRESET=""
KEY=""
UPDATE=0
FORCE=0
RELEASE_FILE="/etc/${PKG}/release"
parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--preset) [ $# -ge 2 ] || die "--preset needs a value"; PRESET="$2"; shift 2 ;;
			--key)    [ $# -ge 2 ] || die "--key needs a value"; KEY="$2"; shift 2 ;;
			--update) UPDATE=1; shift ;;
			--force)  FORCE=1; shift ;;
			*) die "Unknown option: $1 (expected --preset ru-direct, --key <link>, --update, --force)" ;;
		esac
	done
	case "$PRESET" in
		""|ru-direct) : ;;
		*) die "Unknown preset: $PRESET (available: ru-direct)" ;;
	esac
}

pkg_installed() {
	if [ "$PKG_IS_APK" -eq 1 ]; then apk list --installed 2>/dev/null | grep -q "^$1-"; else opkg list-installed 2>/dev/null | grep -q "^$1 "; fi
}
pkg_version() {
	if [ "$PKG_IS_APK" -eq 1 ]; then
		apk list --installed 2>/dev/null | sed -n "s/^$1-\([0-9][^ ]*\) .*/\1/p" | head -1
	else
		opkg list-installed 2>/dev/null | awk -v p="$1" '$1 == p {print $3; exit}'
	fi
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

	# flash space. The full mihomo binary is ~43MB unpacked; on tight flash we
	# install the gzipped package (~16MB) and unpack to tmpfs at runtime instead.
	space=$(df /overlay 2>/dev/null | awk 'NR==2 {print $4}')

	# An update keeps the installed mihomo flavour and needs no fresh space for it.
	if [ "$UPDATE" -eq 1 ]; then
		pkg_installed "$PKG" || die "${BRAND} is not installed, run without --update."
		MIHOMO_VARIANT=mihomo
		pkg_installed mihomo-gz && MIHOMO_VARIANT=mihomo-gz
		nslookup openwrt.org >/dev/null 2>&1 || die "DNS is not working — fix connectivity first."
		return 0
	fi

	if [ -n "$space" ] && [ "$space" -lt 20480 ]; then
		die "Not enough free space on /overlay: $((space/1024))MB (need ~20MB)."
	fi

	# Pick the mihomo flavour by free flash.
	MIHOMO_VARIANT=mihomo
	if [ -z "$space" ] || [ "$space" -lt 61440 ]; then
		MIHOMO_VARIANT=mihomo-gz
	fi
	msg "mihomo flavour: $MIHOMO_VARIANT (free: $((${space:-0}/1024))MB)"

	nslookup openwrt.org >/dev/null 2>&1 || die "DNS is not working — fix connectivity first."
}

install_deps() {
	msg "Updating package lists..."
	pkg_update || die "package list update failed"

	# Install ONLY missing deps. Running `opkg install` on an already-present
	# base package (curl, ucode, ...) pulls the newest feed build and upgrades
	# it — a partial system upgrade that breaks ABI-coupled libraries (e.g. a new
	# curl against an old libcurl, new ucode mods against an old libucode) and
	# takes out LuCI. firewall4 is default on 24.10/25.12.
	local dep missing=""
	for dep in kmod-nft-tproxy ip-full ca-bundle curl jsonfilter \
		ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus; do
		pkg_installed "$dep" || missing="$missing $dep"
	done
	if [ -n "$missing" ]; then
		msg "Installing missing dependencies:$missing"
		# shellcheck disable=SC2086
		pkg_install_feed $missing
	else
		msg "All runtime dependencies already present — nothing to install."
	fi
}

# Download every release asset matching our packages for this arch.
download_release() {
	rm -rf "$DOWNLOAD_DIR"; mkdir -p "$DOWNLOAD_DIR"

	local body
	body=$(wget -qO- "$API" 2>/dev/null || curl -fsSL "$API" 2>/dev/null)
	[ -n "$body" ] || die "Could not fetch release info from GitHub (is the repo public / are you rate-limited?)."
	echo "$body" | grep -q '"message": *"Not Found"' && die "No published release yet for ${GH_OWNER}/${GH_REPO}."

	# Tag, not package version: same-day releases share a package version.
	TAG=$(echo "$body" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
	if [ "$UPDATE" -eq 1 ] && [ "$FORCE" -eq 0 ] && [ -n "$TAG" ] && \
		[ "$(cat "$RELEASE_FILE" 2>/dev/null)" = "$TAG" ]; then
		msg "Already on the latest release ($TAG)."
		exit 0
	fi

	# asset URLs for our format
	local urls
	urls=$(echo "$body" | grep -o "https://[^\"[:space:]]*\\.${EXT}")
	[ -n "$urls" ] || die "Release has no .$EXT assets."

	# Keep: mihomo for THIS arch, plus the arch-independent (_all / -all) daypass packages.
	local got=0 url name
	for url in $urls; do
		name=$(basename "$url")
		# mihomo-gz must be tested before mihomo (its name also starts "mihomo-").
		case "$name" in
			mihomo-gz[_-]*)
				[ "$MIHOMO_VARIANT" = "mihomo-gz" ] || continue
				echo "$name" | grep -q "$ARCH" || continue ;;
			mihomo[_-]*)
				[ "$MIHOMO_VARIANT" = "mihomo" ] || continue
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
	# order matters: mihomo core (satisfies daypass's dep) -> core -> luci-app
	local f
	for pat in "$MIHOMO_VARIANT" "${PKG}" "luci-app-${PKG}"; do
		f=$(ls "$DOWNLOAD_DIR"/${pat}[_-]*."$EXT" 2>/dev/null | head -1)
		[ -n "$f" ] || die "$pat package missing from release (download failed?)"
		# don't reinstall an unchanged core: it would stop traffic for nothing
		if [ "$UPDATE" -eq 1 ] && [ "$pat" = "$MIHOMO_VARIANT" ]; then
			case "$(basename "$f")" in
				*"$(pkg_version "$pat")"*) msg "$pat is up to date."; continue ;;
			esac
		fi
		msg "Installing $(basename "$f")..."
		pkg_install_file "$f" || die "install failed: $(basename "$f")"
	done

	# Point daypass at the gzipped binary when we installed the gz flavour.
	if [ "$MIHOMO_VARIANT" = "mihomo-gz" ]; then
		uci -q set "${PKG}.main.mihomo_gz=/usr/lib/mihomo-gz/mihomo.gz"
		uci -q commit "${PKG}"
	fi

	# Russian LuCI translation: tiny, and LuCI only uses it for a Russian UI, so
	# install it unconditionally — the installer must run without any prompts.
	local ru
	ru=$(ls "$DOWNLOAD_DIR"/luci-i18n-${PKG}-ru*."$EXT" 2>/dev/null | head -1)
	if [ -n "$ru" ]; then
		pkg_install_file "$ru" || msg "Russian translation failed to install, skipping."
	fi

	# Pick up the new rpcd methods and menu on upgrades, without a reboot.
	rm -f /tmp/luci-indexcache* /var/luci-indexcache*
	[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart

	[ -n "${TAG:-}" ] && echo "$TAG" > "$RELEASE_FILE"

	# Reinstalling stops the service; bring it back if it was switched on.
	if [ "$UPDATE" -eq 1 ] && [ "$(uci -q get "${PKG}.main.enabled")" = "1" ]; then
		msg "Restarting ${BRAND}..."
		/etc/init.d/"$PKG" restart || die "${BRAND} failed to start, check: logread -e ${PKG}"
	fi
	return 0
}

_ruleset() {
	# name behavior url — a DIRECT rule-set; appended after the shipped ones so
	# RU-blocked resources still match their PROXY rules first
	uci -q set "${PKG}.$1=ruleset"
	uci -q set "${PKG}.$1.enabled=1"
	uci -q set "${PKG}.$1.behavior=$2"
	uci -q set "${PKG}.$1.format=mrs"
	uci -q set "${PKG}.$1.action=DIRECT"
	uci -q set "${PKG}.$1.url=$3"
	uci -q set "${PKG}.$1.interval=86400"
}

apply_preset() {
	[ "$PRESET" = "ru-direct" ] || return 0
	local base="https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/refs/heads/meta/geo"
	msg "Applying preset: RU direct, everything else through the proxy..."
	uci -q set "${PKG}.settings.routing_mode=full"
	uci -q set "${PKG}.settings.match_action=PROXY"
	_ruleset ru_domains domain "$base/geosite/category-ru.mrs"
	_ruleset ru_ips ipcidr "$base/geoip/ru.mrs"
	uci -q del_list "${PKG}.settings.append_rules=DOMAIN-SUFFIX,ru,DIRECT"
	uci -q add_list "${PKG}.settings.append_rules=DOMAIN-SUFFIX,ru,DIRECT"
	uci -q commit "$PKG"
}

apply_key() {
	[ -n "$KEY" ] || return 0
	msg "Adding your key and starting ${BRAND}..."
	case "$KEY" in
		http://*|https://*)
			uci -q set "${PKG}.my_sub=subscription"
			uci -q set "${PKG}.my_sub.enabled=1"
			uci -q set "${PKG}.my_sub.url=$KEY"
			uci -q set "${PKG}.my_sub.user_agent=clash.meta"
			;;
		*://*)
			uci -q del_list "${PKG}.PROXY.links=$KEY"
			uci -q add_list "${PKG}.PROXY.links=$KEY"
			;;
		*) die "--key must be a subscription URL or a share link" ;;
	esac
	uci -q set "${PKG}.main.enabled=1"
	uci -q commit "$PKG"
	/etc/init.d/"$PKG" enable
	/etc/init.d/"$PKG" restart || die "${BRAND} failed to start, check: logread -e ${PKG}"
}

finish() {
	rm -rf "$DOWNLOAD_DIR"
	if [ "$UPDATE" -eq 1 ]; then
		msg "${BRAND} updated to ${TAG:-latest}. Refresh the panel with Ctrl+F5."
		return 0
	fi
	msg ""
	msg "${BRAND} installed."
	local ip
	ip=$(uci -q get network.lan.ipaddr)
	ip=${ip%%/*}
	msg "1) Open http://${ip:-<router-ip>}/${PKG}/ or LuCI -> Services -> ${BRAND},"
	msg "   paste your vless:// / ss:// / trojan:// link, pick the lists to route, and enable the service."
	msg "2) Or via CLI: edit /etc/config/${PKG}, then: /etc/init.d/${PKG} enable && /etc/init.d/${PKG} start"
	msg ""
}

main() {
	parse_args "$@"
	check_system
	install_deps
	download_release
	install_packages
	apply_preset
	apply_key
	finish
}

main "$@"
