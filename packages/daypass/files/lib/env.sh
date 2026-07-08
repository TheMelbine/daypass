# /usr/lib/__PKG_NAME__/env.sh — brand tokens + fixed runtime constants.
# Sourced by the CLI, init and every shell library. The placeholder values are
# substituted at package install; the fixed constants are identical across
# brands (see docs/CONTRACT.md).

# --- brand (substituted at install) ---
PKG_NAME="__PKG_NAME__"
BRAND_NAME="__BRAND_NAME__"
PKG_VERSION="__PKG_VERSION__"
BRAND_URL="__BRAND_URL__"
LISTS_BASE="__LISTS_BASE__"

# Base for community subnet (.lst IPv4) lists. Domains come from LISTS_BASE as
# <tag>_domain.mrs; subnets come from here as <tag>.lst. A mirror brand can
# override both by shipping its own env.sh values.
SUBNETS_BASE="https://raw.githubusercontent.com/itdoginfo/allow-domains/main/Subnets/IPv4"

# --- fixed constants ---
HOME_DIR="/etc/${PKG_NAME}"
CONFIG_PATH="${HOME_DIR}/config.yaml"
PROVIDERS_DIR="${HOME_DIR}/providers"
UI_DIR="/usr/share/${PKG_NAME}/ui"
UCODE_DIR="/usr/share/${PKG_NAME}/ucode"
CATALOG_PATH="/usr/share/${PKG_NAME}/lists.json"
LOG_DIR="/var/log/${PKG_NAME}"
LOG_PATH="${LOG_DIR}/core.log"
LIST_UPDATE_PID="/var/run/${PKG_NAME}_list_update.pid"

NFT_TABLE="${PKG_NAME}"
NFT_SUBNET_SET="subnets4"
NFT_LOCAL_SET="localv4"
NFT_IFACE_SET="lan_ifaces"

# tproxy mark: destination should be redirected to mihomo
TPROXY_MARK="0x00100000"
TPROXY_MASK="0x00100000"
# bypass mark: mihomo stamps this on its own sockets (routing-mark); the nft
# output chain returns on it to avoid a loop. Decimal form goes in config.yaml.
BYPASS_MARK="0x00200000"
BYPASS_MASK="0x00200000"
ROUTING_MARK_DEC="2097152"

RT_TABLE_ID="105"
RT_RULE_PREF="105"

TPROXY_PORT="7894"
API_PORT="9090"
API_ADDR="127.0.0.1"
DNS_ADDR="127.0.0.42"
DNS_PORT="53"
FAKEIP_CIDR="198.18.0.0/16"

log() {
	logger -t "$PKG_NAME" "$1"
}
