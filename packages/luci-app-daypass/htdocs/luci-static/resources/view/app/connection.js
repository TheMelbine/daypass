'use strict';
'require view';
'require form';
'require uci';
'require poll';
'require ui';
'require tools.__PKG_NAME__ as api';
'require view.__PKG_NAME__.main as main';

/* Groups the user can pick a node in (manual Selector). Auto groups are shown
 * read-only. GLOBAL is mihomo's own noise. */
const SELECTABLE = { 'Selector': true, 'URLTest': true, 'Fallback': true, 'LoadBalance': true };
const HIDE = { 'GLOBAL': true };
const TEST_URL = 'http://www.gstatic.com/generate_204';

/* ---------------- node picker (live, mihomo API) ---------------- */

function fmtDelay(d) {
	if (d == null) return _('n/a');
	if (d <= 0) return _('timeout');
	return d + ' ms';
}

function applyDelays(sel, cell, map) {
	Array.from(sel.options).forEach(function (opt) {
		const name = opt.getAttribute('data-name') || opt.value;
		opt.setAttribute('data-name', name);
		const d = map ? map[name] : null;
		opt.textContent = name + '  ·  ' + fmtDelay(d);
	});
	cell.textContent = fmtDelay(map ? map[sel.value] : null);
}

function testGroup(group, sel, cell, btn) {
	btn.disabled = true;
	cell.textContent = '…';
	return api.api('GET', '/group/' + encodeURIComponent(group) + '/delay',
			'url=' + encodeURIComponent(TEST_URL) + '&timeout=5000', '')
		.then(function (res) { applyDelays(sel, cell, (res && typeof res === 'object') ? res : {}); })
		.catch(function () { cell.textContent = _('test failed'); })
		.finally(function () { btn.disabled = false; });
}

function switchNode(group, name, sel) {
	sel.disabled = true;
	return api.api('PUT', '/proxies/' + encodeURIComponent(group), '', JSON.stringify({ name: name }))
		.then(function () { ui.addNotification(null, E('p', _('%s → %s').format(group, name)), 'info'); })
		.catch(function () { ui.addNotification(null, E('p', _('Failed to switch %s').format(group)), 'danger'); })
		.finally(function () { sel.disabled = false; });
}

function groupRow(group, info) {
	const nodes = info.all || [];
	const isSelector = (info.type === 'Selector');

	const sel = E('select', {
		'class': 'cbi-input-select',
		'style': 'min-width:18em;max-width:100%',
		'disabled': isSelector ? null : 'disabled'
	}, nodes.map(function (n) {
		return E('option', { 'value': n, 'data-name': n, 'selected': (n === info.now) ? 'selected' : null }, [ n ]);
	}));

	const cell = E('td', { 'class': 'td left', 'style': 'white-space:nowrap;color:#888' }, '—');
	if (isSelector)
		sel.addEventListener('change', function () { switchNode(group, this.value, this); });

	const btn = E('button', { 'class': 'cbi-button cbi-button-action' }, _('Test'));
	btn.addEventListener('click', function () { testGroup(group, sel, cell, btn); });

	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'style': 'font-weight:bold' }, [ group ]),
		E('td', { 'class': 'td left' }, [ sel ]),
		cell,
		E('td', { 'class': 'td left' }, [ btn ])
	]);
}

function nodePicker(proxiesData) {
	const proxies = (proxiesData && proxiesData.proxies) || {};
	const names = Object.keys(proxies).filter(function (k) {
		return !HIDE[k] && SELECTABLE[proxies[k].type] && (proxies[k].all || []).length;
	});

	if (!names.length)
		return E('p', { 'class': 'cbi-value-description' },
			_('Add a subscription below, then Save & Apply — your nodes appear here.'));

	const tbl = E('table', { 'class': 'table cbi-section-table' }, [
		E('tr', { 'class': 'tr table-titles' }, [
			E('th', { 'class': 'th' }, _('Group')),
			E('th', { 'class': 'th' }, _('Node')),
			E('th', { 'class': 'th' }, _('Latency')),
			E('th', { 'class': 'th' }, '')
		])
	]);
	names.forEach(function (g) { tbl.appendChild(groupRow(g, proxies[g])); });

	const testAll = E('button', { 'class': 'cbi-button cbi-button-neutral', 'style': 'margin-top:.5em' }, _('Test all'));
	testAll.addEventListener('click', function () {
		tbl.querySelectorAll('tr.tr button.cbi-button-action').forEach(function (b) { b.click(); });
	});
	return E('div', {}, [ tbl, testAll ]);
}

/* ---------------- status + control (live) ---------------- */

function setStatus(running) {
	const el = document.getElementById('svc_status');
	if (!el) return;
	el.style.color = running ? '#2e7d32' : '#c0392b';
	el.textContent = running ? _('Running') : _('Stopped');
}

