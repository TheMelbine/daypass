// vitest global mocks for the LuCI runtime globals. Only the surface the unit
// tests touch is stubbed; RPC-backed modules are not exercised here.
/* eslint-disable @typescript-eslint/no-explicit-any */
const g = globalThis as any;

// gettext — identity.
g._ = (key: string) => key;

// Minimal LuCI namespace.
g.L = {
  resolveDefault: (p: any, d: any) => Promise.resolve(p).catch(() => d),
  error: () => undefined,
  raise: (t: string, m?: string) => {
    throw new Error(m || t);
  },
  dom: {},
  ui: {},
};

// Element factory — enough to build detached nodes in jsdom-less tests.
g.E = (tag: string, _attrs?: any, _children?: any) => ({ tag });

// UI notifications / modals — no-ops.
g.ui = {
  showModal: () => undefined,
  hideModal: () => undefined,
  addNotification: () => undefined,
};

// rpc.declare returns a stub caller so importing rpc-backed modules doesn't throw
// at module-eval time (the caller itself is not invoked by the unit tests).
g.rpc = {
  declare:
    () =>
    (..._args: any[]) =>
      Promise.resolve(undefined),
};

// uci / fs stubs.
g.uci = {
  load: () => Promise.resolve(''),
  sections: () => [],
  get: () => undefined,
  unload: () => undefined,
};
g.fs = {
  exec: () => Promise.resolve({ stdout: '', stderr: '', code: 0 }),
  read: () => Promise.resolve(''),
  read_direct: () => Promise.resolve(''),
  list: () => Promise.resolve([]),
};

// baseclass — passthrough extend.
g.baseclass = { extend: (props: any) => props };
