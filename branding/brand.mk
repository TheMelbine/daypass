# branding/brand.mk — brand loader + shared substitution machinery.
#
# Included by every package Makefile. Selects a brand with
#     make ... BRAND=daypass        (default)
#     make ... BRAND=<name>         (a <name>.mk provided via BRAND_DIR)
#
# A brand file (<BRAND>.mk) defines the BRAND_* variables below. Only the default
# `daypass` brand lives in this tree; additional brands are supplied out-of-tree
# by pointing BRAND_DIR at a separate overlay directory. Everything else in the
# tree is brand-neutral and receives values through the Brand/Subst sed pass or
# the generated runtime brand include.

BRAND ?= daypass

# Resolve the brand definition file. BRAND_DIR lets a private/OEM overlay repo
# supply its own <brand>.mk without living in this tree.
BRAND_DIR ?= $(dir $(lastword $(MAKEFILE_LIST)))
-include $(BRAND_DIR)$(BRAND).mk

# Fallbacks so a bare checkout still builds the default brand even if the
# include path resolution above misses (e.g. odd SDK layouts).
BRAND_PKG     ?= daypass
BRAND_NAME    ?= Daypass
BRAND_URL     ?= https://github.com/you/daypass
BRAND_SUPPORT ?= https://github.com/you/daypass/issues
BRAND_DOCS    ?= https://github.com/you/daypass#readme
BRAND_LISTS   ?= https://github.com/itdoginfo/allow-domains/releases/latest/download
BRAND_ACCENT  ?= #2e7d32
BRAND_DASHBOARD ?= zashboard
BRAND_LICENSE ?= GPL-3.0-or-later
BRAND_MAINTAINER ?= daypass <noreply@example.com>
BRAND_CONFLICTS ?=
BRAND_LOGO    ?= $(BRAND_DIR)logo/daypass.svg

# Version: digit-led (apk requires it; ipk tolerates anything). Never 'v'-prefix.
DAYPASS_VERSION ?=
BRAND_VERSION := $(if $(DAYPASS_VERSION),$(DAYPASS_VERSION),0.$(shell date +%Y%m%d))

# Brand/Subst,<staging-dir>
# Replaces every __TOKEN__ across the install staging tree. sed is guaranteed
# present in every SDK; __UPPER__ tokens can't collide with sh/ucode/JS/JSON.
# Runs only over text files (true for this package set).
define Brand/Subst
	find $(1) -type f -exec sed -i \
		-e 's|__PKG_NAME__|$(BRAND_PKG)|g' \
		-e 's|__BRAND_NAME__|$(BRAND_NAME)|g' \
		-e 's|__PKG_VERSION__|$(BRAND_VERSION)|g' \
		-e 's|__BRAND_URL__|$(BRAND_URL)|g' \
		-e 's|__SUPPORT_URL__|$(BRAND_SUPPORT)|g' \
		-e 's|__DOCS_URL__|$(BRAND_DOCS)|g' \
		-e 's|__LISTS_BASE__|$(BRAND_LISTS)|g' \
		-e 's|__ACCENT__|$(BRAND_ACCENT)|g' \
		-e 's|__DASHBOARD__|$(BRAND_DASHBOARD)|g' \
		{} +
endef
