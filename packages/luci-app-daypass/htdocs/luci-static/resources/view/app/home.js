'use strict';
'require view';
'require ui';
'require uci';
'require tools.__PKG_NAME__ as api';

/* Simple-mode home screen. The whole app for a non-technical user: log in
 * through the provider bot once, then a single on/off state with a node picker.
 * Every advanced tab (Connection/Devices/Rules/...) is hidden behind the
 * main.advanced_ui uci flag — see menu.d, which gates on it. */

const ACCENT = '__ACCENT__';

/* Self-contained i18n for the simple-mode page: the audience is non-technical,
 * so Russian must work even when the .lmo catalog lags behind. Keys are the
 * English sources; anything missing falls back to the normal _() pipeline. */
const RU = {
	'Code from the bot': 'Код из бота',
	'Enter the code from the bot first.': 'Сначала введите код из бота.',
	'Done! Your VPN is set up.': 'Готово! VPN настроен.',
	'unknown error': 'неизвестная ошибка',
	'Login failed: %s': 'Не удалось войти: %s',
	'Log in': 'Войти',
	'Connect your %s account': 'Подключите аккаунт %s',
	'One time only — after this everything works by itself.': 'Один раз — дальше всё работает само.',
	'Open ': 'Откройте ',
	'our Telegram bot': 'нашего Telegram-бота',
	' and press Start': ' и нажмите «Начать»',
	'The bot sends you a login code': 'Бот пришлёт код для входа',
	'Type the code here:': 'Введите код сюда:',
	'Turn off': 'Выключить',
	'Turn on': 'Включить',
	'VPN is working': 'VPN работает',
	'VPN is off': 'VPN выключен',
	'Blocked sites and apps open automatically.': 'Заблокированные сайты и приложения открываются сами.',
	'Turn it on to open blocked sites and apps.': 'Включите — и заблокированные сайты снова будут открываться.',
	'Server changed to %s': 'Сервер изменён: %s',
	'Server (change if it feels slow):': 'Сервер (смените, если медленно):',
	'Refresh subscription': 'Обновить подписку',
	'Subscription updated.': 'Подписка обновлена.',
	'Update failed.': 'Не удалось обновить.',
	'Log out': 'Выйти',
	'Log out? The VPN will stop working until you log in again.': 'Выйти из аккаунта? VPN перестанет работать, пока вы не войдёте снова.',
	'Advanced settings (for experienced users)': 'Расширенные настройки (для опытных)'
};
const IS_RU = ((document.documentElement.lang || '').toLowerCase().indexOf('ru') === 0);
function T(s) { return (IS_RU && RU[s]) || _(s); }

function proxyGroup() {
	const s = uci.sections('__PKG_NAME__', 'proxy');
	return (s.length && s[0]['.name']) || 'PROXY';
}

function card(children) {
	return E('div', {
		'style': 'background:var(--background-color-high,#fff);border:1px solid var(--border-color-medium,#e5e5e5);' +
			'border-radius:12px;padding:20px 24px;margin-bottom:16px;box-shadow:0 1px 3px rgba(0,0,0,.06);'
	}, children);
}

