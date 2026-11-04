#!/usr/bin/ucode
// /usr/share/__PKG_NAME__/ucode/account-links.uc — provider account payload ->
// share links. Some provider platforms return raw xray configs (one per node)
// instead of a subscription URL; this converts each entry's vless outbound into
// a vless:// link that outbound.uc already knows how to parse. One link per line.
'use strict';

import { readfile } from 'fs';

const HOME = '/etc/__PKG_NAME__';

let raw = null;
try {
	raw = json(readfile(`${HOME}/account-config.json`) ?? 'null');
} catch (e) {
	raw = null;
}

let cfgs = raw?.config;
if (type(cfgs) == 'object') cfgs = [ cfgs ];
if (type(cfgs) != 'array') exit(0);

let n = 0;
for (let cfg in cfgs) {
	let ob = null;
	for (let o in (cfg.outbounds ?? [])) {
		if (o.protocol == 'vless') { ob = o; break; }
	}
	if (!ob) continue;
	const v = ob.settings?.vnext?.[0];
	if (!v?.address || !v?.port) continue;
	const u = v.users?.[0] ?? {};
	if (!u.id) continue;
	const ss = ob.streamSettings ?? {};
	const rs = ss.realitySettings ?? {};
	const ts = ss.tlsSettings ?? {};

	let q = [ `encryption=${u.encryption ?? 'none'}`, `type=${ss.network ?? 'tcp'}` ];
	if (ss.security == 'reality') {
		push(q, 'security=reality');
		if (rs.serverName)  push(q, `sni=${rs.serverName}`);
		if (rs.publicKey)   push(q, `pbk=${rs.publicKey}`);
		if (rs.shortId)     push(q, `sid=${rs.shortId}`);
		if (rs.fingerprint) push(q, `fp=${rs.fingerprint}`);
	} else if (ss.security == 'tls') {
		push(q, 'security=tls');
		if (ts.serverName) push(q, `sni=${ts.serverName}`);
	}
	if (u.flow) push(q, `flow=${u.flow}`);

	n++;
	// fragment must stay URL-safe: ASCII subset of remarks, else a numbered name
	let name = replace(cfg.remarks ?? '', /[^A-Za-z0-9_.-]/g, '');
	if (name == '') name = `node-${n}`;
	print(`vless://${u.id}@${v.address}:${v.port}?${join('&', q)}#${name}\n`);
}
