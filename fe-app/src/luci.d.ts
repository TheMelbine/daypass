// Ambient declarations for the LuCI runtime globals the bundle relies on.
// These are injected by LuCI's client module loader from the `'require ...'`
// directive prologue in main.ts; esbuild leaves the directives in place and the
// symbols resolve at runtime. DOM types come from the default TS DOM lib.

type HtmlTag = keyof HTMLElementTagNameMap;

// LuCI's E()/dom.create accept plain attributes, `style` as string|object, and
// function-valued keys that are wired as event listeners (e.g. `click`).
type LuCIAttributes = Record<string, unknown> | null;

type LuCIChildren = Node | string | (Node | string)[] | null | undefined;

declare global {
  // gettext
  const _: (key: string, ...args: unknown[]) => string;

  // Element factory (LuCI global E === L.dom.create).
  const E: {
    <K extends HtmlTag>(
      tag: K,
      attrs?: LuCIAttributes,
      children?: LuCIChildren,
    ): HTMLElementTagNameMap[K];
    (tag: string, attrs?: LuCIAttributes, children?: LuCIChildren): HTMLElement;
  };

  // LuCI namespace (only the members we touch).
  const L: {
    resolveDefault<T>(promise: Promise<T> | T, defaultValue?: T): Promise<T>;
    dom: typeof dom;
    ui: typeof ui;
    error(err: unknown): void;
    raise(type: string, message?: string): never;
  };

  const baseclass: {
    extend(props: Record<string, unknown>): unknown;
  };

  const dom: {
    create: typeof E;
    content(node: Node, children?: LuCIChildren): Node;
    append(node: Node, children?: LuCIChildren): Node;
    isEmpty(node: Node): boolean;
  };

  const ui: {
    showModal(
      title: string | null,
      contents: LuCIChildren,
      ...args: unknown[]
    ): Node;
    hideModal(): void;
    addNotification(
      title: string | null,
      contents: LuCIChildren,
      className?: string,
    ): Node;
  };

  const uci: {
    load(pkg: string | string[]): Promise<string | string[]>;
    sections<T = Record<string, unknown>>(
      conf: string,
      type?: string,
      cb?: (section: T, name: string) => void,
    ): T[];
    get(conf: string, sid: string, opt?: string): unknown;
    unload(pkg: string | string[]): void;
  };

  const fs: {
    exec(
      command: string,
      args?: string[],
      env?: Record<string, string>,
    ): Promise<{ stdout: string; stderr: string; code?: number }>;
    read(path: string): Promise<string>;
    read_direct(path: string): Promise<string>;
    list(path: string): Promise<Array<{ name: string; type: string }>>;
  };

  const rpc: {
    declare<T = unknown>(options: {
      object: string;
      method: string;
      params?: string[];
      expect?: Record<string, unknown>;
      reject?: boolean;
      filter?: (data: unknown, args: unknown[]) => T;
    }): (...args: unknown[]) => Promise<T>;
  };

  const poll: {
    add(fn: () => Promise<unknown> | unknown, interval?: number): void;
    remove(fn: () => Promise<unknown> | unknown): boolean;
    start(): void;
    stop(): void;
  };
}

export {};