return view.extend({
	handleSaveApply: null,
	handleSave: null,
	handleReset: null,

	load: function () {
		return uci.load('__PKG_NAME__').then(function () {
			const grp = proxyGroup();
			return Promise.all([
				L.resolveDefault(api.accountStatus(), { enabled: false }),
				L.resolveDefault(api.api('GET', '/version', '', ''), null),
				L.resolveDefault(api.api('GET', '/proxies/' + grp, '', ''), null)
			]);
		});
	},

	render: function (data) {
		const st = data[0] || { enabled: false };
		const running = !!(data[1] && data[1].version);
		const group = data[2];

		const wrap = E('div', { 'style': 'max-width:600px;margin:0 auto;' });

		if (st.enabled && !st.logged_in)
			wrap.appendChild(this.renderLogin(st));
		else
			wrap.appendChild(this.renderState(st, running, group));

		wrap.appendChild(this.renderAdvancedToggle());
		return wrap;
	},

	/* ---- babushka login: three steps, one input, one button ---- */
	renderLogin: function (st) {
		const codeInput = E('input', {
			'type': 'text',
			'inputmode': 'numeric',
			'autocomplete': 'one-time-code',
			'placeholder': T('Code from the bot'),
			'style': 'font-size:22px;letter-spacing:.2em;text-align:center;width:100%;max-width:260px;' +
				'padding:10px 12px;border:1px solid var(--border-color-medium,#ccc);border-radius:10px;font-family:monospace;'
		});

		const loginBtn = E('button', {
			'style': 'font-size:17px;font-weight:600;padding:12px 28px;border:none;border-radius:10px;cursor:pointer;' +
				'background:' + ACCENT + ';color:#fff;width:100%;max-width:260px;',
			'click': ui.createHandlerFn(this, function () {
				const code = (codeInput.value || '').trim();
				if (!code) {
					ui.addNotification(null, E('p', T('Enter the code from the bot first.')));
					return Promise.resolve();
				}
				return api.accountLogin(code).then(function (res) {
					if (res && res.ok) {
						ui.addNotification(null, E('p', T('Done! Your VPN is set up.')), 'info');
						location.reload();
					} else {
						const msg = (res && (res.detail || res.error)) || T('unknown error');
						ui.addNotification(null, E('p', T('Login failed: %s').format(msg)));
					}
				});
			})
		}, T('Log in'));

		return card([
			E('h2', { 'style': 'margin:0 0 6px;' }, T('Connect your %s account').format('__BRAND_NAME__')),
			E('p', { 'style': 'color:var(--text-color-medium,#666);margin:0 0 16px;' },
				T('One time only — after this everything works by itself.')),
			E('ol', { 'style': 'line-height:2;margin:0 0 16px;padding-left:20px;' }, [
				E('li', {}, [ T('Open '),
					E('a', { 'href': st.bot_url, 'target': '_blank', 'rel': 'noreferrer',
						'style': 'font-weight:600;' }, T('our Telegram bot')),
					T(' and press Start') ]),
				E('li', {}, T('The bot sends you a login code')),
				E('li', {}, T('Type the code here:'))
			]),
			E('div', { 'style': 'display:flex;flex-direction:column;gap:10px;align-items:center;padding:6px 0 4px;' }, [
				codeInput, loginBtn
			])
		]);
	},

	/* ---- logged in (or accountless build): one status, one switch, one picker ---- */
	renderState: function (st, running, group) {
		const self = this;

		const dot = E('span', {
			'style': 'display:inline-block;width:14px;height:14px;border-radius:50%;margin-right:10px;' +
				'background:' + (running ? ACCENT : '#c0392b') + ';'
		});

		const bigBtn = E('button', {
			'style': 'font-size:17px;font-weight:600;padding:12px 28px;border:none;border-radius:10px;cursor:pointer;' +
				'background:' + (running ? 'var(--background-color-medium,#eee)' : ACCENT) + ';' +
				'color:' + (running ? 'var(--text-color-high,#333)' : '#fff') + ';',
			'click': ui.createHandlerFn(self, function () {
				uci.set('__PKG_NAME__', 'main', 'enabled', running ? '0' : '1');
				return uci.save()
					.then(function () { return uci.apply(); })
					.then(function () { return running ? api.stop() : api.start(); })
					.then(function () { window.setTimeout(function () { location.reload(); }, 2000); });
			})
		}, running ? T('Turn off') : T('Turn on'));

		const rows = [
			E('div', { 'style': 'display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;' }, [
				E('div', {}, [
					E('h2', { 'style': 'margin:0;display:flex;align-items:center;' }, [
						dot, running ? T('VPN is working') : T('VPN is off')
					]),
					E('p', { 'style': 'color:var(--text-color-medium,#666);margin:6px 0 0;' },
						running
							? T('Blocked sites and apps open automatically.')
							: T('Turn it on to open blocked sites and apps.'))
				]),
				bigBtn
			])
		];

		/* node picker — only when the core is up and the group is known */
		if (running && group && Array.isArray(group.all) && group.all.length) {
			const sel = E('select', {
				'style': 'font-size:15px;padding:8px 10px;border-radius:8px;max-width:100%;',
				'change': ui.createHandlerFn(self, function (ev) {
					const name = ev.target.value;
					return api.api('PUT', '/proxies/' + proxyGroup(), '', JSON.stringify({ name: name }))
						.then(function () {
							ui.addNotification(null, E('p', T('Server changed to %s').format(name)), 'info');
						});
				})
			}, group.all.map(function (n) {
				return E('option', { 'value': n, 'selected': (n === group.now) ? '' : null }, n);
			}));

			rows.push(E('div', { 'style': 'margin-top:18px;padding-top:16px;border-top:1px solid var(--border-color-medium,#eee);' }, [
				E('label', { 'style': 'display:block;font-size:13px;color:var(--text-color-medium,#666);margin-bottom:6px;' },
					T('Server (change if it feels slow):')),
				sel
			]));
		}

		/* small maintenance line for account builds */
		if (st.enabled) {
			rows.push(E('div', { 'style': 'margin-top:14px;display:flex;gap:18px;font-size:13px;' }, [
				E('a', { 'href': '#', 'click': ui.createHandlerFn(self, function () {
					return api.accountSync().then(function (res) {
						ui.addNotification(null, E('p', (res && res.ok) ? T('Subscription updated.') : T('Update failed.')),
							(res && res.ok) ? 'info' : null);
					});
				}) }, T('Refresh subscription')),
				E('a', { 'href': '#', 'click': ui.createHandlerFn(self, function () {
					if (!confirm(T('Log out? The VPN will stop working until you log in again.')))
						return Promise.resolve();
					return api.accountLogout().then(function () { location.reload(); });
				}) }, T('Log out'))
			]));
		}

		return card(rows);
	},

	/* ---- the gate to the full interface ---- */
	renderAdvancedToggle: function () {
		const on = (uci.get('__PKG_NAME__', 'main', 'advanced_ui') === '1');
		const cb = E('input', {
			'type': 'checkbox',
			'checked': on ? '' : null,
			'change': ui.createHandlerFn(this, function (ev) {
				uci.set('__PKG_NAME__', 'main', 'advanced_ui', ev.target.checked ? '1' : '0');
				return uci.save()
					.then(function () { return uci.apply(); })
					.then(function () { location.reload(); });
			})
		});
		return E('div', { 'style': 'text-align:center;padding:4px 0 12px;color:var(--text-color-medium,#888);font-size:13px;' }, [
			E('label', { 'style': 'cursor:pointer;display:inline-flex;align-items:center;gap:6px;' }, [
				cb, T('Advanced settings (for experienced users)')
			])
		]);
	}
});
