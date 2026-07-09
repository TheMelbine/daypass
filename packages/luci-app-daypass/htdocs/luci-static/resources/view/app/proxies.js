'use strict';
'require view';
'require ui';
'require poll';
'require tools.__PKG_NAME__ as api';

/* Groups you can act on. Selector = manual pick; the rest auto-select. */
const SELECTABLE = { 'Selector': true, 'URLTest': true, 'Fallback': true, 'LoadBalance': true };

function switchNode(group, name, el) {
	el.disabled = true;
	return api.api('PUT', '/proxies/' + encodeURIComponent(group), '', JSON.stringify({ name: name }))
		.then(function () {
			ui.addNotification(null, E('p', _('%s → %s').format(group, name)), 'info');
		})
		.catch(function () {
			ui.addNotification(null, E('p', _('Failed to switch %s').format(group)), 'danger');
		})
		.finally(function () { el.disabled = false; });
}

function testNode(group, el, out) {
	el.disabled = true;
	out.textContent = '…';
	return api.api('GET', '/group/' + encodeURIComponent(group) + '/delay',
			'url=http://www.gstatic.com/generate_204&timeout=5000', '')
		.then(function (res) {
			/* res is a map of node -> delay(ms) */
			out.textContent = _('tested');
			if (res && typeof res === 'object')
				ui.addNotification(null, E('p', _('Latency test done for %s').format(group)), 'info');
		})
		.catch(function () { out.textContent = _('test failed'); })
		.finally(function () { el.disabled = false; });
}

function groupRow(group, info) {
	const nodes = info.all || [];
	const isSelector = (info.type === 'Selector');

	const sel = E('select', {
		'class': 'cbi-input-select',
		'style': 'min-width:18em;max-width:100%',
		'disabled': isSelector ? null : 'disabled'
	}, nodes.map(function (n) {
		return E('option', { 'value': n, 'selected': (n === info.now) ? 'selected' : null }, [ n ]);
	}));

	if (isSelector)
		sel.addEventListener('change', function () { switchNode(group, this.value, this); });

	const delayOut = E('span', { 'style': 'margin-left:.5em;color:#888' }, '');
	const testBtn = E('button', {
		'class': 'cbi-button cbi-button-action',
		'click': function () { testNode(group, this, delayOut); }
	}, _('Test'));

	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'style': 'font-weight:bold' }, [ group,
			E('div', { 'style': 'font-weight:normal;color:#888;font-size:90%' }, info.type) ]),
		E('td', { 'class': 'td left' }, [ sel ]),
		E('td', { 'class': 'td left' }, [ testBtn, delayOut ])
	]);
}

return view.extend({
	load: function () {
		return api.api('GET', '/proxies').catch(function () { return null; });
	},

	render: function (data) {
		const proxies = (data && data.proxies) || {};
		const names = Object.keys(proxies).filter(function (k) {
			return SELECTABLE[proxies[k].type] && (proxies[k].all || []).length;
		});

		const body = E('div', { 'class': 'cbi-map' }, [
			E('h2', _('%s — Proxies').format('__BRAND_NAME__')),
			E('div', { 'class': 'cbi-map-descr' },
				_('Pick which node each Select group uses. Auto-select groups (URL-test / Fallback) are shown read-only. Selection is live and persists across restarts.'))
		]);

		if (!names.length) {
			body.appendChild(E('p', { 'class': 'alert-message warning' },
				_('No proxy groups found. Is the service running and are subscriptions loaded? (Connection / Subscriptions pages.)')));
			return body;
		}

		const tbl = E('table', { 'class': 'table cbi-section-table' }, [
			E('tr', { 'class': 'tr table-titles' }, [
				E('th', { 'class': 'th' }, _('Group')),
				E('th', { 'class': 'th' }, _('Node')),
				E('th', { 'class': 'th' }, _('Latency'))
			])
		]);
		names.forEach(function (g) { tbl.appendChild(groupRow(g, proxies[g])); });

		const refresh = E('button', {
			'class': 'cbi-button cbi-button-neutral',
			'style': 'margin-top:1em',
			'click': function () { location.reload(); }
		}, _('Refresh'));

		body.appendChild(E('div', { 'class': 'cbi-section' }, [ tbl, refresh ]));
		return body;
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
