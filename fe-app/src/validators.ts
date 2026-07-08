// Client-side proxy share-link validation. These mirror the schemes the CORE
// parser accepts (packages/daypass/files/ucode/outbound.uc):
//   vless://  ss:// (shadowsocks://)  trojan://  hysteria2:// | hy2://  socks:// | socks5://
// The goal is a fast, structural sanity check before the URL is handed to the
// ucode parser server-side — not a full re-implementation of it.

export interface ProxyValidationResult {
  valid: boolean;
  error?: string;
  scheme?: string;
}

const PORT_MIN = 1;
const PORT_MAX = 65535;

function ok(scheme: string): ProxyValidationResult {
  return { valid: true, scheme };
}

function fail(
  scheme: string | undefined,
  error: string,
): ProxyValidationResult {
  return scheme ? { valid: false, scheme, error } : { valid: false, error };
}

function isValidPort(value: string): boolean {
  if (!/^\d+$/.test(value)) return false;
  const n = Number(value);
  return n >= PORT_MIN && n <= PORT_MAX;
}

// hysteria2 port hopping: "443", "20000-50000", or "443,8443,20000-30000".
function isValidPortSpec(value: string): boolean {
  const entries = value.split(',');
  if (entries.length === 0) return false;
  return entries.every((entry) => {
    if (!entry) return false;
    if (entry.indexOf('-') < 0) return isValidPort(entry);
    const parts = entry.split('-');
    if (parts.length !== 2) return false;
    if (!isValidPort(parts[0]) || !isValidPort(parts[1])) return false;
    return Number(parts[0]) <= Number(parts[1]);
  });
}

// Split a trailing "host:port" authority (IPv4/host only — v1 is IPv4-only).
function parseHostPort(hostPort: string): { host: string; port: string } {
  const clean = hostPort.replace(/\/+$/, '');
  const idx = clean.lastIndexOf(':');
  if (idx < 0) return { host: clean, port: '' };
  return { host: clean.slice(0, idx), port: clean.slice(idx + 1) };
}

