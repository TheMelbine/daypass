include $(TOPDIR)/rules.mk

# Prebuilt mihomo (Clash.Meta) core. mihomo is NOT in the official OpenWrt feed,
# so we package the upstream MetaCubeX release binary for the target arch and
# expose it as the virtual "mihomo" that daypass depends on. The binary is a
# static (CGO-disabled) Go build and runs on musl.
PKG_NAME:=mihomo
PKG_VERSION:=1.19.28
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only
PKG_MAINTAINER:=daypass <noreply@example.com>

# Map OpenWrt $(ARCH) -> upstream asset name + its sha256. Add rows to support
# more arches (asset names: https://github.com/MetaCubeX/mihomo/releases).
MIHOMO_FILE_aarch64:=mihomo-linux-arm64-v$(PKG_VERSION).gz
MIHOMO_HASH_aarch64:=2474450cd1c41dfa53036a54a4e85579f493d3af524d86c3d4b8e2b240b56cd2
MIHOMO_FILE_x86_64:=mihomo-linux-amd64-compatible-v$(PKG_VERSION).gz
MIHOMO_HASH_x86_64:=skip
MIHOMO_FILE_arm:=mihomo-linux-armv7-v$(PKG_VERSION).gz
MIHOMO_HASH_arm:=skip

MIHOMO_FILE:=$(MIHOMO_FILE_$(ARCH))
MIHOMO_HASH:=$(MIHOMO_HASH_$(ARCH))
# The metadata scan runs with an empty $(ARCH), which would leave PKG_SOURCE
# empty and break the whole feed index ("Download/default is missing the FILE
# field"). Fall back to a non-empty value so parsing always succeeds; the real
# per-arch asset is selected at build time when $(ARCH) is set.
ifeq ($(MIHOMO_FILE),)
MIHOMO_FILE:=mihomo-linux-arm64-v$(PKG_VERSION).gz
MIHOMO_HASH:=$(MIHOMO_HASH_aarch64)
endif

PKG_SOURCE:=$(MIHOMO_FILE)
PKG_SOURCE_URL:=https://github.com/MetaCubeX/mihomo/releases/download/v$(PKG_VERSION)
PKG_HASH:=$(MIHOMO_HASH)

include $(INCLUDE_DIR)/package.mk

define Package/mihomo
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Mihomo (Clash.Meta) proxy core — prebuilt upstream binary
  URL:=https://github.com/MetaCubeX/mihomo
  DEPENDS:=@(aarch64||arm||x86_64) +ca-bundle
  PROVIDES:=mihomo
endef

define Package/mihomo/description
 Rule-based proxy core (formerly Clash.Meta). Packaged from the official
 MetaCubeX release for this architecture.
endef

# PKG_SOURCE is a bare gzipped ELF, not a tarball: gunzip it into the build dir.
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	gzip -dc $(DL_DIR)/$(PKG_SOURCE) > $(PKG_BUILD_DIR)/mihomo
	chmod 0755 $(PKG_BUILD_DIR)/mihomo
endef

define Build/Compile
endef

define Package/mihomo/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/mihomo $(1)/usr/bin/mihomo
endef

$(eval $(call BuildPackage,mihomo))
