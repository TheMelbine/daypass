# Locate the repo's branding/ relative to THIS Makefile. $(realpath ...) follows
# symlinks, so this resolves correctly even when openwrt/gh-action-sdk symlinks the
# package into package/feeds/<feed>/ (a plain $(abspath) would point at the symlink
# dir, not the repo). Works from a plain checkout, our docker SDK image, and
# gh-action-sdk alike — every layout keeps packages/<pkg>/ a sibling of branding/.
PKG_SELF_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

include $(TOPDIR)/rules.mk

# Hard include (not -include): a missing brand.mk must fail loudly rather than
# silently leave PKG_NAME empty (which yields "No rule to make target …").
BRAND_DIR ?= $(PKG_SELF_DIR)/../../branding/
include $(BRAND_DIR)brand.mk

PKG_NAME:=$(BRAND_PKG)
PKG_VERSION:=$(BRAND_VERSION)
PKG_RELEASE:=1
PKG_LICENSE:=$(BRAND_LICENSE)
PKG_MAINTAINER:=$(BRAND_MAINTAINER)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=$(BRAND_NAME) - selective transparent proxy (mihomo + nft TPROXY)
  URL:=$(BRAND_URL)
  PKGARCH:=all
  DEPENDS:=+mihomo +ca-bundle +curl +jsonfilter firewall4 +ip-full \
    +kmod-nft-tproxy \
    +ucode +ucode-mod-fs +ucode-mod-uci +ucode-mod-ubus
endef

define Package/$(PKG_NAME)/description
 $(BRAND_NAME) routes selected traffic (by domain list or subnet) through a
 mihomo proxy using an external nftables TPROXY layer. Unselected traffic is
 routed directly by the kernel and never touches the proxy process.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(BRAND_PKG)
endef

# Files-only package.
define Build/Configure
endef
define Build/Compile
endef

define Package/$(PKG_NAME)/install
	# CLI, init, UCI config (renamed from neutral source names to brand paths)
	$(INSTALL_DIR) $(1)/usr/bin $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) ./files/cli    $(1)/usr/bin/$(BRAND_PKG)
	$(INSTALL_BIN) ./files/init   $(1)/etc/init.d/$(BRAND_PKG)
	$(INSTALL_CONF) ./files/config $(1)/etc/config/$(BRAND_PKG)

	# Shell libraries
	$(INSTALL_DIR) $(1)/usr/lib/$(BRAND_PKG)
	$(INSTALL_DATA) ./files/lib/env.sh         $(1)/usr/lib/$(BRAND_PKG)/env.sh
	$(INSTALL_DATA) ./files/lib/dnsmasq.sh      $(1)/usr/lib/$(BRAND_PKG)/dnsmasq.sh
	$(INSTALL_DATA) ./files/lib/nftset.sh       $(1)/usr/lib/$(BRAND_PKG)/nftset.sh
	$(INSTALL_DATA) ./files/lib/list-update.sh  $(1)/usr/lib/$(BRAND_PKG)/list-update.sh

	# ucode generator + nft template + catalog
	$(INSTALL_DIR) $(1)/usr/share/$(BRAND_PKG)/ucode
	$(INSTALL_DATA) ./files/ucode/constants.uc  $(1)/usr/share/$(BRAND_PKG)/ucode/constants.uc
	$(INSTALL_DATA) ./files/ucode/lib.uc        $(1)/usr/share/$(BRAND_PKG)/ucode/lib.uc
	$(INSTALL_DATA) ./files/ucode/outbound.uc   $(1)/usr/share/$(BRAND_PKG)/ucode/outbound.uc
	$(INSTALL_DATA) ./files/ucode/generate.uc   $(1)/usr/share/$(BRAND_PKG)/ucode/generate.uc
	$(INSTALL_DATA) ./files/ucode/nft.ut        $(1)/usr/share/$(BRAND_PKG)/ucode/nft.ut
	$(INSTALL_DATA) ./files/share/lists.json    $(1)/usr/share/$(BRAND_PKG)/lists.json

	# first-boot secret generation
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/uci-defaults/init $(1)/etc/uci-defaults/90-$(BRAND_PKG)

	# sysupgrade keep-list (persist config + cached providers)
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/keep.lst $(1)/lib/upgrade/keep.d/$(BRAND_PKG)

	# persistent home for mihomo (config + providers cache)
	$(INSTALL_DIR) $(1)/etc/$(BRAND_PKG)/providers/rule

	# resolve all __TOKEN__ placeholders for this brand
	$(call Brand/Subst,$(1))
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] || /etc/init.d/$(BRAND_PKG) stop
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
