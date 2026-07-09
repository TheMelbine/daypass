// /usr/share/__PKG_NAME__/ucode/generate.uc — UCI -> mihomo config (JSON==YAML).
// Raw ucode script (NOT a template). Run as: ucode -S generate.uc > config.yaml
// JSON is a strict subset of YAML, so the printed object is a valid config.
'use strict';

import { cursor } from 'uci';
import * as C from '/usr/share/__PKG_NAME__/ucode/constants.uc';
import { uci_bool, uci_array, csv, trim_all } from '/usr/share/__PKG_NAME__/ucode/lib.uc';
import { parse_proxy_url } from '/usr/share/__PKG_NAME__/ucode/outbound.uc';

const uci = cursor();
uci.load(C.PKG_NAME);

function get(section, option, dflt) {
	let v = uci.get(C.PKG_NAME, section, option);
	return (v == null) ? dflt : v;
}

const log_level = get('main', 'log_level', 'warning');
const api_secret = get('main', 'api_secret', '');
const dashboard = get('main', 'dashboard', '__DASHBOARD__');

const dns_type = get('settings', 'dns_type', 'doh');
const dns_server = get('settings', 'dns_server', 'https://1.1.1.1/dns-query');
const bootstrap = get('settings', 'bootstrap_dns_server', '1.1.1.1');
const disable_quic = uci_bool(get('settings', 'disable_quic', '0'));
// selective: nft marks only fake-ip + subnet sets, so everything mihomo sees is
// meant for the proxy (MATCH -> proxy). full: nft tproxies ALL lan traffic, so
// mihomo's whole rule set (incl. ipcidr on real dst) applies (MATCH -> direct).
const routing_mode = get('settings', 'routing_mode', 'selective');

let proxies = [];        // inline proxy objects
let groups = [];         // proxy-groups
let proxy_providers = {}; // subscriptions
let rule_providers = {}; // rule-sets
let fakeip_filter = [];  // domains that DO get a fake-ip (whitelist)
let rules = [];          // final rule list, in order
let default_group = null;

// -------------------- subscriptions -> proxy-providers --------------------
uci.foreach(C.PKG_NAME, 'subscription', (s) => {
	if (!uci_bool(s.enabled)) return;
	let n = s['.name'];
	proxy_providers[n] = {
		type: 'http',
		url: s.url,
		interval: int(s.interval || '3600'),
		path: C.PROVIDERS_REL + '/proxy/' + n + '.yaml',
		header: { 'User-Agent': [ s.user_agent || 'clash.meta' ] },
		'health-check': {
			enable: true,
			url: s.health_check_url || 'https://www.gstatic.com/generate_204',
			interval: int(s.health_check_interval || '300'),
		},
	};
});

// -------------------- proxies + proxy-groups --------------------
function add_proxy(p) {
	if (p == null) return null;
	if (p.name == null || p.name == '') p.name = p.server;
	push(proxies, p);
	return p.name;
}

uci.foreach(C.PKG_NAME, 'proxy', (s) => {
	if (!uci_bool(s.enabled)) return;
	let id = s['.name'];
	let members = [];

	// inline single URL
	if (s.proxy_string) {
		let nm = add_proxy(parse_proxy_url(s.proxy_string, id));
		if (nm) push(members, nm);
	}
	// inline multiple URLs
	let i = 0;
	for (let link in uci_array(s.links)) {
		let nm = add_proxy(parse_proxy_url(link, id + '-' + (++i)));
		if (nm) push(members, nm);
	}
	// raw mihomo proxy object
	if (s.outbound_json) {
		let obj = json(s.outbound_json);
		if (type(obj) == 'object') {
			if (obj.name == null) obj.name = id + '-raw';
			push(proxies, obj);
			push(members, obj.name);
		}
	}
	if (uci_bool(s.include_direct)) push(members, 'DIRECT');

	// subscriptions this group draws from
	let uses = uci_array(s.subscriptions);

	if (length(members) == 0 && length(uses) == 0) return;

	let t = s.type || 'select';
	let g = { name: id };
	if (t == 'urltest' || t == 'url-test') {
		g.type = 'url-test';
		g.url = s.test_url || 'https://www.gstatic.com/generate_204';
		g.interval = int(s.test_interval || '300');
		g.tolerance = int(s.tolerance || '50');
	} else if (t == 'fallback') {
		g.type = 'fallback';
		g.url = s.test_url || 'https://www.gstatic.com/generate_204';
		g.interval = int(s.test_interval || '300');
	} else {
		g.type = 'select';
	}
	if (length(members) > 0) g.proxies = members;
	if (length(uses) > 0) g.use = uses;
	push(groups, g);

	if (default_group == null) default_group = id;
});

