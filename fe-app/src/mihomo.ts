// Thin typed client for mihomo's REST/clash API. All one-shot calls go through
// the rpcd `api` proxy (luci.__PKG_NAME__ api) so the bearer secret never leaves
// the router. wsStream() is a phase-1 stub reserved for future live streaming
// (/traffic, /logs, /connections) built from dashboard_info() credentials.

import { api, dashboardInfo, DashboardInfo } from './rpc';
import { API_PORT } from './constants';

// --- mihomo REST types (subset we care about) -----------------------------

export interface MihomoTraffic {
  up: number;
  down: number;
}

export interface MihomoConnectionsSnapshot {
  downloadTotal: number;
  uploadTotal: number;
  connections: unknown[];
  memory: number;
}

export interface MihomoProxyHistory {
  time: string;
  delay: number;
}

export interface MihomoProxy {
  type: string;
  name: string;
  udp?: boolean;
  now?: string;
  all?: string[];
  history: MihomoProxyHistory[];
}

export interface MihomoProxies {
  proxies: Record<string, MihomoProxy>;
}

export interface MihomoVersion {
  version: string;
  meta?: boolean;
}

// --- one-shot REST via the rpcd proxy -------------------------------------

export interface RpcApiOptions {
  query?: Record<string, string>;
  body?: unknown;
}

// rpcApi('GET', '/proxies') -> parsed JSON. query is encoded to a query string;
// body is JSON-stringified. The rpcd side attaches --oauth2-bearer <secret>.
export async function rpcApi<T = unknown>(
  method: string,
  path: string,
  opts: RpcApiOptions = {},
): Promise<T> {
  const query = opts.query ? new URLSearchParams(opts.query).toString() : '';
  const body = opts.body != null ? JSON.stringify(opts.body) : '';
  const res = await api(method, path, query, body);
  return res as T;
}

export function getProxies(): Promise<MihomoProxies> {
  return rpcApi<MihomoProxies>('GET', '/proxies');
}

export function getMihomoVersion(): Promise<MihomoVersion> {
  return rpcApi<MihomoVersion>('GET', '/version');
}

// Switch a selector group to a named outbound.
export function selectProxy(group: string, name: string): Promise<unknown> {
  return rpcApi('PUT', `/proxies/${encodeURIComponent(group)}`, {
    body: { name },
  });
}

// --- live streaming (phase-1 stub) ----------------------------------------

export interface WsStreamHandle {
  close(): void;
}

export type WsEndpoint =
  | '/traffic'
  | '/logs'
  | '/connections'
  | '/memory'
  | string;

function wsBase(info: DashboardInfo): string {
  const proto = info && info.https ? 'wss' : 'ws';
  const host =
    typeof window !== 'undefined' && window.location
      ? window.location.hostname
      : '127.0.0.1';
  const port = (info && info.port) || API_PORT;
  return `${proto}://${host}:${port}`;
}

// Reserved for future dashboards. Opens a mihomo websocket stream, forwarding
// parsed JSON frames to onMessage. Degrades to a no-op handle where WebSocket
// is unavailable (e.g. under vitest). Kept intentionally minimal for phase 1.
export async function wsStream(
  endpoint: WsEndpoint,
  onMessage: (data: unknown) => void,
  onError?: (err: unknown) => void,
): Promise<WsStreamHandle> {
  const noop: WsStreamHandle = { close() {} };
  if (typeof WebSocket === 'undefined') return noop;

  try {
    const info = await dashboardInfo();
    const secret = (info && info.secret) || '';
    const url = `${wsBase(info)}${endpoint}?token=${encodeURIComponent(secret)}`;
    const sock = new WebSocket(url);

    sock.onmessage = (ev: MessageEvent) => {
      try {
        onMessage(JSON.parse(String(ev.data)));
      } catch (e) {
        if (onError) onError(e);
      }
    };
    sock.onerror = (ev: Event) => {
      if (onError) onError(ev);
    };

    return {
      close() {
        try {
          sock.close();
        } catch {
          /* ignore */
        }
      },
    };
  } catch (e) {
    if (onError) onError(e);
    return noop;
  }
}
