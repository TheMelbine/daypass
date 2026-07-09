# /usr/lib/__PKG_NAME__/list-update.sh — refresh the subnets4 nft set.
# Domain lists are mihomo's job (mrs rule-providers auto-refresh). Only raw-IP
# subnet lists need shell: community <tag>.lst, remote subnet URLs and inline
# user subnets are gathered here and loaded into the nft set. Ported from the
# podkop list_update flow (bin/podkop:482-548,1278-1346).

# shellcheck source=/dev/null
. /usr/lib/__PKG_NAME__/env.sh
# shellcheck source=/dev/null
. /usr/lib/__PKG_NAME__/nftset.sh

_lu_tmp="/tmp/${PKG_NAME}_lists"

# download <url> <dest> — curl with retries; returns non-zero on failure.
_lu_download() {
	curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 -o "$2" "$1"
}

# _lu_catalog_has_subnets <tag> -> 0 if the community tag ships an IPv4 .lst
_lu_catalog_has_subnets() {
	[ "$(jsonfilter -i "$CATALOG_PATH" -e "@.lists[@.tag='$1'].subnets" 2>/dev/null)" = "true" ]
}

# _lu_gate — wait for connectivity before hammering mirrors (best-effort).
_lu_gate() {
	local i
	for i in 1 2 3 4 5; do
		curl -fsI --connect-timeout 5 "$LISTS_BASE" >/dev/null 2>&1 && return 0
		sleep 3
	done
	return 0
}

list_update() {
	# single-flight
	if [ -f "$LIST_UPDATE_PID" ] && kill -0 "$(cat "$LIST_UPDATE_PID" 2>/dev/null)" 2>/dev/null; then
		log "list_update already running"
		return 0
	fi
	echo $$ > "$LIST_UPDATE_PID"

	nft list table inet "$NFT_TABLE" >/dev/null 2>&1 || {
		log "nft table absent; skipping list_update"
		rm -f "$LIST_UPDATE_PID"
		return 0
	}

	_lu_gate
	rm -rf "$_lu_tmp"
	mkdir -p "$_lu_tmp"

	local section proxy enabled tag url n=0 routing_mode

	# Collect subnet sources from every enabled route section.
	config_load "$PKG_NAME" 2>/dev/null

	routing_mode="$(uci -q get "${PKG_NAME}.settings.routing_mode")"
	[ -n "$routing_mode" ] || routing_mode="selective"

	_lu_collect_route() {
		local s="$1"
		config_get enabled "$s" enabled 0
		[ "$enabled" = "1" ] || return 0

		# community <tag>.lst (only tags that actually have subnets)
		config_list_foreach "$s" community_lists _lu_community
		# remote subnet list URLs
		config_list_foreach "$s" remote_subnet_lst _lu_remote
		# inline user subnets
		config_list_foreach "$s" user_subnets _lu_user
	}
	_lu_community() {
		_lu_catalog_has_subnets "$1" || return 0
		n=$((n + 1))
		_lu_download "${SUBNETS_BASE}/${1}.lst" "${_lu_tmp}/c_${1}.lst" \
			|| log "download failed: ${1}.lst"
	}
	_lu_remote() {
		n=$((n + 1))
		_lu_download "$1" "${_lu_tmp}/r_${n}.lst" \
			|| log "download failed: $1"
	}
	_lu_user() {
		echo "$1" >> "${_lu_tmp}/user.lst"
	}

	# In selective mode, ipcidr rule-sets must have their CIDRs in the nft set so
	# the traffic is marked and reaches mihomo (mihomo's own RULE-SET then routes
	# it). We get the CIDRs straight out of the rule-set file: mihomo compiles
	# .mrs one-way, but `convert-ruleset ipcidr mrs <in> <out>` dumps it back to
	# plain CIDR text — no external list or decompiler needed. yaml/text/classical
	# rule-sets are already text; strip any "IP-CIDR," prefix. In full mode every
	# LAN packet is marked anyway, so this whole pass is skipped.
	_lu_ruleset() {
		local s="$1" beh fmt file url ext src out mb
		config_get enabled "$s" enabled 0
		[ "$enabled" = "1" ] || return 0
		config_get beh "$s" behavior domain
		[ "$beh" = "ipcidr" ] || return 0
		config_get fmt "$s" format mrs
		config_get file "$s" file ""
		config_get url "$s" url ""

		if [ -n "$file" ]; then
			src="$file"
		else
			case "$fmt" in mrs) ext=mrs ;; yaml) ext=yaml ;; *) ext=txt ;; esac
			src="${PROVIDERS_DIR}/rule/${s}.${ext}"
			# mihomo may not have fetched it yet (async on boot); grab our own copy.
			[ -f "$src" ] || { _lu_download "$url" "${_lu_tmp}/rs_${s}.${ext}" \
				&& src="${_lu_tmp}/rs_${s}.${ext}"; }
		fi
		[ -f "$src" ] || { log "ruleset $s: source missing ($src)"; return 0; }

		out="${_lu_tmp}/rs_${s}.lst"
		case "$fmt" in
			mrs)
				mb="$(mihomo_bin)" || { log "ruleset $s: no mihomo to decompile mrs"; return 0; }
				"$mb" convert-ruleset ipcidr mrs "$src" "$out" >/dev/null 2>&1 \
					|| { log "ruleset $s: mrs decompile failed"; rm -f "$out"; return 0; }
				;;
			yaml)
				sed -n 's/^[[:space:]]*-[[:space:]]*//p' "$src" > "$out"
				;;
			*)
				sed -e 's/^[[:space:]]*//' -e 's/^IP-CIDR6\{0,1\},//' -e 's/,.*$//' "$src" > "$out"
				;;
		esac
		n=$((n + 1))
		log "ruleset $s: loaded $(wc -l < "$out" 2>/dev/null) cidrs from $fmt"
	}

	config_foreach _lu_collect_route route
	[ "$routing_mode" = "selective" ] && config_foreach _lu_ruleset ruleset

	# Reload the set atomically-ish: flush then bulk-load everything we fetched.
	nft_flush_set "$NFT_SUBNET_SET"
	for f in "$_lu_tmp"/*.lst; do
		[ -f "$f" ] || continue
		nft_load_subnets_from_file "$f"
	done

	rm -rf "$_lu_tmp"
	rm -f "$LIST_UPDATE_PID"
	log "list_update done"
}