// -------------------- custom rule-providers (rulesets) --------------------
function ruleset_ext(fmt) {
	if (fmt == 'yaml') return 'yaml';
	if (fmt == 'text') return 'txt';
	return 'mrs';
}

uci.foreach(C.PKG_NAME, 'ruleset', (s) => {
	if (!uci_bool(s.enabled)) return;
	let n = s['.name'];
	let beh = s.behavior || 'domain';
	let fmt = s.format || 'mrs';
	let act = s.action || 'PROXY';

	if (s.file) {
		// local file provider (e.g. a list managed by another tool on the box)
		rule_providers[n] = { type: 'file', behavior: beh, format: fmt, path: s.file };
	} else {
		rule_providers[n] = {
			type: 'http', behavior: beh, format: fmt,
			url: s.url,
			path: C.PROVIDERS_REL + '/rule/' + n + '.' + ruleset_ext(fmt),
			interval: int(s.interval || '86400'),
			// fetch directly — the proxy group isn't ready at startup, so pulling
			// through it would fail and leave the rule-set empty.
			proxy: 'DIRECT',
		};
	}

	let rule = 'RULE-SET,' + n + ',' + act;
	if (beh == 'ipcidr' && uci_bool(s.no_resolve)) rule += ',no-resolve';
	push(rules, rule);

	// A domain must get a fake-ip to be handled by mihomo (proxied OR rejected).
	// DIRECT domains must NOT be fake-ip'd, so they resolve real and bypass mihomo.
	if (beh == 'domain' && act != 'DIRECT') push(fakeip_filter, 'rule-set:' + n);
});

// -------------------- community lists + routes --------------------
function provider_for_tag(tag) {
	if (rule_providers[tag]) return;
	rule_providers[tag] = {
		type: 'http', behavior: 'domain', format: 'mrs',
		url: C.LISTS_BASE + '/' + tag + '_domain.mrs',
		path: C.PROVIDERS_REL + '/rule/' + tag + '.mrs',
		interval: 86400, proxy: 'DIRECT',
	};
	push(fakeip_filter, 'rule-set:' + tag);
}

function provider_for_remote(name, url) {
	rule_providers[name] = {
		type: 'http', behavior: 'domain', format: 'mrs',
		url: url, path: C.PROVIDERS_REL + '/rule/' + name + '.mrs',
		interval: 86400, proxy: 'DIRECT',
	};
	push(fakeip_filter, 'rule-set:' + name);
}

uci.foreach(C.PKG_NAME, 'route', (s) => {
	if (!uci_bool(s.enabled)) return;
	let grp = s.proxy;
	if (grp == null || grp == '') return;
	if (default_group == null) default_group = grp;

	for (let tag in uci_array(s.community_lists)) {
		provider_for_tag(tag);
		push(rules, 'RULE-SET,' + tag + ',' + grp);
	}
	let rn = 0;
	for (let url in uci_array(s.remote_domain_mrs)) {
		let nm = 'rd_' + s['.name'] + '_' + (++rn);
		provider_for_remote(nm, url);
		push(rules, 'RULE-SET,' + nm + ',' + grp);
	}
	for (let dom in uci_array(s.user_domains)) {
		push(fakeip_filter, '+.' + dom);
		push(rules, 'DOMAIN-SUFFIX,' + dom + ',' + grp);
	}
});

