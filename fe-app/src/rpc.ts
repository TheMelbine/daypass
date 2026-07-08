// rpc.declare wrappers for the rpcd ubus object luci.__PKG_NAME__ and the
// generic `rc` service-control object. The __PKG_NAME__ token inside the object
// name and the service name is substituted at install time.

export interface VersionInfo {
  app: string;
  core: string;
}

export interface DashboardInfo {
  https: boolean;
  port: number;
  ui_name: string;
  secret: string;
}

// --- luci.__PKG_NAME__ ----------------------------------------------------

const callVersion = rpc.declare<VersionInfo>({
  object: 'luci.__PKG_NAME__',
  method: 'version',
  expect: { '': {} },
});

const callLists = rpc.declare<unknown>({
  object: 'luci.__PKG_NAME__',
  method: 'lists',
  expect: { '': {} },
});

const callDiag = rpc.declare<{ result?: string }>({
  object: 'luci.__PKG_NAME__',
  method: 'diag',
  params: ['check'],
  expect: { '': {} },
});

const callLogs = rpc.declare<{ result?: string }>({
  object: 'luci.__PKG_NAME__',
  method: 'logs',
  params: ['lines'],
  expect: { '': {} },
});

const callApi = rpc.declare<unknown>({
  object: 'luci.__PKG_NAME__',
  method: 'api',
  params: ['method', 'path', 'query', 'body'],
  expect: { '': {} },
});

const callDashboardInfo = rpc.declare<DashboardInfo>({
  object: 'luci.__PKG_NAME__',
  method: 'dashboard_info',
  expect: { '': {} },
});

// --- rc (service control) -------------------------------------------------

const callRcList = rpc.declare<
  Record<string, { running?: boolean; enabled?: boolean }>
>({
  object: 'rc',
  method: 'list',
  params: ['name'],
  expect: { '': {} },
});

const callRcInit = rpc.declare<unknown>({
  object: 'rc',
  method: 'init',
  params: ['name', 'action'],
  expect: { '': {} },
});

// --- thin, named exports --------------------------------------------------

export function version(): Promise<VersionInfo> {
  return callVersion();
}

export function lists(): Promise<unknown> {
  return callLists();
}

export function diag(
  check: 'config' | 'dns' | 'proxy' | 'nft',
): Promise<{ result?: string }> {
  return callDiag(check);
}

export function logs(lines?: number): Promise<{ result?: string }> {
  return callLogs(lines);
}

export function api(
  method: string,
  path: string,
  query?: string,
  body?: string,
): Promise<unknown> {
  return callApi(method, path, query, body);
}

export function dashboardInfo(): Promise<DashboardInfo> {
  return callDashboardInfo();
}

// Service state via `rc list <pkg>` -> { <pkg>: { running, enabled } }.
export async function serviceStatus(): Promise<boolean> {
  const list = await callRcList('__PKG_NAME__');
  return Boolean(list && list['__PKG_NAME__'] && list['__PKG_NAME__'].running);
}

export function serviceAction(
  action: 'start' | 'stop' | 'restart' | 'reload' | 'enable' | 'disable',
): Promise<unknown> {
  return callRcInit('__PKG_NAME__', action);
}
