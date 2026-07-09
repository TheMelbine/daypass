include $(TOPDIR)/rules.mk

# Prebuilt mihomo core shipped GZIPPED. The decompressed binary is ~43 MB, which
# does not fit on small-flash routers (e.g. 16/8 targets). This package installs
# the ~16 MB .gz to flash instead; daypass unpacks it to tmpfs on start (see
# mihomo_bin() in env.sh). PROVIDES mihomo, so it satisfies daypass's dependency
# exactly like the full mihomo package — install one or the other, not both.
PKG_NAME:=mihomo-gz
PKG_VERSION:=1.19.28
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=daypass <noreply@example.com>

# arch -> upstream asset + sha256 (same map as the full mihomo package).
MIHOMO_FILE_aarch64:=mihomo-linux-arm64-v$(PKG_VERSION).gz
MIHOMO_HASH_aarch64:=2474450cd1c41dfa53036a54a4e85579f493d3af524d86c3d4b8e2b240b56cd2
MIHOMO_FILE_x86_64:=mihomo-linux-amd64-compatible-v$(PKG_VERSION).gz
MIHOMO_HASH_x86_64:=skip
MIHOMO_FILE_arm:=mihomo-linux-armv7-v$(PKG_VERSION).gz
MIHOMO_HASH_arm:=skip

MIHOMO_FILE:=$(MIHOMO_FILE_$(ARCH))
MIHOMO_HASH:=$(MIHOMO_HASH_$(ARCH))
# Empty $(ARCH) during the metadata scan would blank PKG_SOURCE and break the
# feed index; fall back to a non-empty value (the real asset is chosen at build).
ifeq ($(MIHOMO_FILE),)
MIHOMO_FILE:=mihomo-linux-arm64-v$(PKG_VERSION).gz
MIHOMO_HASH:=$(MIHOMO_HASH_aarch64)
endif

PKG_SOURCE:=$(MIHOMO_FILE)
PKG_SOURCE_URL:=https://github.com/MetaCubeX/mihomo/releases/download/v$(PKG_VERSION)
PKG_HASH:=$(MIHOMO_HASH)

include $(INCLUDE_DIR)/package.mk

define Package/mihomo-gz
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Mihomo (Clash.Meta) core — gzipped for small-flash routers
  URL:=https://github.com/MetaCubeX/mihomo
  DEPENDS:=@(aarch64||arm||x86_64) +ca-bundle
  PROVIDES:=mihomo
endef

define Package/mihomo-gz/description
 Same MetaCubeX mihomo binary as the mihomo package, but installed compressed
 (~16 MB) and unpacked to tmpfs at runtime, for routers without room for the
 ~43 MB decompressed binary.
endef

# PKG_SOURCE is already the gzipped binary; ship it as-is, no build step.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	cp $(DL_DIR)/$(PKG_SOURCE) $(PKG_BUILD_DIR)/mihomo.gz
endef

define Build/Compile
endef

define Package/mihomo-gz/install
	$(INSTALL_DIR) $(1)/usr/lib/mihomo-gz
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/mihomo.gz $(1)/usr/lib/mihomo-gz/mihomo.gz
endef

$(eval $(call BuildPackage,mihomo-gz))
