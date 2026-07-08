// DashboardTab — phase-1 landing card for the LuCI app. render() is fully static
// (no live streaming required to paint): a branded card, an "Open dashboard"
// button that resolves the mihomo web-UI URL from dashboard_info() on click, and
// a service-status line filled in by initController(). Reserved (hidden) widget
// containers are left in place for future live traffic/connection widgets.

import { brandInfo } from './brand';
import { dashboardInfo, serviceStatus, DashboardInfo } from './rpc';
import { DASHBOARD, VERSION, API_PORT } from './constants';

const IDS = {
  root: '__PKG_NAME__-dashboard',
  status: '__PKG_NAME__-dashboard-status',
  statusText: '__PKG_NAME__-dashboard-status-text',
  widgets: '__PKG_NAME__-dashboard-widgets',
};

// One status-poll handle so destroy() can tear it down.
let statusTimer: ReturnType<typeof setInterval> | null = null;

// language=CSS
export const styles = `
.__PKG_NAME__-card {
  --accent: __ACCENT__;
  border: 1px solid var(--border-color-medium, rgba(0,0,0,.12));
  border-radius: 8px;
  padding: 20px;
  max-width: 640px;
  margin-top: 10px;
}
.__PKG_NAME__-card__header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 6px;
}
.__PKG_NAME__-card__badge {
  color: #fff;
  background: var(--accent);
  border-radius: 4px;
  padding: 2px 8px;
  font-weight: 700;
  font-size: 12px;
  letter-spacing: .02em;
}
.__PKG_NAME__-card__title {
  margin: 0;
  font-size: 18px;
}
.__PKG_NAME__-card__version {
  margin-left: auto;
  opacity: .6;
  font-size: 12px;
}
.__PKG_NAME__-card__desc {
  margin: 6px 0 14px;
  opacity: .85;
}
.__PKG_NAME__-card__status {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 14px;
}
.__PKG_NAME__-status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--border-color-high, #999);
  flex: 0 0 auto;
}
.__PKG_NAME__-status-dot--up { background: var(--success-color-medium, #2e7d32); }
.__PKG_NAME__-status-dot--down { background: var(--error-color-medium, #c62828); }
.__PKG_NAME__-card__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.__PKG_NAME__-card__actions .btn { text-decoration: none; }
.__PKG_NAME__-card__actions .__PKG_NAME__-btn--primary {
  background: var(--accent);
  border-color: var(--accent);
  color: #fff;
}
.__PKG_NAME__-widgets { margin-top: 16px; }
`;

function buildDashboardUrl(info: DashboardInfo): string {
  const proto = info && info.https ? 'https' : 'http';
  const host =
    typeof window !== 'undefined' && window.location
      ? window.location.hostname
      : '127.0.0.1';
  const port = (info && info.port) || API_PORT;
  const ui = info && info.ui_name ? info.ui_name : DASHBOARD;
  const secret = info && info.secret ? info.secret : '';
  const query = new URLSearchParams({
    hostname: host,
    host,
    port: String(port),
    secret,
  }).toString();
  return `${proto}://${host}:${port}/ui/${ui}/?${query}`;
}

// Resolve the mihomo web-UI address on demand and open it. Kept off the render
// path so the card paints instantly without any RPC round-trip.
async function openDashboard(ev?: Event): Promise<void> {
  if (ev) ev.preventDefault();
  try {
    const info = await dashboardInfo();
    const url = buildDashboardUrl(info);
    setTimeout(() => window.open(url, '_blank', 'noopener'), 0);
  } catch (e) {
    if (typeof ui !== 'undefined' && ui.addNotification)
      ui.addNotification(
        null,
        E('p', {}, _('Failed to resolve the dashboard address')),
        'danger',
      );
    if (typeof L !== 'undefined' && L.error) L.error(e);
  }
}

function paintStatus(running: boolean): void {
  const dot = document.getElementById(IDS.status);
  const text = document.getElementById(IDS.statusText);
  if (dot) {
    dot.className =
      '__PKG_NAME__-status-dot ' +
      (running
        ? '__PKG_NAME__-status-dot--up'
        : '__PKG_NAME__-status-dot--down');
  }
  if (text)
    text.textContent = running ? _('Service running') : _('Service stopped');
}

async function refreshStatus(): Promise<void> {
  if (!document.getElementById(IDS.status)) return;
  let running = false;
  try {
    running = await serviceStatus();
  } catch {
    running = false;
  }
  paintStatus(running);
}

function render(): Node {
  const brand = brandInfo();

  return E('div', { class: '__PKG_NAME__-card', id: IDS.root }, [
    E('div', { class: '__PKG_NAME__-card__header' }, [
      E('span', { class: '__PKG_NAME__-card__badge' }, brand.name),
      E('h3', { class: '__PKG_NAME__-card__title' }, _('Dashboard')),
      E('span', { class: '__PKG_NAME__-card__version' }, VERSION),
    ]),
    E(
      'p',
      { class: '__PKG_NAME__-card__desc' },
      _(
        'Monitor proxies, traffic and connections in the mihomo web dashboard.',
      ),
    ),
    E('div', { class: '__PKG_NAME__-card__status' }, [
      E('span', {
        class: '__PKG_NAME__-status-dot',
        id: IDS.status,
      }),
      E('span', { id: IDS.statusText }, _('Checking service status…')),
    ]),
    E('div', { class: '__PKG_NAME__-card__actions' }, [
      E(
        'button',
        {
          type: 'button',
          class: 'btn cbi-button cbi-button-action __PKG_NAME__-btn--primary',
          click: openDashboard,
        },
        _('Open dashboard'),
      ),
      brand.docsUrl
        ? E(
            'a',
            {
              class: 'btn cbi-button',
              href: brand.docsUrl,
              target: '_blank',
              rel: 'noopener',
            },
            _('Documentation'),
          )
        : E('span'),
      brand.supportUrl
        ? E(
            'a',
            {
              class: 'btn cbi-button',
              href: brand.supportUrl,
              target: '_blank',
              rel: 'noopener',
            },
            _('Support'),
          )
        : E('span'),
    ]),
    // Reserved for future live widgets (traffic / connections / memory).
    // Hidden and empty in phase 1 — no streaming is started to render the card.
    E('div', {
      id: IDS.widgets,
      class: '__PKG_NAME__-widgets',
      style: 'display:none',
    }),
  ]);
}

function initController(): void {
  // Fire-and-forget: fill the status line, then poll it lightly.
  void refreshStatus();
  if (statusTimer === null) {
    statusTimer = setInterval(() => void refreshStatus(), 10000);
  }
}

function destroy(): void {
  if (statusTimer !== null) {
    clearInterval(statusTimer);
    statusTimer = null;
  }
}

export const DashboardTab = {
  styles,
  render,
  initController,
  destroy,
  openDashboard,
};
