'use strict';
'require view';
'require form';
'require uci';
'require poll';
'require tools.__PKG_NAME__ as api';
'require view.__PKG_NAME__.main as main';

/* Static fallback if the rpcd luci.__PKG_NAME__ lists() catalog is unavailable. */
const FALLBACK_LISTS = [
	{ tag: 'russia_inside',  label: 'Russia (inside)' },
	{ tag: 'russia_outside', label: 'Russia (outside)' },
	{ tag: 'youtube',        label: 'YouTube' },
	{ tag: 'telegram',       label: 'Telegram' },
	{ tag: 'discord',        label: 'Discord' },
	{ tag: 'meta',           label: 'Meta' },
	{ tag: 'twitter',        label: 'Twitter / X' }
];

function setStatus(running) {
	const el = document.getElementById('svc_status');
	if (!el)
		return;
	el.style.color = running ? '#2e7d32' : '#c0392b';
	el.textContent = running ? _('Running') : _('Stopped');
}

function control(action) {
	return api[action]().then(function () {
		return L.resolveDefault(api.status(), false).then(setStatus);
	});
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('__PKG_NAME__'),
			L.resolveDefault(api.status(), false),
			L.resolveDefault(api.lists(), null)
		]);
	},

	render: function (data) {
		const running = data[1];
		const catalog = (data[2] && Array.isArray(data[2].lists) && data[2].lists.length)
			? data[2].lists
			: FALLBACK_LISTS;

		let m, s, o;

		m = new form.Map('__PKG_NAME__', '__BRAND_NAME__',
			_('Selective transparent proxy. Paste a proxy link and choose which lists route through it; everything else is routed directly by the kernel.'));

		/* ---------------- Service status + control ---------------- */
		s = m.section(form.TypedSection, '__PKG_NAME__', _('Service'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('Enable at boot'),
			_('Start %s automatically and route selected traffic through the proxy.').format('__BRAND_NAME__'));
		o.rmempty = false;

		o = s.option(form.DummyValue, '_status', _('Status'));
		o.rawhtml = true;
		o.cfgvalue = function () {
			return '<span id="svc_status" style="font-weight:bold;color:' +
				(running ? '#2e7d32' : '#c0392b') + '">' +
				(running ? _('Running') : _('Stopped')) + '</span>';
		};

		o = s.option(form.Button, '_start', _('Start'));
		o.inputstyle = 'positive';
		o.inputtitle = _('Start');
		o.onclick = function () { return control('start'); };

		o = s.option(form.Button, '_stop', _('Stop'));
		o.inputstyle = 'negative';
		o.inputtitle = _('Stop');
		o.onclick = function () { return control('stop'); };

		o = s.option(form.Button, '_restart', _('Restart'));
		o.inputstyle = 'action';
		o.inputtitle = _('Restart');
		o.onclick = function () { return control('restart'); };

		/* Live status refresh (no streaming needed). */
		poll.add(function () {
			return L.resolveDefault(api.status(), false).then(setStatus);
		});

		/* ---------------- Proxy (outbound group) ---------------- */
		s = m.section(form.TypedSection, 'proxy', _('Proxy'),
			_('A proxy group. Its members can be a single link, several links, subscriptions, and/or raw outbound JSON — combine as needed.'));
		s.anonymous = false;
		s.addremove = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'type', _('Group type'));
		o.value('select', _('Select (manual pick)'));
		o.value('url-test', _('URL test (auto fastest)'));
		o.value('fallback', _('Fallback (first alive)'));
		o.default = 'select';

		o = s.option(form.MultiValue, 'subscriptions', _('Subscriptions'),
			_('Proxy-providers this group draws nodes from. Manage them on the Subscriptions page.'));
		o.display_size = 8;
		uci.sections('__PKG_NAME__', 'subscription').forEach(function (sub) {
			o.value(sub['.name'], sub['.name']);
		});
		o.load = function (section_id) {
			return uci.get('__PKG_NAME__', section_id, 'subscriptions') || [];
		};
		o.write = function (section_id, value) {
			uci.set('__PKG_NAME__', section_id, 'subscriptions', L.toArray(value));
		};
		o.remove = function (section_id) {
			uci.unset('__PKG_NAME__', section_id, 'subscriptions');
		};

		o = s.option(form.TextValue, 'proxy_string', _('Proxy link'),
			_('A single vless:// ss:// trojan:// hysteria2:// (hy2://) or socks:// link.'));
		o.rows = 3;
		o.wrap = 'off';
		o.optional = true;
		o.validate = function (section_id, value) {
			if (!value)
				return true;
			const res = main.validateProxyUrl(value);
			if (res && res.valid)
				return true;
			return (res && res.error) ? res.error : _('Invalid proxy link');
		};

		o = s.option(form.DynamicList, 'links', _('Proxy links'),
			_('One connection link per entry.'));
		o.optional = true;
		o.validate = function (section_id, value) {
			if (!value)
				return true;
			const res = main.validateProxyUrl(value);
			if (res && res.valid)
				return true;
			return (res && res.error) ? res.error : _('Invalid proxy link');
		};

		o = s.option(form.Flag, 'include_direct', _('Include DIRECT'),
			_('Add a DIRECT entry to the group (useful as a manual bypass option).'));
		o.optional = true;

		o = s.option(form.TextValue, 'outbound_json', _('Outbound JSON'),
			_('Raw mihomo outbound object (advanced).'));
		o.rows = 6;
		o.wrap = 'off';
		o.optional = true;

		o = s.option(form.Value, 'test_url', _('Test URL'),
			_('Health-check URL for url-test / fallback groups.'));
		o.placeholder = 'https://www.gstatic.com/generate_204';
		o.depends('type', 'url-test');
		o.depends('type', 'fallback');
		o.optional = true;

		/* ---------------- Route (which lists via which proxy) ---------------- */
		s = m.section(form.TypedSection, 'route', _('Routing'),
			_('One routing bucket: pick the community lists (and any custom domains/subnets) that should travel through a proxy.'));
		s.anonymous = false;
		s.addremove = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'proxy', _('Proxy'),
			_('Which proxy group this bucket routes through.'));
		const proxies = uci.sections('__PKG_NAME__', 'proxy');
		if (proxies.length) {
			proxies.forEach(function (px) {
				o.value(px['.name'], px['.name']);
			});
		} else {
			o.value('main', 'main');
		}

		o = s.option(form.MultiValue, 'community_lists', _('Community lists'),
			_('Domains and subnets in the selected lists are routed through the proxy.'));
		o.display_size = 12;
		catalog.forEach(function (item) {
			o.value(item.tag, item.label || item.tag);
		});
		/* community_lists is a UCI list — read/write it as an array. */
		o.load = function (section_id) {
			return uci.get('__PKG_NAME__', section_id, 'community_lists') || [];
		};
		o.write = function (section_id, value) {
			uci.set('__PKG_NAME__', section_id, 'community_lists', L.toArray(value));
		};
		o.remove = function (section_id) {
			uci.unset('__PKG_NAME__', section_id, 'community_lists');
		};

		o = s.option(form.DynamicList, 'user_domains', _('Custom domains'),
			_('Extra domains to route through the proxy.'));
		o.optional = true;

		o = s.option(form.DynamicList, 'user_subnets', _('Custom subnets'),
			_('Extra CIDR subnets to route through the proxy.'));
		o.datatype = 'cidr4';
		o.optional = true;

		return m.render();
	}
});
