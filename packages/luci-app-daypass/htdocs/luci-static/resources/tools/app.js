'use strict';
'require baseclass';
'require rpc';

/* Shared rpc.declare wrappers for the __BRAND_NAME__ LuCI app.
 * Installed as tools/__PKG_NAME__.js and required by the views as
 *   'require tools.__PKG_NAME__ as api'.
 * Service control goes through ubus rc.list / rc.init; everything else
 * through the luci.__PKG_NAME__ rpcd ucode plugin (secret stays server-side). */

const SERVICE = '__PKG_NAME__';

const callRCList = rpc.declare({
	object: 'rc',
	method: 'list',
	params: ['name'],
	expect: { '': {} }
});

const callRCInit = rpc.declare({
	object: 'rc',
	method: 'init',
	params: ['name', 'action'],
	expect: { '': {} }
});

const callVersion = rpc.declare({
	object: 'luci.__PKG_NAME__',
	method: 'version',
	expect: { '': {} }
});

const callLists = rpc.declare({
	object: 'luci.__PKG_NAME__',
	method: 'lists',
	expect: { '': {} }
});

const callDiag = rpc.declare({
	object: 'luci.__PKG_NAME__',
	method: 'diag',
	params: ['check'],
	expect: { output: '' }
});

const callLogs = rpc.declare({
	object: 'luci.__PKG_NAME__',
	method: 'logs',
	params: ['lines'],
	expect: { log: '' }
});

const callApi = rpc.declare({
	object: 'luci.__PKG_NAME__',
	method: 'api',
	params: ['method', 'path', 'query', 'body'],
	expect: { '': {} }
});

const callDashboardInfo = rpc.declare({
	object: 'luci.__PKG_NAME__',
	method: 'dashboard_info',
	expect: { '': {} }
});

return baseclass.extend({
	serviceName: SERVICE,

	/* ---- service control (ubus rc) ---- */
	status: function () {
		return callRCList(SERVICE).then(function (res) {
			return (res && res[SERVICE] && res[SERVICE].running) ? true : false;
		});
	},

	start: function () {
		return callRCInit(SERVICE, 'start');
	},

	stop: function () {
		return callRCInit(SERVICE, 'stop');
	},

	restart: function () {
		return callRCInit(SERVICE, 'restart');
	},

	reload: function () {
		return callRCInit(SERVICE, 'reload');
	},

	/* ---- luci.__PKG_NAME__ rpcd plugin ---- */
	version: function () {
		return callVersion();
	},

	lists: function () {
		return callLists();
	},

	diag: function (check) {
		return callDiag(check);
	},

	logs: function (lines) {
		return callLogs(lines);
	},

	api: function (method, path, query, body) {
		return callApi(method, path, query, body);
	},

	dashboardInfo: function () {
		return callDashboardInfo();
	}
});
