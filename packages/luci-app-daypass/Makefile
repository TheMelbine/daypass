# Locate branding/ relative to THIS Makefile (see packages/core/Makefile for the
# rationale; $(realpath) follows the gh-action-sdk feed symlink). Hard include so a
# missing brand.mk fails loudly instead of leaving PKG_NAME empty.
PKG_SELF_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

include $(TOPDIR)/rules.mk

BRAND_DIR ?= $(PKG_SELF_DIR)/../../branding/
include $(BRAND_DIR)brand.mk

PKG_NAME:=luci-app-$(BRAND_PKG)
PKG_VERSION:=$(BRAND_VERSION)
PKG_RELEASE:=1
PKG_LICENSE:=$(BRAND_LICENSE)
PKG_MAINTAINER:=$(BRAND_MAINTAINER)

LUCI_TITLE:=$(BRAND_NAME) - LuCI interface (mihomo + nft TPROXY)
LUCI_DEPENDS:=+luci-base +$(BRAND_PKG)
LUCI_PKGARCH:=all
LUCI_LANGUAGES:=en ru
LUCI_LANG.en:=English
LUCI_LANG.ru:=Русский (Russian)

include $(TOPDIR)/feeds/luci/luci.mk

# Neutral source names -> brand paths at install; then Brand/Subst resolves every
# __TOKEN__ placeholder for the selected brand. Source dir stays brand-neutral.
define Package/$(PKG_NAME)/install
	# --- client resources: view wrappers + fe-app bundle (view/app -> view/<brand>) ---
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/$(BRAND_PKG)
	$(CP) ./htdocs/luci-static/resources/view/app/. $(1)/www/luci-static/resources/view/$(BRAND_PKG)/

	# --- shared rpc helper (tools/app.js -> tools/<brand>.js) ---
	$(INSTALL_DIR) $(1)/www/luci-static/resources/tools
	$(INSTALL_DATA) ./htdocs/luci-static/resources/tools/app.js \
		$(1)/www/luci-static/resources/tools/$(BRAND_PKG).js

	# --- menu / acl / rpcd plugin / uci-defaults (renamed to brand paths) ---
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/app.json \
		$(1)/usr/share/luci/menu.d/luci-app-$(BRAND_PKG).json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/app.json \
		$(1)/usr/share/rpcd/acl.d/luci-app-$(BRAND_PKG).json

	$(INSTALL_DIR) $(1)/usr/share/rpcd/ucode
	$(INSTALL_DATA) ./root/usr/share/rpcd/ucode/luci.app \
		$(1)/usr/share/rpcd/ucode/luci.$(BRAND_PKG)

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./root/etc/uci-defaults/50_luci-app \
		$(1)/etc/uci-defaults/50_luci-$(BRAND_PKG)

	# --- brand logo into the app resource dir ---
	$(INSTALL_DATA) $(BRAND_LOGO) $(1)/www/luci-static/resources/view/$(BRAND_PKG)/logo.svg

	# fe-app committed bundle carries its own version token (not in Brand/Subst)
	if [ -f "$(1)/www/luci-static/resources/view/$(BRAND_PKG)/main.js" ]; then \
		sed -i -e 's|__COMPILED_VERSION_VARIABLE__|$(PKG_VERSION)|g' \
			$(1)/www/luci-static/resources/view/$(BRAND_PKG)/main.js; \
	fi

	# resolve all __TOKEN__ placeholders for this brand
	$(call Brand/Subst,$(1))
endef

# call BuildPackage
$(eval $(call BuildPackage,$(PKG_NAME)))
