// /usr/share/__PKG_NAME__/ucode/lib.uc — helpers (module).
// UCI coercion helpers adapted from nikki include.uc:21-51; URL helpers are
// new and deliberately structural (split BEFORE percent-decoding each part) to
// avoid '+'->space and %26 corruption bugs.
'use strict';

function uci_bool(v) {
	return v == '1' || v == 'true';
}

function uci_int(v) {
	return v == null ? null : int(v);
}

function uci_array(v) {
	if (v == null) return [];
	if (type(v) == 'array') return v;
	return [v];
}

// Recursively drop null / '' / [] / {} so absent UCI options simply vanish
// from the emitted config (nikki trim_all).
function trim_all(x) {
	if (type(x) == 'object') {
		let out = {};
		for (let k in x) {
			let v = trim_all(x[k]);
			if (v === null) continue;
			if (type(v) == 'string' && v == '') continue;
			if (type(v) == 'array' && length(v) == 0) continue;
			if (type(v) == 'object' && length(keys(v)) == 0) continue;
			out[k] = v;
		}
		return out;
	}
	if (type(x) == 'array') {
		let out = [];
		for (let v in x) {
			let t = trim_all(v);
			if (t === null) continue;
			push(out, t);
		}
		return out;
	}
	return x;
}

function _hexval(c) {
	if (c >= '0' && c <= '9') return ord(c) - 48;
	let l = lc(c);
	if (l >= 'a' && l <= 'f') return ord(l) - 87;
	return -1;
}

// Percent-decode a single URL component. Does NOT translate '+' to space.
function percent_decode(s) {
	if (s == null) return null;
	let out = '';
	let i = 0, n = length(s);
	while (i < n) {
		let c = substr(s, i, 1);
		if (c == '%' && i + 2 < n) {
			let hi = _hexval(substr(s, i + 1, 1));
			let lo = _hexval(substr(s, i + 2, 1));
			if (hi >= 0 && lo >= 0) {
				out += chr(hi * 16 + lo);
				i += 3;
				continue;
			}
		}
		out += c;
		i++;
	}
	return out;
}

// Structural URL split. Returns { scheme, userinfo, host, port, query, fragment }.
// query is an object of decoded params; userinfo/host are returned RAW (caller
// decides whether to base64/percent decode). fragment is decoded (display name).
function url_parse(url) {
	let out = { scheme: null, userinfo: null, host: null, port: null, query: {}, fragment: null };

	let si = index(url, '://');
	if (si < 0) return out;
	out.scheme = lc(substr(url, 0, si));
	let rest = substr(url, si + 3);

	// fragment
	let hi = index(rest, '#');
	if (hi >= 0) {
		out.fragment = percent_decode(substr(rest, hi + 1));
		rest = substr(rest, 0, hi);
	}

	// query
	let qi = index(rest, '?');
	if (qi >= 0) {
		let qs = substr(rest, qi + 1);
		rest = substr(rest, 0, qi);
		for (let pair in split(qs, '&')) {
			if (pair == '') continue;
			let eq = index(pair, '=');
			if (eq < 0) { out.query[percent_decode(pair)] = ''; continue; }
			let k = percent_decode(substr(pair, 0, eq));
			let v = percent_decode(substr(pair, eq + 1));
			out.query[k] = v;
		}
	}

	// authority = [userinfo@]host[:port]
	let at = index(rest, '@');
	let authority = rest;
	if (at >= 0) {
		out.userinfo = substr(rest, 0, at);
		authority = substr(rest, at + 1);
	}

	// host[:port], IPv6 in brackets
	if (substr(authority, 0, 1) == '[') {
		let rb = index(authority, ']');
		out.host = substr(authority, 1, rb - 1);
		let tail = substr(authority, rb + 1);
		if (substr(tail, 0, 1) == ':') out.port = substr(tail, 1);
	} else {
		let ci = rindex(authority, ':');
		if (ci >= 0) {
			out.host = substr(authority, 0, ci);
			out.port = substr(authority, ci + 1);
		} else {
			out.host = authority;
		}
	}
	return out;
}

// Comma-list -> array of trimmed non-empty strings.
function csv(s) {
	let out = [];
	if (s == null || s == '') return out;
	for (let p in split(s, ',')) {
		p = trim(p);
		if (p != '') push(out, p);
	}
	return out;
}

export {
	uci_bool, uci_int, uci_array, trim_all,
	percent_decode, url_parse, csv
};
