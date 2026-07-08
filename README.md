# daypass

Selective transparent proxy for OpenWrt, built on the **mihomo** (Clash.Meta)
core with an **external nftables TPROXY** layer. A spiritual alternative to
[podkop](https://github.com/itdoginfo/podkop), but mihomo-only and TPROXY-only.

Only traffic you deliberately select (by domain list or subnet) is routed
through the proxy; everything else is routed directly by the kernel with zero
overhead — mihomo never even sees it.

## Why mihomo + TPROXY (and no TUN)

- mihomo's `fake-ip-filter-mode: whitelist` hands out fake-ip answers **only**
  for whitelisted domains, so the external nft layer marks and TPROXY-redirects
  exactly the selected flows. Same selective-routing behaviour as podkop, but
  the DNS whitelist and list auto-refresh come from the core itself.
- TPROXY (not TUN) keeps unselected traffic entirely off the Go process, which
  matters on routers with limited RAM.
- mihomo brings a REST API + dashboards (zashboard / metacubexd) and
  proxy-groups with url-test / fallback for free.

See [`docs/CONTRACT.md`](docs/CONTRACT.md) for the exact data path, nft
topology, marks, ports, UCI schema, and mihomo config shape.

## Branding

The package name and every runtime path, identifier and user-visible string are
build-time parameters, so the project can be rebuilt under a different name
without touching source:

```
make apk BRAND=daypass          # default
make apk BRAND=<name>           # a <name>.mk supplied via BRAND_DIR
```

`branding/daypass.mk` holds the default values; `branding/brand.mk` does the
substitution. Only `daypass` ships in this tree — other brands are supplied
out-of-tree by pointing `BRAND_DIR` at a separate overlay. The package **name
itself** is brand-driven (`/etc/config/<brand>`, `/etc/init.d/<brand>`, nft
table `<brand>`, LuCI menu `<brand>`). See
[`docs/CONTRACT.md`](docs/CONTRACT.md#branding).

## Layout

```
branding/          brand definitions + Brand/Subst make macro + logos
packages/daypass/  OpenWrt package: mihomo + nft TPROXY, ucode config generator
packages/luci-app-daypass/LuCI web UI (standard form.Map pages) + rpcd plugin
fe-app/            TypeScript/tsup source for the LuCI bundle (committed main.js)
docker/            SDK images + build Dockerfiles (apk 25.12, ipk 24.10)
scripts/           build.sh (docker wrapper) + verify-pkg.sh (artifact checks)
tests/             smoke suite (shipped in-package as `<brand> selftest`) + QEMU
docs/CONTRACT.md   the single source of truth for all cross-package conventions
```

## Status

Early scaffold. The core generator, nft template and proxy-URL parser are the
substance; the LuCI forms and fe-app dashboard grow from a working skeleton.
