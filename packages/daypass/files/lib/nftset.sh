# /usr/lib/__PKG_NAME__/nftset.sh — nft set helpers (subnet loading).
# Ported from podkop nft.sh:32-70 (chunked interval-set loader) with the
# validators inlined. Sourced by list-update.sh and the CLI.

is_ipv4() {
	echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

is_ipv4_cidr() {
	echo "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'
}

# nft_add_elements <set> <comma-separated elements>
nft_add_elements() {
	nft add element inet "$NFT_TABLE" "$1" "{ $2 }" 2>/dev/null
}

# nft_flush_set <set>
nft_flush_set() {
	nft flush set inet "$NFT_TABLE" "$1" 2>/dev/null
}

# nft_load_subnets_from_file <file> [chunk_size]
# Reads one CIDR/IP per line, validates, and adds to the subnets4 set in chunks
# so we don't exceed nft command-line limits on huge lists.
nft_load_subnets_from_file() {
	local file="$1"
	local chunk_size="${2:-5000}"
	local array="" count=0 line

	[ -f "$file" ] || return 0

	while IFS= read -r line; do
		line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
		[ -z "$line" ] && continue
		case "$line" in \#*) continue ;; esac

		if ! is_ipv4 "$line" && ! is_ipv4_cidr "$line"; then
			continue
		fi

		if [ -z "$array" ]; then
			array="$line"
		else
			array="$array,$line"
		fi
		count=$((count + 1))

		if [ "$count" = "$chunk_size" ]; then
			nft_add_elements "$NFT_SUBNET_SET" "$array"
			array=""
			count=0
		fi
	done < "$file"

	[ -n "$array" ] && nft_add_elements "$NFT_SUBNET_SET" "$array"
	return 0
}
