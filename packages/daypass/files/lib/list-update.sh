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

	local section proxy enabled tag url n=0

	# Collect subnet sources from every enabled route section.
	config_load "$PKG_NAME" 2>/dev/null

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

	config_foreach _lu_collect_route route

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
