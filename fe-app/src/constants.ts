// Brand + fixed-runtime constants. The __TOKEN__ literals are substituted by the
// luci-app Makefile's Brand/Subst pass at install time (one committed bundle
// serves every brand). __COMPILED_VERSION_VARIABLE__ is injected by CI at build.
// Keep every token as a bare string literal so sed can find it.

export const VERSION = '__COMPILED_VERSION_VARIABLE__';
export const PKG = '__PKG_NAME__';
export const BRAND = '__BRAND_NAME__';
export const ACCENT = '__ACCENT__';
export const SUPPORT_URL = '__SUPPORT_URL__';
export const DOCS_URL = '__DOCS_URL__';
export const DASHBOARD = '__DASHBOARD__';

// Fixed runtime constants (identical across brands — see docs/CONTRACT.md).
export const API_PORT = 9090; // mihomo external-controller (127.0.0.1)
export const TPROXY_PORT = 7894; // mihomo tproxy listener
export const FAKEIP_RANGE = '198.18.0.0/16';

// --- UCI option catalogs (config settings 'settings') --------------------

// dns_type
export const DNS_TYPE_OPTIONS: Record<string, string> = {
  udp: 'UDP (plain 53)',
  doh: 'DNS over HTTPS',
  dot: 'DNS over TLS',
};

// dns_server
export const DNS_SERVER_OPTIONS: Record<string, string> = {
  '1.1.1.1': '1.1.1.1 (Cloudflare)',
  '8.8.8.8': '8.8.8.8 (Google)',
  '9.9.9.9': '9.9.9.9 (Quad9)',
  'dns.adguard-dns.com': 'dns.adguard-dns.com (AdGuard Default)',
  'unfiltered.adguard-dns.com':
    'unfiltered.adguard-dns.com (AdGuard Unfiltered)',
  'family.adguard-dns.com': 'family.adguard-dns.com (AdGuard Family)',
};

// bootstrap_dns_server (plain-IP resolver used to reach a DoH/DoT endpoint)
export const BOOTSTRAP_DNS_SERVER_OPTIONS: Record<string, string> = {
  '1.1.1.1': '1.1.1.1 (Cloudflare)',
  '1.0.0.1': '1.0.0.1 (Cloudflare)',
  '8.8.8.8': '8.8.8.8 (Google)',
  '8.8.4.4': '8.8.4.4 (Google)',
  '9.9.9.9': '9.9.9.9 (Quad9)',
  '77.88.8.8': '77.88.8.8 (Yandex)',
};

// update_interval (subnet/domain list refresh cadence)
export const UPDATE_INTERVAL_OPTIONS: Record<string, string> = {
  '1h': 'Every hour',
  '3h': 'Every 3 hours',
  '12h': 'Every 12 hours',
  '1d': 'Every day',
  '3d': 'Every 3 days',
};

// config proxy '<name>' — outbound group `type`
export const PROXY_TYPE_OPTIONS: Record<string, string> = {
  url: 'Single URL',
  selector: 'Selector (manual choice)',
  urltest: 'URL test (auto-fastest)',
  raw: 'Raw outbound JSON',
};
