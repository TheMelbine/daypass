#!/usr/bin/ucode

// luci.__PKG_NAME__ — rpcd ucode plugin for the __BRAND_NAME__ LuCI app.
// Exposes a whitelisted surface; the mihomo API secret never leaves the router.

'use strict';

import { popen, access } from 'fs';

const PKG = '__PKG_NAME__';
const API = '127.0.0.1:9090';
const CORE_LOG = '/var/log/__PKG_NAME__/core.log';

// Run a shell command and return its trimmed stdout.
function sh(cmd) {
	const proc = popen(cmd);
	if (!proc)
		return '';
	const out = proc.read('all');
	proc.close();
	return trim(out ?? '');
}

// Read a UCI value: uci_get('main.api_secret').
function uci_get(key) {
	return sh(`uci -q get ${PKG}.${key}`);
}

function parse_json(raw) {
	let val = null;
	try {
		val = json(raw);
	} catch (e) {
		val = null;
	}
	return val;
}

const methods = {
	// version() -> { app, core }
	version: {
		call: function() {
			let app = '';
			if (system('command -v opkg >/dev/null 2>&1') == 0) {
				app = sh(`opkg list-installed luci-app-${PKG} 2>/dev/null | cut -d ' ' -f 3`);
			} else if (system('command -v apk >/dev/null 2>&1') == 0) {
				app = sh(`apk list -I luci-app-${PKG} 2>/dev/null | head -n1`);
			}
			const core = sh("mihomo -v 2>/dev/null | grep -o 'v[0-9][^ ]*' | head -n1");
			return { app: app, core: core };
		}
	},

	// lists() -> community catalog JSON (from the CLI, base URL already branded)
	lists: {
		call: function() {
			const catalog = parse_json(sh(`${PKG} lists 2>/dev/null`));
			return catalog ?? {};
		}
	},

	// diag(check) -> { output } — whitelisted check runner
	diag: {
		args: { check: 'check' },
		call: function(req) {
			const check = req.args?.check ?? '';
			let cmd;
			switch (check) {
			case 'config':
				cmd = `${PKG} check 2>&1`;
				break;
			case 'dns':
				cmd = 'nslookup example.com 127.0.0.42 2>&1';
				break;
			case 'proxy':
				cmd = `curl -s --max-time 5 --oauth2-bearer '${uci_get('main.api_secret')}' 'http://${API}/version' 2>&1`;
				break;
			case 'nft':
				cmd = `nft list table inet ${PKG} 2>&1`;
				break;
			default:
				return { output: '' };
			}
			return { output: sh(cmd) };
		}
	},

	// logs(lines) -> { log } — tail of the mihomo core log
	logs: {
		args: { lines: 0 },
		call: function(req) {
			let lines = int(req.args?.lines ?? 0);
			if (!lines || lines < 1)
				lines = 200;
			if (!access(CORE_LOG, 'r'))
				return { log: '' };
			return { log: sh(`tail -n ${lines} '${CORE_LOG}' 2>/dev/null`) };
		}
	},

	// api(method, path, query, body) -> parsed JSON from the mihomo REST API
	api: {
		args: { method: 'method', path: 'path', query: 'query', body: 'body' },
		call: function(req) {
			const method = req.args?.method ?? 'GET';
			const path = req.args?.path ?? '/';
			const query = req.args?.query ?? '';
			const body = req.args?.body ?? '';
			const secret = uci_get('main.api_secret');
			const url = `http://${API}${path}`;
			const raw = sh(`curl -s --max-time 10 --request '${method}' --oauth2-bearer '${secret}' --url-query '${query}' --data '${body}' '${url}' 2>/dev/null`);
			return parse_json(raw) ?? { raw: raw };
		}
	},

	// dashboard_info() -> { https, port, ui_name, secret } for the client URL builder
	dashboard_info: {
		call: function() {
			return {
				https: false,
				port: 9090,
				ui_name: uci_get('main.dashboard') || '__DASHBOARD__',
				secret: uci_get('main.api_secret')
			};
		}
	}
};

return { 'luci.__PKG_NAME__': methods };
