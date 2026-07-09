'use strict';
'require view';
'require form';
'require uci';

return view.extend({
	load: function () {
		return uci.load('__PKG_NAME__');
	},

	render: function () {
		let m, s, o;

		m = new form.Map('__PKG_NAME__',
			_('%s — Rules').format('__BRAND_NAME__'),
			_('Routing mode, custom rule-sets and raw rule lines. Rule order: your "before" rules, then rule-sets (top to bottom), then community/route rules, then MATCH.'));

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

		/* ---------------- custom rule-providers ---------------- */
		s = m.section(form.GridSection, 'ruleset', _('Custom rule-sets'),
			_('External (URL) or local (file) rule providers, each routed to an action.'));
		s.addremove = true;
		s.anonymous = false;
		s.nodescriptions = true;
		s.modaltitle = _('Rule-set');

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
		uci.sections('__PKG_NAME__', 'proxy').forEach(function (px) {
			o.value(px['.name'], px['.name']);
		});
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