function safeDecode(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function parseQuery(query: string): Record<string, string> {
  const out: Record<string, string> = {};
  if (!query) return out;
  for (const pair of query.split('&')) {
    if (!pair) continue;
    const eq = pair.indexOf('=');
    const key = eq < 0 ? pair : pair.slice(0, eq);
    const value = eq < 0 ? '' : pair.slice(eq + 1);
    if (key) out[safeDecode(key)] = safeDecode(value);
  }
  return out;
}

export function validateVlessUrl(url: string): ProxyValidationResult {
  const scheme = 'vless';
  if (!url.startsWith('vless://'))
    return fail(scheme, _('VLESS URL must start with vless://'));
  if (/\s/.test(url))
    return fail(scheme, _('VLESS URL must not contain whitespace'));

  const [userHostPort] = url.slice('vless://'.length).split('#')[0].split('?');
  const at = userHostPort.lastIndexOf('@');
  if (at < 0)
    return fail(scheme, _('VLESS URL is missing the UUID@server separator'));

  const uuid = userHostPort.slice(0, at);
  if (!uuid) return fail(scheme, _('VLESS URL is missing the UUID'));

  const { host, port } = parseHostPort(userHostPort.slice(at + 1));
  if (!host) return fail(scheme, _('VLESS URL is missing the server host'));
  if (!port) return fail(scheme, _('VLESS URL is missing the port'));
  if (!isValidPort(port))
    return fail(scheme, _('VLESS URL has an invalid port'));

  return ok(scheme);
}

export function validateShadowsocksUrl(url: string): ProxyValidationResult {
  const scheme = 'ss';
  const prefix = url.startsWith('shadowsocks://')
    ? 'shadowsocks://'
    : url.startsWith('ss://')
      ? 'ss://'
      : '';
  if (!prefix) return fail(scheme, _('Shadowsocks URL must start with ss://'));
  if (/\s/.test(url))
    return fail(scheme, _('Shadowsocks URL must not contain whitespace'));

  const body = url.slice(prefix.length).split('#')[0].split('?')[0];
  const at = body.lastIndexOf('@');
  if (at < 0)
    return fail(
      scheme,
      _('Shadowsocks URL is missing the credentials@server separator'),
    );

  const userinfo = body.slice(0, at);
  if (!userinfo)
    return fail(scheme, _('Shadowsocks URL is missing the credentials'));

  const { host, port } = parseHostPort(body.slice(at + 1));
  if (!host)
    return fail(scheme, _('Shadowsocks URL is missing the server host'));
  if (!port) return fail(scheme, _('Shadowsocks URL is missing the port'));
  if (!isValidPort(port))
    return fail(scheme, _('Shadowsocks URL has an invalid port'));

  return ok(scheme);
}

export function validateTrojanUrl(url: string): ProxyValidationResult {
  const scheme = 'trojan';
  if (!url.startsWith('trojan://'))
    return fail(scheme, _('Trojan URL must start with trojan://'));
  if (/\s/.test(url))
    return fail(scheme, _('Trojan URL must not contain whitespace'));

  const [userHostPort] = url.slice('trojan://'.length).split('#')[0].split('?');
  const at = userHostPort.lastIndexOf('@');
  if (at < 0)
    return fail(
      scheme,
      _('Trojan URL is missing the password@server separator'),
    );

  const password = userHostPort.slice(0, at);
  if (!password) return fail(scheme, _('Trojan URL is missing the password'));

  const { host, port } = parseHostPort(userHostPort.slice(at + 1));
  if (!host) return fail(scheme, _('Trojan URL is missing the server host'));
  if (!port) return fail(scheme, _('Trojan URL is missing the port'));
  if (!isValidPort(port))
    return fail(scheme, _('Trojan URL has an invalid port'));

  return ok(scheme);
}

export function validateHysteria2Url(url: string): ProxyValidationResult {
  const scheme = 'hysteria2';
  const isLong = url.startsWith('hysteria2://');
  const isShort = url.startsWith('hy2://');
  if (!isLong && !isShort)
    return fail(
      scheme,
      _('Hysteria2 URL must start with hysteria2:// or hy2://'),
    );
  if (/\s/.test(url))
    return fail(scheme, _('Hysteria2 URL must not contain whitespace'));

  const prefix = isLong ? 'hysteria2://' : 'hy2://';
  const [main, queryString] = url.slice(prefix.length).split('#')[0].split('?');
  const at = main.lastIndexOf('@');
  if (at < 0)
    return fail(
      scheme,
      _('Hysteria2 URL is missing the password@server separator'),
    );

  const password = main.slice(0, at);
  if (!password)
    return fail(scheme, _('Hysteria2 URL is missing the password'));

  const { host, port } = parseHostPort(main.slice(at + 1));
  if (!host) return fail(scheme, _('Hysteria2 URL is missing the server host'));

  const params = parseQuery(queryString);
  const portSpec = params.mport || port;
  if (!portSpec) return fail(scheme, _('Hysteria2 URL is missing the port'));
  if (!isValidPortSpec(portSpec))
    return fail(scheme, _('Hysteria2 URL has an invalid port'));

  if (params.obfs && params.obfs !== 'none' && params.obfs !== 'salamander')
    return fail(scheme, _('Hysteria2 URL has an unsupported obfs type'));

  return ok(scheme);
}

export function validateSocksUrl(url: string): ProxyValidationResult {
  const scheme = 'socks';
  if (!/^socks5?:\/\//.test(url))
    return fail(scheme, _('SOCKS URL must start with socks:// or socks5://'));
  if (/\s/.test(url))
    return fail(scheme, _('SOCKS URL must not contain whitespace'));

  const body = url
    .replace(/^socks5?:\/\//, '')
    .split('#')[0]
    .split('?')[0];
  const at = body.lastIndexOf('@');
  if (at >= 0) {
    const username = body.slice(0, at).split(':')[0];
    if (!username) return fail(scheme, _('SOCKS URL is missing the username'));
  }

  const { host, port } = parseHostPort(at >= 0 ? body.slice(at + 1) : body);
  if (!host) return fail(scheme, _('SOCKS URL is missing the server host'));
  if (!port) return fail(scheme, _('SOCKS URL is missing the port'));
  if (!isValidPort(port))
    return fail(scheme, _('SOCKS URL has an invalid port'));

  return ok(scheme);
}

// Dispatch on scheme. Mirrors CORE parse_proxy_url()'s switch.
export function validateProxyUrl(url: string): ProxyValidationResult {
  const trimmed = (url || '').trim();
  if (trimmed === '') return fail(undefined, _('Proxy URL is empty'));

  if (trimmed.startsWith('vless://')) return validateVlessUrl(trimmed);
  if (trimmed.startsWith('ss://') || trimmed.startsWith('shadowsocks://'))
    return validateShadowsocksUrl(trimmed);
  if (trimmed.startsWith('trojan://')) return validateTrojanUrl(trimmed);
  if (trimmed.startsWith('hysteria2://') || trimmed.startsWith('hy2://'))
    return validateHysteria2Url(trimmed);
  if (/^socks5?:\/\//.test(trimmed)) return validateSocksUrl(trimmed);

  return fail(
    undefined,
    _(
      'Proxy URL must start with vless://, ss://, trojan://, hysteria2://, hy2:// or socks://',
    ),
  );
}
