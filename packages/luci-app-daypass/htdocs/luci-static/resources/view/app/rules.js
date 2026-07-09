'use strict';
'require view';
'require form';
'require uci';
'require tools.__PKG_NAME__ as api';

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

const PKG = '__PKG_NAME__';

/* rule-sets belonging to a shipped preset, matched by tag OR name (covers both
 * fresh installs and migrated configs with trailing-underscore names). */
function presetRulesets(preset, nameRe) {
	return uci.sections(PKG, 'ruleset')
		.filter(function (s) { return s.preset === preset || nameRe.test(s['.name']); })
		.map(function (s) { return s['.name']; });
}
function anyEnabled(names) {
	return names.some(function (n) { return uci.get(PKG, n, 'enabled') === '1'; });
}
function setEnabled(names, v) {
	names.forEach(function (n) { uci.set(PKG, n, 'enabled', v); });
}

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('__PKG_NAME__'),
			L.resolveDefault(api.lists(), null)
		]);
	},

	render: function (data) {
		const catalog = (data[1] && Array.isArray(data[1].lists) && data[1].lists.length)
			? data[1].lists
			: FALLBACK_LISTS;

		let m, s, o;

		m = new form.Map('__PKG_NAME__',
			_('%s — Rules').format('__BRAND_NAME__'),
			_('Routing mode, custom rule-sets and raw rule lines. Rule order: your "before" rules, then rule-sets (top to bottom), then community/route rules, then MATCH.'));

		const ADS = presetRulesets('ads', /^ads_?$/);
		const RU = presetRulesets('ru_unblock', /^ru_blocked_/);
		const managed = {};
		ADS.concat(RU).forEach(function (n) { managed[n] = true; });

		/* ---------------- ready-made lists (friendly toggles) ---------------- */
		s = m.section(form.NamedSection, 'settings', 'settings', _('Ready-made lists'),
			_('Quick switches for the built-in lists. Fine-tune the raw providers below.'));
		s.addremove = false;

		o = s.option(form.Flag, '_preset_ads', _('Block ads'));
		o.rmempty = false;
		o.load = function () { return anyEnabled(ADS) ? '1' : '0'; };
		o.write = function (sid, v) { setEnabled(ADS, v); };
		o.remove = function () {};

		o = s.option(form.Flag, '_preset_ru', _('Unblock RU-restricted resources'));
		o.rmempty = false;
		o.load = function () { return anyEnabled(RU) ? '1' : '0'; };
		o.write = function (sid, v) { setEnabled(RU, v); };
		o.remove = function () {};

		/* ---------------- routing mode + inline rules (settings) ---------------- */
		s = m.section(form.NamedSection, 'settings', 'settings', _('Routing'));
		s.addremove = false;
		s.anonymous = true;

		o = s.option(form.ListValue, 'routing_mode', _('Routing mode'),
			_('Selective: only listed domains/subnets reach mihomo (efficient). Full: all LAN traffic is tproxied to mihomo, so every rule (incl. ipcidr) applies and unmatched traffic goes DIRECT.'));
		o.value('selective', _('Selective (efficient)'));
		o.value('full', _('Full (all traffic via mihomo)'));
		o.default = 'selective';

		o = s.option(form.DynamicList, 'prepend_rules', _('Rules — before (highest priority)'),
			_('Raw mihomo rule lines evaluated first. e.g. %s or %s')
				.format('<code>AND,((NETWORK,udp),(DST-PORT,443)),REJECT</code>',
					'<code>IP-CIDR,192.168.0.0/16,DIRECT,no-resolve</code>'));

		o = s.option(form.DynamicList, 'append_rules', _('Rules — after'),
			_('Raw mihomo rule lines applied after the generated rules, before the final MATCH.'));

		/* ---------------- route buckets (which lists via which proxy) ---------------- */
		s = m.section(form.TypedSection, 'route', _('Lists to route'),
			_('Pick the community lists (and any custom domains/subnets) that should travel through a proxy.'));
		s.anonymous = false;
		s.addremove = true;

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;

		o = s.option(form.ListValue, 'proxy', _('Proxy'),
			_('Which proxy group this bucket routes through.'));
		const proxies = uci.sections('__PKG_NAME__', 'proxy');
		if (proxies.length)
			proxies.forEach(function (px) { o.value(px['.name'], px['.name']); });
		else
			o.value('main', 'main');

		o = s.option(form.MultiValue, 'community_lists', _('Community lists'),
			_('Domains and subnets in the selected lists are routed through the proxy.'));
		o.display_size = 12;
		catalog.forEach(function (item) { o.value(item.tag, item.label || item.tag); });
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

		/* ---------------- custom rule-providers ---------------- */
		s = m.section(form.GridSection, 'ruleset', _('Custom rule-sets'),
			_('External (URL) or local (file) rule providers, each routed to an action.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.modaltitle = _('Rule-set');
		/* preset lists are driven by the toggles above; hide them from the raw grid */
		s.filter = function (section_id) { return !managed[section_id]; };

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o.editable = true;

		o = s.option(form.ListValue, 'behavior', _('Behavior'));
		o.value('domain', _('domain'));
		o.value('ipcidr', _('ipcidr'));
		o.value('classical', _('classical'));
		o.default = 'domain';

		o = s.option(form.ListValue, 'format', _('Format'));
		o.value('mrs', 'mrs');
		o.value('yaml', 'yaml');
		o.value('text', 'text');
		o.default = 'mrs';

		o = s.option(form.Value, 'action', _('Action'),
			_('PROXY, DIRECT, REJECT or a proxy group name.'));
		o.default = 'PROXY';
		o.rmempty = false;
		uci.sections('__PKG_NAME__', 'proxy').forEach(function (px) { o.value(px['.name'], px['.name']); });
		o.value('DIRECT', 'DIRECT');
		o.value('REJECT', 'REJECT');

		o = s.option(form.Value, 'url', _('URL'),
			_('http(s) rule-provider URL (leave empty for a local file).'));

		o = s.option(form.Value, 'file', _('Local file'),
			_('Absolute path to a local rule file (alternative to URL).'));
		o.modalonly = true;

		o = s.option(form.Flag, 'no_resolve', _('no-resolve'),
			_('For ipcidr rules: match on the destination IP without a DNS lookup.'));
		o.modalonly = true;
		o.depends('behavior', 'ipcidr');

		o = s.option(form.Value, 'interval', _('Update interval (s)'));
		o.datatype = 'uinteger';
		o.placeholder = '86400';
		o.modalonly = true;

		return m.render();
	}
});