// -------------------- inline custom rules --------------------
// settings.prepend_rules run BEFORE everything (highest priority: QUIC blocks,
// DIRECT exceptions, private-IP bypasses). settings.append_rules run after the
// generated rules but before the final MATCH.
let prepend = uci_array(uci.get(C.PKG_NAME, 'settings', 'prepend_rules'));
let append = uci_array(uci.get(C.PKG_NAME, 'settings', 'append_rules'));
if (length(prepend) > 0) rules = [ ...prepend, ...rules ];
for (let r in append) push(rules, r);

// catch-all: full mode routes the unmatched majority DIRECT; selective mode sends
// the (already pre-filtered) remainder to the proxy. Overridable via match_action.
let match_default = (routing_mode == 'full') ? 'DIRECT' : (default_group != null ? default_group : 'DIRECT');
push(rules, 'MATCH,' + get('settings', 'match_action', match_default));

// -------------------- DNS --------------------
// Prefer plain-IP nameserver lists (reliable, no per-query TLS) over a single
// DoH URL, which handshake-times-out under load at startup. Lists override the
// single dns_server / bootstrap_dns_server for users who want several resolvers.
let nameservers = uci_array(uci.get(C.PKG_NAME, 'settings', 'nameservers'));
if (length(nameservers) == 0) nameservers = [ dns_server ];
let proxy_ns = uci_array(uci.get(C.PKG_NAME, 'settings', 'proxy_server_nameservers'));
if (length(proxy_ns) == 0) proxy_ns = [ bootstrap ];
let default_ns = uci_array(uci.get(C.PKG_NAME, 'settings', 'default_nameservers'));
if (length(default_ns) == 0) default_ns = [ bootstrap ];

let dns = {
	enable: true,
	listen: C.DNS_ADDR + ':' + C.DNS_PORT,
	ipv6: false,
	'enhanced-mode': 'fake-ip',
	'fake-ip-range': C.FAKEIP_CIDR,
	'fake-ip-filter-mode': 'whitelist',
	'fake-ip-filter': fakeip_filter,
	'fake-ip-ttl': 1,
	'default-nameserver': default_ns,
	nameserver: nameservers,
	'proxy-server-nameserver': proxy_ns,
};

// -------------------- sniffer --------------------
let sniff = {
	HTTP: { ports: [ 80, '8080-8880' ] },
	TLS:  { ports: [ 443, 8443 ] },
};
if (!disable_quic) sniff.QUIC = { ports: [ 443, 8443 ] };
let sniffer = {
	enable: true, 'force-dns-mapping': true, 'parse-pure-ip': true,
	'override-destination': false, sniff: sniff, 'skip-domain': [ '+.lan' ],
};

// -------------------- assemble --------------------
let config = {
	mode: 'rule',
	ipv6: false,
	'log-level': log_level,
	'find-process-mode': 'off',
	'unified-delay': true,
	'tcp-concurrent': true,
	'routing-mark': C.ROUTING_MARK,
	listeners: [
		{ name: 'tproxy-in', type: 'tproxy', port: C.TPROXY_PORT, listen: '0.0.0.0', udp: true },
	],
	tun: { enable: false },
	'external-controller': C.API_ADDR + ':' + C.API_PORT,
	secret: api_secret,
	'external-ui': C.UI_DIR + '/' + dashboard,
	profile: { 'store-selected': true, 'store-fake-ip': true },
	dns: dns,
	sniffer: sniffer,
	proxies: proxies,
	'proxy-providers': proxy_providers,
	'proxy-groups': groups,
	'rule-providers': rule_providers,
	rules: rules,
};

print(trim_all(config));
