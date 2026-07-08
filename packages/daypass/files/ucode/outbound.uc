// /usr/share/__PKG_NAME__/ucode/outbound.uc — proxy share-link -> mihomo proxy.
// Adapted from podkop sing_box_config_facade.sh:58-270, retargeted to mihomo
// key names. Structural parse first (lib.url_parse), then per-scheme mapping.
'use strict';

import { url_parse, percent_decode, csv } from '/usr/share/__PKG_NAME__/ucode/lib.uc';

function as_port(v) {
	let n = int(v);
	return (n == null || n < 0) ? null : n;
}

// tls / reality query -> mihomo keys on the proxy object.
function apply_security(p, q) {
	let sec = q.security;
	// reality is signalled by pbk; tls by security=tls or presence of sni.
	let has_reality = (q.pbk != null && q.pbk != '');
	if (sec == 'reality' || has_reality) {
		p.tls = true;
		if (q.sni) p.servername = q.sni;
		if (q.fp) p['client-fingerprint'] = q.fp;
		let ro = {};
		if (q.pbk) ro['public-key'] = q.pbk;
		if (q.sid) ro['short-id'] = q.sid;
		p['reality-opts'] = ro;
	} else if (sec == 'tls') {
		p.tls = true;
		if (q.sni) p.servername = q.sni;
		if (q.fp) p['client-fingerprint'] = q.fp;
		if (q.alpn) p.alpn = csv(q.alpn);
		if (q.allowInsecure == '1' || q.insecure == '1') p['skip-cert-verify'] = true;
	}
	return p;
}

// ws / grpc / http transport query -> mihomo *-opts.
function apply_transport(p, q) {
	let net = q.type;
	if (net == null || net == 'tcp' || net == 'raw' || net == 'none') return p;
	if (net == 'ws') {
		p.network = 'ws';
		let o = {};
		if (q.path) o.path = q.path;
		if (q.host) o.headers = { Host: q.host };
		p['ws-opts'] = o;
	} else if (net == 'grpc') {
		p.network = 'grpc';
		if (q.serviceName) p['grpc-opts'] = { 'grpc-service-name': q.serviceName };
	} else if (net == 'http' || net == 'h2') {
		p.network = 'http';
		let o = {};
		if (q.path) o.path = [q.path];
		if (q.host) o.headers = { Host: csv(q.host) };
		p['http-opts'] = o;
	}
	return p;
}

function parse_vless(u, name) {
	let p = {
		name: name, type: 'vless', server: u.host, port: as_port(u.port),
		uuid: u.userinfo, udp: true, network: 'tcp',
	};
	if (u.query.flow) p.flow = u.query.flow;
	if (u.query.packetEncoding) p['packet-encoding'] = u.query.packetEncoding;
	apply_security(p, u.query);
	apply_transport(p, u.query);
	return p;
}

function parse_ss(u, name) {
	let ui = u.userinfo;
	// userinfo is either plain 'method:password' or base64 of it.
	if (!match(ui, /^[^:]+:[^:]+$/)) {
		let dec = b64dec(ui);
		if (dec != null) ui = dec;
	}
	let ci = index(ui, ':');
	let p = {
		name: name, type: 'ss', server: u.host, port: as_port(u.port),
		cipher: substr(ui, 0, ci), password: substr(ui, ci + 1), udp: true,
	};
	// SIP003 plugin passthrough: plugin=<name>;k=v;k2=v2
	if (u.query.plugin) {
		let parts = split(u.query.plugin, ';');
		let name0 = parts[0];
		let opts = {};
		for (let i = 1; i < length(parts); i++) {
			let kv = parts[i];
			let eq = index(kv, '=');
			if (eq < 0) { opts[kv] = true; continue; }
			opts[substr(kv, 0, eq)] = substr(kv, eq + 1);
		}
		if (name0 == 'obfs-local' || name0 == 'simple-obfs') p.plugin = 'obfs';
		else p.plugin = name0;
		if (length(keys(opts)) > 0) p['plugin-opts'] = opts;
	}
	return p;
}

function parse_trojan(u, name) {
	let p = {
		name: name, type: 'trojan', server: u.host, port: as_port(u.port),
		password: u.userinfo, udp: true,
	};
	if (u.query.sni) p.sni = u.query.sni;
	if (u.query.alpn) p.alpn = csv(u.query.alpn);
	if (u.query.allowInsecure == '1' || u.query.insecure == '1') p['skip-cert-verify'] = true;
	if (u.query.fp) p['client-fingerprint'] = u.query.fp;
	apply_transport(p, u.query);
	return p;
}

function parse_hysteria2(u, name) {
	let p = {
		name: name, type: 'hysteria2', server: u.host, password: u.userinfo,
	};
	// port hopping: range/list in authority, or mport query.
	let portspec = u.query.mport || u.port;
	if (portspec != null && (index(portspec, '-') >= 0 || index(portspec, ',') >= 0)) {
		p.ports = portspec;
	} else {
		p.port = as_port(u.port);
	}
	if (u.query.obfs) {
		p.obfs = u.query.obfs;
		if (u.query['obfs-password']) p['obfs-password'] = u.query['obfs-password'];
	}
	if (u.query.sni) p.sni = u.query.sni;
	if (u.query.alpn) p.alpn = csv(u.query.alpn);
	if (u.query.insecure == '1' || u.query.allowInsecure == '1') p['skip-cert-verify'] = true;
	if (u.query.up) p.up = u.query.up;
	if (u.query.down) p.down = u.query.down;
	return p;
}

function parse_socks(u, name) {
	let p = {
		name: name, type: 'socks5', server: u.host, port: as_port(u.port), udp: true,
	};
	if (u.userinfo != null && u.userinfo != '') {
		let ui = u.userinfo;
		if (!match(ui, /^[^:]+:.*$/)) {
			let dec = b64dec(ui);
			if (dec != null) ui = dec;
		}
		let ci = index(ui, ':');
		if (ci >= 0) {
			p.username = substr(ui, 0, ci);
			p.password = substr(ui, ci + 1);
		}
	}
	return p;
}

// parse_proxy_url(url, fallback_name) -> mihomo proxy object, or null.
function parse_proxy_url(url, fallback_name) {
	url = trim(url);
	if (url == '') return null;
	let u = url_parse(url);
	if (u.scheme == null || u.host == null) return null;

	let name = (u.fragment != null && u.fragment != '') ? u.fragment : fallback_name;

	switch (u.scheme) {
	case 'vless':                 return parse_vless(u, name);
	case 'ss':
	case 'shadowsocks':           return parse_ss(u, name);
	case 'trojan':                return parse_trojan(u, name);
	case 'hysteria2':
	case 'hy2':                   return parse_hysteria2(u, name);
	case 'socks':
	case 'socks5':                return parse_socks(u, name);
	default:                      return null;
	}
}

export { parse_proxy_url };
