'use strict';
'require view';
'require ui';
'require tools.__PKG_NAME__ as api';

const SELECTABLE = { 'Selector': true, 'URLTest': true, 'Fallback': true, 'LoadBalance': true };
/* mihomo built-in groups that just add noise here */
const HIDE = { 'GLOBAL': true };
const TEST_URL = 'http://www.gstatic.com/generate_204';

function fmtDelay(d) {
	if (d == null) return _('n/a');
	if (d <= 0) return _('timeout');
	return d + ' ms';
}

/* annotate the <option>s with per-node latency and update the group's cell */
function applyDelays(sel, cell, map) {
	Array.from(sel.options).forEach(function (opt) {
		const name = opt.getAttribute('data-name') || opt.value;
		opt.setAttribute('data-name', name);
		const d = map ? map[name] : null;
		opt.textContent = name + '  ·  ' + fmtDelay(d);
	});
	cell.textContent = fmtDelay(map ? map[sel.value] : null);
	cell.style.color = '';
}

function testGroup(group, sel, cell, btn) {
	btn.disabled = true;
	cell.textContent = '…';
	return api.api('GET', '/group/' + encodeURIComponent(group) + '/delay',
			'url=' + encodeURIComponent(TEST_URL) + '&timeout=5000', '')
		.then(function (res) {
			applyDelays(sel, cell, (res && typeof res === 'object') ? res : {});
		})
		.catch(function () { cell.textContent = _('test failed'); cell.style.color = '#c0392b'; })
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
		'style': 'min-width:20em;max-width:100%',
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
		E('td', { 'class': 'td left', 'style': 'font-weight:bold' }, [ group,
			E('div', { 'style': 'font-weight:normal;color:#888;font-size:90%' }, info.type) ]),
		E('td', { 'class': 'td left' }, [ sel ]),
		cell,
		E('td', { 'class': 'td left' }, [ btn ])
	]);
}

return view.extend({
	load: function () {
		return api.api('GET', '/proxies').catch(function () { return null; });
	},

	render: function (data) {
		const proxies = (data && data.proxies) || {};
		const names = Object.keys(proxies).filter(function (k) {
			return !HIDE[k] && SELECTABLE[proxies[k].type] && (proxies[k].all || []).length;
		});

		const body = E('div', { 'class': 'cbi-map' }, [
			E('h2', _('%s — Proxies').format('__BRAND_NAME__')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Pick which node each Select group uses. Auto-select groups (URL-test / Fallback) are read-only. Selection is live and persists across restarts. Use Test to measure per-node latency.'))
		]);

		if (!names.length) {
			body.appendChild(E('p', { 'class': 'alert-message warning' },
				_('No proxy groups found. Is the service running and are subscriptions loaded?')));
			return body;
		}

		const tbl = E('table', { 'class': 'table cbi-section-table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Group')),
				E('th', { 'class': 'th' }, _('Node')),
				E('th', { 'class': 'th' }, _('Latency')),
				E('th', { 'class': 'th' }, '')
			])
		]);
		names.forEach(function (g) { tbl.appendChild(groupRow(g, proxies[g])); });

		const testAll = E('button', { 'class': 'cbi-button cbi-button-neutral', 'style': 'margin-top:1em' }, _('Test all'));
		testAll.addEventListener('click', function () {
			tbl.querySelectorAll('tr.tr button.cbi-button-action').forEach(function (b) { b.click(); });
		});
		const refresh = E('button', { 'class': 'cbi-button cbi-button-neutral', 'style': 'margin:1em 0 0 .5em' }, _('Refresh'));
		refresh.addEventListener('click', function () { location.reload(); });

		body.appendChild(E('div', { 'class': 'cbi-section' }, [ tbl, testAll, refresh ]));
		return body;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
