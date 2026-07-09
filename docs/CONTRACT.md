# daypass — build contract (single source of truth)

This file pins the cross-package conventions. Everything under `packages/`,
`fe-app/`, `docker/`, `scripts/`, `tests/` must agree with it. When something
here changes, change it here first.

## What daypass is

A brandable OpenWrt package set that runs **mihomo** (Clash.Meta core) as a
**selective transparent proxy** using an **external nftables TPROXY** layer.
No TUN, no redirect. Only traffic we deliberately select ever reaches mihomo;
everything else is routed directly by the kernel with zero overhead.

Data path:

1. mihomo DNS runs in `fake-ip` mode with `fake-ip-filter-mode: whitelist`.
   Only domains present in the enabled rule-sets get a fake-ip answer
   (`198.18.0.0/16`); every other name resolves to its real IP.
2. dnsmasq is repointed at mihomo's DNS (`server=127.0.0.42`, `noresolv`,
   `cachesize 0`) so client lookups flow through it.
3. nftables marks packets whose destination is in the fake-ip range **or** in a
   subnet set (`subnets4`), then TPROXY-redirects them to mihomo's tproxy
   listener. Unmarked traffic is never touched.
4. mihomo carries `routing-mark` on its own sockets; the nft `output` chain
   returns early on that mark, so mihomo's upstream/DNS/list-download traffic
   never loops back into itself.
5. Because nft already filtered, mihomo's own rule list can be trivial
   (`RULE-SET,<tag>,<group>` lines for multi-proxy setups, then `MATCH,<group>`).

## Branding

Two layers:

- **Build-time tokens** — replaced by `sed` over the install staging tree in
  each package Makefile (`Brand/Subst` macro). Tokens use `__UPPER__` form so
  they cannot collide with sh / ucode / JS / JSON syntax:
  - `__PKG_NAME__`   — lowercase `[a-z0-9]+`, no dash (nft/ cgroup identifier
    safe). Becomes the package name and **every** runtime path & identifier.
  - `__BRAND_NAME__` — human display name (e.g. `Daypass`).
  - `__PKG_VERSION__`
  - `__BRAND_URL__`, `__SUPPORT_URL__`, `__DOCS_URL__`
  - `__LISTS_BASE__` — base URL for community list assets.
  - `__ACCENT__` — UI accent color.
- **Runtime brand include** — a generated file each language sources once, so
  code never repeats a token:
  - shell/ucode: `/usr/lib/__PKG_NAME__/brand.sh` (POSIX sh, `KEY=value`).
  - fe-app: `src/brand.ts` (tokens as string literals, resolved at package
    build; kept literal so one committed `main.js` serves every brand).

The **package name itself is brand-driven**: `PKG_NAME := $(BRAND_PKG)`.
Source filenames stay neutral (`files/init`, `menu.d/luci-app.json`); Makefiles
rename them to brand paths at install (`/etc/init.d/$(BRAND_PKG)`,
`menu.d/luci-app-$(BRAND_PKG).json`, `view/app/` → `view/$(BRAND_PKG)/`).
Filenames cannot be `sed`-ed — they are renamed by the `$(INSTALL_*)` target.

Brands `CONFLICTS` each other on-device (both would hijack DNS/nft).

## Fixed runtime constants (identical across brands)

| name | value | notes |
|---|---|---|
| tproxy mark | `0x00100000` (mask `0x00100000`) | packet destined for mihomo |
| bypass mark | `0x00200000` | mihomo `routing-mark`; nft output returns on it. Decimal `2097152` in the mihomo config |
| rt table id | `105` | name = `__PKG_NAME__` in `/etc/iproute2/rt_tables` |
| rt rule pref | `105` | |
| tproxy port | `7894` | mihomo tproxy listener |
| api port | `9090` | mihomo external-controller (127.0.0.1) |
| dns listen | `127.0.0.42:53` | mihomo dns; dnsmasq `server=127.0.0.42` |
| fake-ip range | `198.18.0.0/16` | mihomo `198.18.0.1/16`; nft daddr `198.18.0.0/16` |
| nft table | `inet __PKG_NAME__` | |
| home dir | `/etc/__PKG_NAME__` | mihomo `-d`; holds generated `config.yaml` + cache |
| providers dir | `/etc/__PKG_NAME__/providers` | persistent mrs cache (relative `providers/…` in config); in keep.d |
| ui dir | `/usr/share/__PKG_NAME__/ui` | bundled clash dashboards |
| log | `/var/log/__PKG_NAME__/core.log` | mihomo stdout/stderr |

IPv4-only in v1 (mihomo `ipv6: false`, no v6 nft rules). Marks live in high bits
to avoid fw4/mwan3 mask collisions.

## nftables topology (`table inet __PKG_NAME__`)

Sets: `localv4` (reserved/bogon ipv4, interval+auto-merge), `subnets4`
(proxied subnets, filled by list-update), `lan_ifaces` (ifname, from
`source_network_interfaces`).

Chains:
- `mangle` — `type filter hook prerouting priority -150`. `ct status dnat
  return`; then for `iifname @lan_ifaces` and `ip daddr @subnets4` **or** `ip
  daddr 198.18.0.0/16`, `meta mark set 0x00100000` (tcp & udp).
- `mangle_output` — `type route hook output priority -150`. First rule
  `meta mark & 0x00200000 == 0x00200000 return` (mihomo loop guard), then
  `ip daddr @localv4 return`, `ct status dnat return`, then the same mark-set
  rules without the `iifname` match (router-self traffic).
- `divert` — `type filter hook prerouting priority -100`.
  `meta mark & 0x00100000 == 0x00100000 meta l4proto tcp|udp tproxy ip to
  127.0.0.1:7894`.

