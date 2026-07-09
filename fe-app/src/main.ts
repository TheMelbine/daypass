'use strict';
'require baseclass';
'require dom';
'require ui';
'require rpc';
'require uci';
'require fs';

// LuCI runs on browsers that predate structuredClone; keep a tiny shim so shared
// helpers can rely on it.
if (typeof structuredClone !== 'function')
  globalThis.structuredClone = (obj: unknown) =>
    JSON.parse(JSON.stringify(obj));

// The bundle is consumed by luci-app view wrappers as
//   'require view.__PKG_NAME__.main as main'
// tsup emits a trailing `export { ... }` which onSuccess rewrites into
// `return baseclass.extend({ ... })`. NO default export.
export * from './constants';
export * from './brand';
export * from './validators';
export * from './rpc';
export * from './mihomo';
export * from './dashboard';
