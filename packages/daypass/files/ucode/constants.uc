// /usr/share/__PKG_NAME__/ucode/constants.uc — shared constants (module).
// Imported by generate.uc and nft.ut. Brand tokens are substituted at install;
// the rest mirrors lib/env.sh and docs/CONTRACT.md.
'use strict';

// Declared plainly, exported as a list at the bottom (the `export { ... }` form
// works on every ucode version; `export const` is rejected by older builds).
const PKG_NAME   = '__PKG_NAME__';
const BRAND_NAME = '__BRAND_NAME__';
const VERSION    = '__PKG_VERSION__';
const LISTS_BASE = '__LISTS_BASE__';

const HOME_DIR      = '/etc/__PKG_NAME__';
const PROVIDERS_REL = 'providers';            // relative to mihomo -d home
const UI_DIR        = '/usr/share/__PKG_NAME__/ui';

const TPROXY_PORT = 7894;
const API_ADDR    = '127.0.0.1';
const API_PORT    = 9090;
const DNS_ADDR    = '127.0.0.42';
const DNS_PORT    = 53;
const FAKEIP_CIDR = '198.18.0.1/16';          // mihomo form
const FAKEIP_NFT  = '198.18.0.0/16';          // nft form

// mihomo routing-mark (decimal) == BYPASS_MARK 0x00200000 in the nft layer.
const ROUTING_MARK = 2097152;

// nft
const NFT_TABLE      = '__PKG_NAME__';
const NFT_SUBNET_SET = 'subnets4';
const NFT_LOCAL_SET  = 'localv4';
const NFT_IFACE_SET  = 'lan_ifaces';
// per-device full tunnel: every packet from these sources is proxied
const NFT_FORCE_SET     = 'force4';       // by IPv4 source
const NFT_FORCE_MAC_SET = 'force_mac';    // by MAC source (DHCP-proof)
const TPROXY_MARK_HEX = '0x00100000';
const TPROXY_MASK_HEX = '0x00100000';
const BYPASS_MARK_HEX = '0x00200000';
const BYPASS_MASK_HEX = '0x00200000';
const RT_TABLE_ID = 105;
const RT_RULE_PREF = 105;

// reserved / bogon IPv4 that must never be proxied
const LOCALV4 = [
	'0.0.0.0/8', '10.0.0.0/8', '127.0.0.0/8', '169.254.0.0/16',
	'172.16.0.0/12', '192.0.0.0/24', '192.0.2.0/24', '192.88.99.0/24',
	'192.168.0.0/16', '198.51.100.0/24', '203.0.113.0/24',
	'224.0.0.0/4', '240.0.0.0-255.255.255.255',
];

export {
	PKG_NAME, BRAND_NAME, VERSION, LISTS_BASE,
	HOME_DIR, PROVIDERS_REL, UI_DIR,
	TPROXY_PORT, API_ADDR, API_PORT, DNS_ADDR, DNS_PORT, FAKEIP_CIDR, FAKEIP_NFT,
	ROUTING_MARK,
	NFT_TABLE, NFT_SUBNET_SET, NFT_LOCAL_SET, NFT_IFACE_SET,
	NFT_FORCE_SET, NFT_FORCE_MAC_SET,
	TPROXY_MARK_HEX, TPROXY_MASK_HEX, BYPASS_MARK_HEX, BYPASS_MASK_HEX,
	RT_TABLE_ID, RT_RULE_PREF, LOCALV4
};
