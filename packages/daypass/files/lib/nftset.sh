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

# nft_load_subnets_from_file <file>
# Reads one IPv4/CIDR per line and loads it into the subnets4 set. A single awk
# pass validates (IPv4 only — IPv6/junk/comments skipped) and emits an `nft -f`
# script of batched `add element` statements, applied in ONE transaction.
#
# Why not a shell loop: the set is `interval`+`auto-merge`, so a per-chunk
# `nft add` re-merges the whole growing set, and a per-line `echo|sed`+`grep`
# loop spawns ~3 subprocesses per line — both unusably slow for the ~29k CIDRs a
# decompiled ipcidr rule-set produces (minutes, pinned CPU). awk + one `nft -f`
# does it in a second. Strict validation matters here: `nft -f` is atomic, so a
# single bad element would fail the entire load — we filter to valid IPv4 only.
nft_load_subnets_from_file() {
	local file="$1"
	[ -f "$file" ] || return 0
	local nftf="/tmp/${PKG_NAME}_nftload.$$"

	awk -v tbl="$NFT_TABLE" -v set="$NFT_SUBNET_SET" '
		function ok(s,   a, i, n, o) {
			if (s !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/) return 0
			n = split(s, a, /[.\/]/)
			for (i = 1; i <= 4; i++) { o = a[i] + 0; if (o > 255) return 0 }
			if (n == 5 && a[5] + 0 > 32) return 0
			return 1
		}
		{
			sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); sub(/#.*/, "")
			if ($0 == "" || !ok($0)) next
			if (k == 0) printf "add element inet %s %s { ", tbl, set
			else printf ", "
			printf "%s", $0
			if (++k >= 2000) { printf " }\n"; k = 0 }
		}
		END { if (k) printf " }\n" }
	' "$file" > "$nftf"

	[ -s "$nftf" ] && nft -f "$nftf"
	rm -f "$nftf"
}
