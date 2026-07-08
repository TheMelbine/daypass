# /usr/lib/__PKG_NAME__/dnsmasq.sh — repoint dnsmasq at mihomo's DNS and back.
# Ported from podkop bin/podkop:339-433. Crash-safe: the 'shutdown_correctly'
# UCI flag records whether the last stop was clean, so a power-loss between
# takeover and restore doesn't back up our own (already-modified) settings as
# if they were the user's.
#
# While active: server=<DNS_ADDR>, noresolv=1, cachesize=0. cachesize MUST be 0
# because fake-ip answers must never be cached by dnsmasq.

_dnsmasq_backup_option() {
	local key="$1" backup_key="$2" value
	value="$(uci -q get "dhcp.@dnsmasq[0].$key")"
	[ -n "$value" ] && uci set "dhcp.@dnsmasq[0].$backup_key=$value"
}

dns_takeover() {
	[ "$(uci -q get "${PKG_NAME}.settings.dont_touch_dhcp")" = "1" ] && return 0
	[ "$(uci -q get "${PKG_NAME}.settings.shutdown_correctly")" = "0" ] && {
		log "previous shutdown was not clean; dnsmasq backup already authoritative"
		return 0
	}

	local server
	for server in $(uci -q get "dhcp.@dnsmasq[0].server"); do
		[ "$server" = "$DNS_ADDR" ] && continue
		uci add_list "dhcp.@dnsmasq[0].${PKG_NAME}_server=$server"
	done
	uci -q delete "dhcp.@dnsmasq[0].server"

	_dnsmasq_backup_option noresolv "${PKG_NAME}_noresolv"
	_dnsmasq_backup_option cachesize "${PKG_NAME}_cachesize"

	uci add_list "dhcp.@dnsmasq[0].server=$DNS_ADDR"
	uci set "dhcp.@dnsmasq[0].noresolv=1"
	uci set "dhcp.@dnsmasq[0].cachesize=0"
	uci commit dhcp
	/etc/init.d/dnsmasq restart
}

dns_restore() {
	[ "$(uci -q get "${PKG_NAME}.settings.dont_touch_dhcp")" = "1" ] && return 0
	[ "$(uci -q get "${PKG_NAME}.settings.shutdown_correctly")" = "1" ] && return 0

	local cachesize noresolv backup_servers server resolvfile

	cachesize="$(uci -q get "dhcp.@dnsmasq[0].${PKG_NAME}_cachesize")"
	if [ -z "$cachesize" ]; then
		uci set "dhcp.@dnsmasq[0].cachesize=150"
	else
		uci set "dhcp.@dnsmasq[0].cachesize=$cachesize"
		uci -q delete "dhcp.@dnsmasq[0].${PKG_NAME}_cachesize"
	fi

	noresolv="$(uci -q get "dhcp.@dnsmasq[0].${PKG_NAME}_noresolv")"
	if [ -z "$noresolv" ]; then
		uci set "dhcp.@dnsmasq[0].noresolv=0"
	else
		uci set "dhcp.@dnsmasq[0].noresolv=$noresolv"
		uci -q delete "dhcp.@dnsmasq[0].${PKG_NAME}_noresolv"
	fi

	uci -q delete "dhcp.@dnsmasq[0].server"
	backup_servers="$(uci -q get "dhcp.@dnsmasq[0].${PKG_NAME}_server")"
	if [ -n "$backup_servers" ]; then
		for server in $backup_servers; do
			uci add_list "dhcp.@dnsmasq[0].server=$server"
		done
		uci -q delete "dhcp.@dnsmasq[0].${PKG_NAME}_server"
	else
		resolvfile="/tmp/resolv.conf.d/resolv.conf.auto"
		if [ -f "$resolvfile" ]; then
			uci set "dhcp.@dnsmasq[0].resolvfile=$resolvfile"
			uci set "dhcp.@dnsmasq[0].noresolv=0"
		else
			log "no dnsmasq server backup and no resolvfile; DNS may be degraded"
		fi
	fi

	uci commit dhcp
	/etc/init.d/dnsmasq restart
}
