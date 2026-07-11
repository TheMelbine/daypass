'use strict';
'require view';
'require form';
'require uci';
'require tools.__PKG_NAME__ as api';

/* Per-device full tunnel: every device listed here has ALL its traffic routed
 * through the proxy, regardless of destination. Matched by MAC (survives DHCP
 * IP changes) and/or IPv4. Pure nft layer — see nft.ut force_mac / force4. */

return view.extend({
	load: function () {
		return Promise.all([
			uci.load('__PKG_NAME__'),
			L.resolveDefault(api.leases(), null)
		]);
	},

	render: function (data) {
		const leases = (data[1] && Array.isArray(data[1].leases)) ? data[1].leases : [];

		let m, s, o;

		m = new form.Map('__PKG_NAME__',
			_('%s — Devices').format('__BRAND_NAME__'),
			_('Route every device listed here fully through the proxy, whatever it connects to. Matched by MAC (survives IP changes).'));

		s = m.section(form.GridSection, 'device', _('Devices via VPN'));
		s.addremove = true;
		s.anonymous = true;
		s.nodescriptions = true;
		s.modaltitle = _('Device');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o.editable = true;
		o.default = '1';

		o = s.option(form.Value, 'name', _('Name'));
		o.placeholder = _('e.g. PlayStation');

		o = s.option(form.Value, 'mac', _('MAC address'),
			_('Pick a known device or type a MAC. Preferred — survives DHCP IP changes.'));
		o.datatype = 'macaddr';
		o.rmempty = true;
		leases.forEach(function (l) {
			if (l.mac)
				o.value(l.mac, (l.name ? l.name + ' — ' : '') + l.ip + ' — ' + l.mac);
		});
		/* auto-fill the Name field from the chosen lease when empty */
		o.onchange = function (ev, section_id, value) {
			const lease = leases.filter(function (l) { return l.mac === value; })[0];
			if (lease && lease.name && !uci.get('__PKG_NAME__', section_id, 'name'))
				uci.set('__PKG_NAME__', section_id, 'name', lease.name);
		};

		o = s.option(form.Value, 'ip', _('IP address'),
			_('Optional. Use instead of (or with) the MAC.'));
		o.datatype = 'ip4addr';
		o.modalonly = true;
		o.rmempty = true;

		return m.render();
	}
});
