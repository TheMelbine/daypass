'use strict';
'require view';
'require form';
'require uci';
'require tools.widgets as widgets';

return view.extend({
	load: function () {
		return uci.load('__PKG_NAME__');
	},

	render: function () {
		let m, s, o;

		m = new form.Map('__PKG_NAME__',
			_('%s — Settings').format('__BRAND_NAME__'),
			_('Core, DNS, network and list settings. Defaults are safe; change only what you need.'));

		s = m.section(form.NamedSection, 'settings', 'settings', _('Settings'));
		s.addremove = false;
		s.anonymous = true;

		s.tab('dns', _('DNS'));
		s.tab('network', _('Network'));
		s.tab('lists', _('Lists'));
		s.tab('advanced', _('Advanced'));

		/* ---------------- DNS ---------------- */
		o = s.taboption('dns', form.ListValue, 'dns_type', _('DNS protocol'),
			_('Protocol used to reach the upstream DNS server.'));
		o.value('udp', _('UDP (plain, unencrypted)'));
		o.value('doh', _('DNS over HTTPS (DoH)'));
		o.value('dot', _('DNS over TLS (DoT)'));
		o.default = 'doh';
		o.rmempty = false;

		o = s.taboption('dns', form.Value, 'dns_server', _('DNS server'),
			_('DoH/DoT URL or plain IP, matching the protocol above.'));
		o.placeholder = 'https://1.1.1.1/dns-query';
		o.rmempty = false;

		o = s.taboption('dns', form.Value, 'bootstrap_dns_server', _('Bootstrap DNS server'),
			_('Plain-IP resolver used to look up the DNS server hostname.'));
		o.datatype = 'ipaddr';
		o.placeholder = '1.1.1.1';

		/* ---------------- Network ---------------- */
		o = s.taboption('network', widgets.DeviceSelect, 'source_network_interfaces',
			_('LAN interfaces'),
			_('Traffic entering on these interfaces is eligible for proxying. Matches the nft lan_ifaces set (device / ifname).'));
		o.multiple = true;
		o.noaliases = true;
		o.nobridges = false;
		o.rmempty = false;

		/* ---------------- Lists ---------------- */
		o = s.taboption('lists', form.ListValue, 'update_interval', _('List update interval'),
			_('How often subnet lists are refreshed into the nft set.'));
		o.value('1h', _('Every hour'));
		o.value('3h', _('Every 3 hours'));
		o.value('12h', _('Every 12 hours'));
		o.value('1d', _('Daily'));
		o.value('3d', _('Every 3 days'));
		o.default = '1d';

		/* ---------------- Advanced ---------------- */
		o = s.taboption('advanced', form.ListValue, 'log_level', _('Log level'));
		o.value('silent', _('Silent'));
		o.value('error', _('Error'));
		o.value('warning', _('Warning'));
		o.value('info', _('Info'));
		o.value('debug', _('Debug'));
		o.default = 'warning';

		o = s.taboption('advanced', form.Value, 'api_secret', _('API secret'),
			_('Bearer token for the mihomo REST API (127.0.0.1:9090). Auto-generated on first boot.'));
		o.password = true;

		o = s.taboption('advanced', form.ListValue, 'dashboard', _('Dashboard'),
			_('Bundled clash dashboard served by mihomo external-ui.'));
		o.value('zashboard', 'zashboard');
		o.value('metacubexd', 'metacubexd');
		o.default = '__DASHBOARD__';

		o = s.taboption('advanced', form.Flag, 'disable_quic', _('Disable QUIC'),
			_('Block QUIC (UDP/443) so browsers fall back to TCP/TLS for more reliable sniffing.'));

		o = s.taboption('advanced', form.Flag, 'dont_touch_dhcp', _('Do not modify DHCP/DNS'),
			_('Skip the dnsmasq takeover. Advanced: you must repoint client DNS to mihomo yourself.'));

		return m.render();
	}
});
