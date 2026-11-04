# /usr/lib/__PKG_NAME__/account.sh — provider account (login via Telegram bot).
#
# TV-style code flow: the UI shows a link to the provider bot, the bot sends the
# user a one-time code, the code is exchanged here for a JWT session. The
# session lives in a curl cookie jar (0600); the subscription URL is then pulled
# from the provider API and written into a managed uci subscription section.
# The whole feature is disabled when the brand ships no ACCOUNT_API.

ACCOUNT_JAR="${HOME_DIR}/account.cookies"
ACCOUNT_STATE="${HOME_DIR}/account.json"
ACCOUNT_RAW="${HOME_DIR}/account-config.json"
ACCOUNT_LINKS="${HOME_DIR}/account-links.lst"
ACCOUNT_SECTION="provider_account"

account_enabled() { [ -n "$ACCOUNT_API" ]; }

_account_curl() {
	curl -s --max-time 20 \
		-b "$ACCOUNT_JAR" -c "$ACCOUNT_JAR" \
		-H 'Content-Type: application/json' "$@"
}

_account_state_write() {
	umask 077
	printf '%s\n' "$1" > "$ACCOUNT_STATE"
}

# Stable per-router id for the bot start payload (no PII, survives reboots).
_account_device_id() {
	local mac
	mac="$(cat /sys/class/net/br-lan/address 2>/dev/null)"
	[ -n "$mac" ] || mac="$PKG_NAME"
	printf 'rt-%s' "$mac" | md5sum | cut -c1-16
}

_account_bot_url() {
	printf '%s?start=tva_%s' "$ACCOUNT_BOT" "$(_account_device_id)"
}

# account_link -> { enabled, bot_url } for the UI login screen
cmd_account_link() {
	if ! account_enabled; then
		echo '{"enabled":false}'
		return 0
	fi
	printf '{"enabled":true,"bot_url":"%s"}\n' "$(_account_bot_url)"
}

# account_login <code> -> logs in with the one-time code from the bot,
# then syncs the subscription.
cmd_account_login() {
	local code http detail body
	account_enabled || { echo '{"error":"account feature disabled"}'; return 1; }
	# the code is user input: keep only safe characters before it hits a shell string
	code="$(printf '%s' "$1" | tr -cd 'A-Za-z0-9_-')"
	[ -n "$code" ] || { echo '{"error":"code required"}'; return 1; }
	umask 077
	mkdir -p "$HOME_DIR"
	body="{\"login\":null,\"code\":\"${code}\",\"platform\":\"${ACCOUNT_PLATFORM}\"}"
	http="$(_account_curl -o "${ACCOUNT_RAW}.login" -w '%{http_code}' \
		-X POST --data "$body" "${ACCOUNT_API}/api/v1/auth/login")"
	if [ "$http" != "200" ]; then
		detail="$(jsonfilter -i "${ACCOUNT_RAW}.login" -e '@.detail' 2>/dev/null | head -c 200)"
		rm -f "${ACCOUNT_RAW}.login"
		printf '{"error":"login_failed","http":"%s","detail":"%s"}\n' "$http" "$detail"
		return 1
	fi
	rm -f "${ACCOUNT_RAW}.login"
	_account_state_write "{\"logged_in\":true,\"logged_in_at\":$(date +%s)}"
	log "account: logged in"
	cmd_account_sync
}

# Refresh the JWT pair via the refresh cookie. Returns non-zero when the
# session is gone for good (user must log in again).
_account_refresh() {
	local http
	http="$(_account_curl -o /dev/null -w '%{http_code}' \
		-H "X-Idempotency-Key: $(cat /proc/sys/kernel/random/uuid)" \
		-X POST "${ACCOUNT_API}/api/v1/auth/refresh")"
	[ "$http" = "200" ]
}

# account_sync -> pulls the VPN configuration from the provider and installs
# its subscription URL as a managed uci subscription (idempotent).
cmd_account_sync() {
	local url http tries sub_url path refreshed proxy_sec
	account_enabled || { echo '{"error":"account feature disabled"}'; return 1; }
	[ -f "$ACCOUNT_JAR" ] || { echo '{"error":"not_logged_in"}'; return 1; }
	url="${ACCOUNT_API}/api/v2/applications/${ACCOUNT_PLATFORM}/vpn-configurations"
	# ensure a configuration exists server-side (idempotent, 202 + task)
	_account_curl -o /dev/null -X POST --data '{}' "$url"
	tries=0 refreshed=0
	while :; do
		http="$(_account_curl -o "$ACCOUNT_RAW" -w '%{http_code}' "$url")"
		if [ "$http" = "401" ] && [ "$refreshed" = "0" ]; then
			refreshed=1
			if ! _account_refresh; then
				_account_state_write '{"logged_in":false}'
				echo '{"error":"session_expired"}'
				return 1
			fi
			continue
		fi
		if [ "$http" = "200" ] && ! grep -q '"config"[[:space:]]*:[[:space:]]*null' "$ACCOUNT_RAW"; then
			break
		fi
		tries=$((tries + 1))
		[ $tries -ge 10 ] && { echo '{"error":"config_not_ready"}'; return 1; }
		sleep 2
	done
	chmod 600 "$ACCOUNT_RAW" 2>/dev/null
	# provider payload shape differs per backend version — try the known spots
	for path in '@.config.access_url' '@.config[0].access_url' \
	            '@.config.subscription_url' '@.config[0].subscription_url'; do
		sub_url="$(jsonfilter -i "$ACCOUNT_RAW" -e "$path" 2>/dev/null)"
		[ -n "$sub_url" ] && break
	done
	if [ -n "$sub_url" ]; then
		uci -q batch <<-EOF
			set ${PKG_NAME}.${ACCOUNT_SECTION}=subscription
			set ${PKG_NAME}.${ACCOUNT_SECTION}.enabled=1
			set ${PKG_NAME}.${ACCOUNT_SECTION}.url=${sub_url}
			set ${PKG_NAME}.${ACCOUNT_SECTION}.user_agent=clash.meta
			commit ${PKG_NAME}
		EOF
		# make sure the managed subscription is a member of the first proxy group
		proxy_sec="$(uci -q show "$PKG_NAME" | sed -n "s/^${PKG_NAME}\.\([^.=]*\)=proxy$/\1/p" | head -n1)"
		if [ -n "$proxy_sec" ]; then
			uci -q del_list "${PKG_NAME}.${proxy_sec}.subscriptions=${ACCOUNT_SECTION}"
			uci -q add_list "${PKG_NAME}.${proxy_sec}.subscriptions=${ACCOUNT_SECTION}"
			uci -q commit "$PKG_NAME"
		fi
	else
		# no URL — some platforms ship raw per-node xray configs instead;
		# convert them to share links and manage them on the first proxy group
		_account_install_links || return 1
	fi
	_account_state_write "{\"logged_in\":true,\"synced_at\":$(date +%s)}"
	/etc/init.d/"$PKG_NAME" reload >/dev/null 2>&1
	log "account: subscription synced"
	echo '{"ok":true}'
}

