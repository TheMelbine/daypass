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
			_('%s — Subscriptions').format('__BRAND_NAME__'),
			_('mihomo proxy-providers. Each subscription URL is fetched and health-checked by mihomo; reference a subscription by name from a proxy group on the Connection page.'));

		/* Named sections: the section name is the provider name used in groups. */
		s = m.section(form.GridSection, 'subscription', _('Subscriptions'));
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
			if (value && !/^https?:\/\//.test(value))
				return _('Must be an http(s) URL');
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

		return m.render();
	}
});
