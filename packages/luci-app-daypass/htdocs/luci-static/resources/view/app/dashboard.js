'use strict';
'require view';
'require form';
'require uci';
'require view.__PKG_NAME__.main as main';

/* Mounts the fe-app DashboardTab. A synthetic TypedSection (cfgsections forced to
 * ['dashboard']) carries a single rawhtml DummyValue whose cfgvalue initialises the
 * controller and returns the rendered node. */
return view.extend({
	load: function () {
		return uci.load('__PKG_NAME__');
	},

	render: function () {
		const m = new form.Map('__PKG_NAME__', '__BRAND_NAME__',
			_('Live proxy dashboard.'));

		const s = m.section(form.TypedSection, 'dashboard', _('Dashboard'));
		s.anonymous = true;
		s.addremove = false;
		s.cfgsections = function () {
			return ['dashboard'];
		};

		const o = s.option(form.DummyValue, '_mount_node');
		o.rawhtml = true;
		o.cfgvalue = function () {
			main.DashboardTab.initController();
			return main.DashboardTab.render();
		};

		return m.render();
	}
});