# Replace the account-managed share links on the first proxy group with the
# ones converted from the raw provider payload. The managed set is remembered
# in ACCOUNT_LINKS so re-syncs and logout never touch user-added links.
_account_install_links() {
	local proxy_sec links old l
	links="$(ucode "$UCODE_DIR/account-links.uc" 2>/dev/null)"
	if [ -z "$links" ]; then
		log "account: no subscription url and no parsable nodes (see $ACCOUNT_RAW)"
		echo '{"error":"no_subscription_url"}'
		return 1
	fi
	proxy_sec="$(uci -q show "$PKG_NAME" | sed -n "s/^${PKG_NAME}\.\([^.=]*\)=proxy$/\1/p" | head -n1)"
	[ -n "$proxy_sec" ] || { echo '{"error":"no_proxy_group"}'; return 1; }
	if [ -f "$ACCOUNT_LINKS" ]; then
		while IFS= read -r old; do
			[ -n "$old" ] && uci -q del_list "${PKG_NAME}.${proxy_sec}.links=${old}"
		done < "$ACCOUNT_LINKS"
	fi
	umask 077
	printf '%s\n' "$links" > "$ACCOUNT_LINKS"
	printf '%s\n' "$links" | while IFS= read -r l; do
		[ -n "$l" ] && uci -q add_list "${PKG_NAME}.${proxy_sec}.links=${l}"
	done
	uci -q commit "$PKG_NAME"
	return 0
}

# account_status -> { enabled, bot_url, logged_in, has_subscription, synced_at }
cmd_account_status() {
	local logged synced has_sub
	if ! account_enabled; then
		echo '{"enabled":false}'
		return 0
	fi
	logged="$(jsonfilter -i "$ACCOUNT_STATE" -e '@.logged_in' 2>/dev/null)"
	[ "$logged" = "true" ] || logged=false
	synced="$(jsonfilter -i "$ACCOUNT_STATE" -e '@.synced_at' 2>/dev/null)"
	[ -n "$synced" ] || synced=0
	# either a managed subscription URL or managed share links count as installed
	if [ -n "$(uci -q get "${PKG_NAME}.${ACCOUNT_SECTION}.url")" ] || [ -s "$ACCOUNT_LINKS" ]; then
		has_sub=true
	else
		has_sub=false
	fi
	printf '{"enabled":true,"bot_url":"%s","logged_in":%s,"has_subscription":%s,"synced_at":%s}\n' \
		"$(_account_bot_url)" "$logged" "$has_sub" "$synced"
}

# account_logout -> server-side logout (best effort) + local cleanup
cmd_account_logout() {
	account_enabled || { echo '{"error":"account feature disabled"}'; return 1; }
	[ -f "$ACCOUNT_JAR" ] && \
		_account_curl -o /dev/null -X POST --data '{}' "${ACCOUNT_API}/api/v2/auth/logout"
	local proxy_sec old changed=0
	if [ -f "$ACCOUNT_LINKS" ]; then
		proxy_sec="$(uci -q show "$PKG_NAME" | sed -n "s/^${PKG_NAME}\.\([^.=]*\)=proxy$/\1/p" | head -n1)"
		if [ -n "$proxy_sec" ]; then
			while IFS= read -r old; do
				[ -n "$old" ] && uci -q del_list "${PKG_NAME}.${proxy_sec}.links=${old}"
			done < "$ACCOUNT_LINKS"
			changed=1
		fi
	fi
	rm -f "$ACCOUNT_JAR" "$ACCOUNT_STATE" "$ACCOUNT_RAW" "$ACCOUNT_LINKS"
	if [ -n "$(uci -q get "${PKG_NAME}.${ACCOUNT_SECTION}")" ]; then
		[ -n "$proxy_sec" ] || \
			proxy_sec="$(uci -q show "$PKG_NAME" | sed -n "s/^${PKG_NAME}\.\([^.=]*\)=proxy$/\1/p" | head -n1)"
		[ -n "$proxy_sec" ] && \
			uci -q del_list "${PKG_NAME}.${proxy_sec}.subscriptions=${ACCOUNT_SECTION}"
		uci -q delete "${PKG_NAME}.${ACCOUNT_SECTION}"
		changed=1
	fi
	if [ "$changed" = "1" ]; then
		uci -q commit "$PKG_NAME"
		/etc/init.d/"$PKG_NAME" reload >/dev/null 2>&1
	fi
	log "account: logged out"
	echo '{"ok":true}'
}