Policy routing (installed by init, torn down on stop):
`ip rule add fwmark 0x00100000/0x00100000 table 105 priority 105`,
`ip route add local 0.0.0.0/0 dev lo table 105`.

The tproxy port comes from the shared constants used by BOTH the nft template
and the config generator — never hardcode it in only one place.

### ucode invocation & validation notes (verified against real mihomo/nft)

- `generate.uc` is a **raw** ucode script (no `{%- -%}` markers): `ucode -S generate.uc`.
- `nft.ut` is a **template**: `ucode -T nft.ut | nft -f -`.
- ucode modules export with the list form `export { a, b }` (no trailing comma) —
  works on both old and new ucode; `export function`/`export const` inline is
  rejected by older builds.
- mihomo's path-safety guard rejects `external-ui` outside its home dir. The
  procd service passes `SAFE_PATHS=/usr/share/__PKG_NAME__/ui` so the bundled
  dashboard loads. Provider `path:` values are **relative** (`providers/…`), so
  they stay under home and need no SAFE_PATHS.
- Validated: outbound.uc parses vless/ss/trojan/hysteria2/socks correctly;
  generate.uc output passes `mihomo -t`; nft.ut renders and applies on a live
  kernel (tproxy + `type route` output chain).

## CLI — `/usr/bin/__PKG_NAME__`

`generate` (UCI → `run/config.yaml`), `fw_start` / `fw_stop` (render/flush
nft + ip rule/route), `list_update` (subnet .lst → `subnets4`), `dns_takeover`
/ `dns_restore` (dnsmasq), `status`, `check` (validate config), `lists [--json]`
(community-list catalog), `selftest`. The procd init calls these; never
duplicate logic between init and CLI.

## procd init — `/etc/init.d/__PKG_NAME__`

`USE_PROCD=1`, `START=99`. The procd instance **is** mihomo
(`command mihomo -d <run_dir>`). `service_started()` does `generate` →
`dns_takeover` → policy routing → `fw_start`. `service_stopped()` does
`fw_stop` → policy-routing teardown → `dns_restore`. `reload`/config-change
re-renders. `procd_set_param file run/config.yaml` for restart-on-change.

## rpcd ubus object — `luci.__PKG_NAME__`

Methods (all through the rpcd ucode plugin, no blanket file-exec ACL):
- `version()` → `{app, core}`
- `lists()` → community-list catalog (shells `__PKG_NAME__ lists --json`)
- `diag(check)` → whitelisted check runner (`config|dns|proxy|nft`)
- `logs(lines)` → tail of mihomo log
- `api(method, path, query, body)` → curl proxy to mihomo REST with
  `--oauth2-bearer <secret>` (secret stays server-side)
- `dashboard_info()` → `{https, port, ui_name, secret}` for the client to build
  the external dashboard URL.

Service control uses ubus `rc.init` / `rc.list` (start/stop/restart/status).

## UCI schema — config `__PKG_NAME__`

- `config __PKG_NAME__ 'main'` — `enabled`, `log_level`, `api_secret`,
  `dashboard` (`zashboard|metacubexd`).
- `config settings 'settings'` — `dns_type` (udp|doh|dot), `dns_server`,
  `bootstrap_dns_server`, `source_network_interfaces` (list), `update_interval`
  (1h|3h|12h|1d|3d), `disable_quic`, `dont_touch_dhcp`, `shutdown_correctly`
  (state flag).
- `config proxy '<name>'` — one outbound (group). `type` (url|selector|urltest|
  raw), `proxy_string` (single URL) / `links` (list, for selector/urltest) /
  `outbound_json` (raw), `enabled`.
- `config route '<name>'` — one routing bucket. `proxy` (ref to a proxy
  section), `community_lists` (list of tags), `remote_domain_mrs` (list of
  URLs), `remote_subnet_lst` (list), `user_domains` (list), `user_subnets`
  (list), `enabled`.

## Proxy-URL parser (`ucode/outbound.uc`)

`parse_proxy_url(url, name) → mihomo proxy object`. Schemes: `vless` (tls /
reality / ws / grpc / http), `ss`/`shadowsocks` (base64 userinfo via ucode
`b64dec`, plugin passthrough), `trojan` (tls + ws/grpc), `hysteria2`/`hy2`
(port hopping `ports`, `obfs` salamander), `socks`/`socks5`. Split the URL
structurally (scheme/userinfo/host/port/query/fragment) **before**
percent-decoding each component; never translate `+`→space in userinfo; the
`#fragment` becomes the proxy display name. Emit mihomo key names
(`servername`, `reality-opts`, `ws-opts`, `grpc-opts`, `client-fingerprint`).

## mihomo config shape (emitted by `ucode/generate.uc` as JSON == YAML)

Top: `mode: rule`, `ipv6: false`, `find-process-mode: off`,
`routing-mark: 2097152`, `log-level`. `listeners: [{name, type: tproxy, port:
7894, listen: 0.0.0.0, udp: true}]`. `tun: {enable: false}`.
`external-controller: 127.0.0.1:9090`, `secret`, `external-ui`,
`profile: {store-selected: true, store-fake-ip: true}`. `dns:` fake-ip
whitelist with `fake-ip-filter: [rule-set:<tag>...]`, `nameserver`,
`proxy-server-nameserver`. `sniffer:` HTTP/TLS/QUIC. `proxies:` from parser.
`proxy-groups:` one per proxy section. `rule-providers:` mrs domain per enabled
domain list. `rules:` `RULE-SET,<tag>,<group>` … then `MATCH,<default group>`.
