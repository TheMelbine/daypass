'use strict';
'require view';
'require ui';
'require poll';
'require tools.__PKG_NAME__ as api';
'require view.__PKG_NAME__.main as main';

const PRE_STYLE = 'white-space:pre-wrap;word-break:break-word;max-height:24em;overflow:auto;' +
	'padding:.6em .8em;border:1px solid rgba(128,128,128,.35);border-radius:4px;' +
	'background:rgba(128,128,128,.06);font-family:monospace;font-size:12px;margin:0';

function kvRow(label, value) {
	return E('tr', { 'class': 'tr' }, [
		E('td', { 'class': 'td left', 'style': 'width:33%;font-weight:bold' }, label),
		E('td', { 'class': 'td left' }, value || '?')
	]);
}

return view.extend({
	load: function () {
		return Promise.all([
			L.resolveDefault(api.version(), {}),
			L.resolveDefault(api.logs(200), '')
		]);
	},

	render: function (data) {
		const version = data[0] || {};
		const initialLog = data[1] || '';
		const brand = (main.brandInfo ? main.brandInfo() : {}) || {};
		const accent = brand.accent || '__ACCENT__';

		const diagOut = E('pre', { 'style': PRE_STYLE }, _('Pick a check above.'));
		const logOut = E('pre', { 'id': 'diag_log', 'style': PRE_STYLE }, initialLog || _('(log empty)'));

		function runDiag(check) {
			diagOut.textContent = _('Running %s…').format(check);
			return L.resolveDefault(api.diag(check), '').then(function (out) {
				diagOut.textContent = (out && out.length) ? out : _('(no output)');
			});
		}

		function diagButton(check, label) {
			return E('button', {
				'class': 'btn cbi-button cbi-button-action',
				'style': 'margin:0 .4em .4em 0',
				'click': ui.createHandlerFn(this, function () { return runDiag(check); })
			}, label);
		}

		/* Live log tail (no streaming required). */
		poll.add(function () {
			return L.resolveDefault(api.logs(200), null).then(function (log) {
				if (log != null)
					logOut.textContent = log.length ? log : _('(log empty)');
			});
		});

		const footerLinks = [];
		if (brand.supportUrl || '__SUPPORT_URL__')
			footerLinks.push(E('a', { 'href': brand.supportUrl || '__SUPPORT_URL__', 'target': '_blank', 'rel': 'noreferrer' }, _('Support')));
		if (brand.docsUrl || '__DOCS_URL__')
			footerLinks.push(E('span', {}, ' · '), E('a', { 'href': brand.docsUrl || '__DOCS_URL__', 'target': '_blank', 'rel': 'noreferrer' }, _('Documentation')));

		return E('div', {}, [
			E('h2', {}, _('%s — Diagnostics').format('__BRAND_NAME__')),

			/* ---- Version ---- */
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Version')),
				E('table', { 'class': 'table' }, [
					kvRow(_('App'), version.app),
					kvRow(_('Core (mihomo)'), version.core)
				])
			]),

			/* ---- Checks ---- */
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Checks')),
				E('div', {}, [
					diagButton('config', _('Config')),
					diagButton('dns', _('DNS')),
					diagButton('proxy', _('Proxy')),
					diagButton('nft', _('nftables'))
				]),
				diagOut
			]),

			/* ---- Log ---- */
			E('div', { 'class': 'cbi-section' }, [
				E('h3', {}, _('Core log')),
				E('div', { 'style': 'margin-bottom:.4em' }, [
					E('button', {
						'class': 'btn cbi-button cbi-button-neutral',
						'click': ui.createHandlerFn(this, function () {
							return L.resolveDefault(api.logs(200), '').then(function (log) {
								logOut.textContent = log && log.length ? log : _('(log empty)');
							});
						})
					}, _('Refresh'))
				]),
				logOut
			]),

			/* ---- Brand footer ---- */
			E('div', {
				'class': 'cbi-section',
				'style': 'border-top:2px solid ' + accent + ';padding-top:.6em;color:var(--fg,inherit)'
			}, [
				E('p', { 'style': 'margin:0' }, footerLinks)
			])
		]);
	}
});
