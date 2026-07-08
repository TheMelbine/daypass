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

// ---- proxies + proxy-groups (one group per enabled 'proxy' section) ----
let proxies = [];
let groups = [];

function add_proxy(p) {
	if (p == null) return null;
	// ensure a name
	if (p.name == null || p.name == '') p.name = p.server;
	push(proxies, p);
	return p.name;
}

uci.foreach(C.PKG_NAME, 'proxy', (s) => {
	if (!uci_bool(s.enabled)) return;
	let id = s['.name'];
	let members = [];

	let t = s.type || 'url';
	if (t == 'raw' && s.outbound_json) {
		let obj = json(s.outbound_json);
		if (type(obj) == 'object') {
			if (obj.name == null) obj.name = id + '-raw';
			push(proxies, obj);
			push(members, obj.name);
		}
	} else if (t == 'url') {
		let nm = add_proxy(parse_proxy_url(s.proxy_string || '', id));
		if (nm) push(members, nm);
	} else { // selector | urltest
		let i = 0;
		for (let link in uci_array(s.links)) {
			let nm = add_proxy(parse_proxy_url(link, id + '-' + (++i)));
			if (nm) push(members, nm);
		}
	}

	if (length(members) == 0) return;

	let g = { name: id, proxies: members };
	if (t == 'urltest') {
		g.type = 'url-test';
		g.url = s.test_url || 'https://www.gstatic.com/generate_204';
		g.interval = int(s.test_interval || '300');
		g.tolerance = int(s.tolerance || '50');
	} else {
		g.type = 'select';
	}
	push(groups, g);
});

// ---- routes -> rule-providers, fake-ip-filter, rules ----
let providers = {};
let fakeip_filter = [];
let rules = [];
let default_group = null;

function provider_for_tag(tag) {
	if (providers[tag]) return;
	providers[tag] = {
		type: 'http', behavior: 'domain', format: 'mrs',
		url: C.LISTS_BASE + '/' + tag + '_domain.mrs',
		path: C.PROVIDERS_REL + '/rule/' + tag + '.mrs',
		interval: 86400, proxy: 'DIRECT',
	};
	push(fakeip_filter, 'rule-set:' + tag);
}

function provider_for_remote(name, url) {
	providers[name] = {
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

// catch-all: anything else that reached the tproxy listener (e.g. subnet flows)
push(rules, 'MATCH,' + (default_group != null ? default_group : 'DIRECT'));

// ---- DNS ----
let nameserver = [ dns_server ];
let dns = {
	enable: true,
	listen: C.DNS_ADDR + ':' + C.DNS_PORT,
	ipv6: false,
	'enhanced-mode': 'fake-ip',
	'fake-ip-range': C.FAKEIP_CIDR,
	'fake-ip-filter-mode': 'whitelist',
	'fake-ip-filter': fakeip_filter,
	'fake-ip-ttl': 1,
	'default-nameserver': [ bootstrap ],
	nameserver: nameserver,
	'proxy-server-nameserver': [ bootstrap ],
};

// ---- sniffer ----
let sniff = {
	HTTP: { ports: [ 80, '8080-8880' ] },
	TLS:  { ports: [ 443, 8443 ] },
};
if (!disable_quic) sniff.QUIC = { ports: [ 443, 8443 ] };
let sniffer = {
	enable: true, 'force-dns-mapping': true, 'parse-pure-ip': true,
	'override-destination': false, sniff: sniff, 'skip-domain': [ '+.lan' ],
};

// ---- assemble ----
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
	'proxy-groups': groups,
	'rule-providers': providers,
	rules: rules,
};

print(trim_all(config));