function control(action) {
	return api[action]().then(function () {
		return L.resolveDefault(api.status(), false).then(setStatus);
	});
}

function statusBlock(running, enabledBoot) {
	function btn(style, label, action) {
		const b = E('button', { 'class': 'cbi-button cbi-button-' + style, 'style': 'margin-right:.4em' }, label);
		b.addEventListener('click', function () { control(action); });
		return b;
	}
	const chk = E('input', { 'type': 'checkbox', 'style': 'margin:0 .35em 0 0' });
	chk.checked = enabledBoot;
	/* just marks the uci change dirty; the form's Save & Apply flushes it */
	chk.addEventListener('change', function () {
		uci.set('__PKG_NAME__', 'main', 'enabled', this.checked ? '1' : '0');
	});
	return E('div', { 'style': 'display:flex;align-items:center;gap:1.5em;flex-wrap:wrap;margin-bottom:1em' }, [
		E('span', {}, [
			_('Status') + ': ',
			E('span', { 'id': 'svc_status', 'style': 'font-weight:bold;color:' + (running ? '#2e7d32' : '#c0392b') },
				running ? _('Running') : _('Stopped'))
		]),
		E('span', {}, [
			btn('positive', _('Start'), 'start'),
			btn('negative', _('Stop'), 'stop'),
			btn('action', _('Restart'), 'restart')
		]),
		E('label', { 'style': 'display:inline-flex;align-items:center;cursor:pointer' }, [ chk, _('Enable at boot') ])
	]);
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('__PKG_NAME__'),
			L.resolveDefault(api.status(), false),
			L.resolveDefault(api.api('GET', '/proxies'), null)
		]);
	},

	render: function (data) {
		const running = data[1];
		const proxiesData = data[2];

		let m, s, o;

		m = new form.Map('__PKG_NAME__', '__BRAND_NAME__');

		/* subscriptions (add a URL — that's the whole setup) */
		s = m.section(form.GridSection, 'subscription', _('Subscriptions'),
			_('Paste a subscription (proxy-provider) link. Its nodes show up in the picker above.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.modaltitle = _('Subscription');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o.editable = true;

		o = s.option(form.Value, 'url', _('Subscription URL'),
			_('Clash/mihomo subscription (proxy-provider) link.'));
		o.rmempty = false;
		o.validate = function (section_id, value) {
			if (value && !/^https?:\/\//.test(value)) return _('Must be an http(s) URL');
			return true;
		};
		o = s.option(form.Value, 'user_agent', _('User-Agent'),
			_('Some providers gate content on the client User-Agent.'));
		o.placeholder = 'clash.meta';
		o.modalonly = true;
		o = s.option(form.Value, 'interval', _('Update interval (s)'),
			_('How often mihomo refreshes the subscription.'));
		o.datatype = 'uinteger';
		o.placeholder = '3600';
		o.modalonly = true;
		o = s.option(form.Value, 'health_check_url', _('Health-check URL'));
		o.placeholder = 'https://www.gstatic.com/generate_204';
		o.modalonly = true;
		o = s.option(form.Value, 'health_check_interval', _('Health-check interval (s)'));
		o.datatype = 'uinteger';
		o.placeholder = '300';
		o.modalonly = true;

		/* connection method (the single proxy group) — a group with no explicit
		 * members draws from every subscription automatically. */
		const pg = uci.sections('__PKG_NAME__', 'proxy')[0];
		const pgName = pg ? pg['.name'] : 'PROXY';
		s = m.section(form.NamedSection, pgName, 'proxy', _('Connection method'),
			_('A single link is optional — with subscriptions above you can leave it empty.'));
		s.addremove = false;

		o = s.option(form.ListValue, 'type', _('Group type'));
		o.value('select', _('Select (manual pick)'));
		o.value('url-test', _('URL test (auto fastest)'));
		o.value('fallback', _('Fallback (first alive)'));
		o.default = 'select';

		o = s.option(form.TextValue, 'proxy_string', _('Proxy link'),
			_('A single vless:// ss:// trojan:// hysteria2:// (hy2://) or socks:// link.'));
		o.rows = 2;
		o.wrap = 'off';
		o.optional = true;
		o.validate = function (section_id, value) {
			if (!value) return true;
			const res = main.validateProxyUrl(value);
			if (res && res.valid) return true;
			return (res && res.error) ? res.error : _('Invalid proxy link');
		};

		poll.add(function () {
			return L.resolveDefault(api.status(), false).then(setStatus);
		});

		return m.render().then(function (mapNode) {
			return E('div', {}, [
				statusBlock(running, uci.get('__PKG_NAME__', 'main', 'enabled') === '1'),
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('Node')),
					nodePicker(proxiesData)
				]),
				mapNode
			]);
		});
	}
});
