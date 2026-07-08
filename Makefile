# Top-level developer entrypoint. This is NOT the OpenWrt package Makefile —
# those live under packages/*/Makefile and are built by the SDK. This file
# drives the frontend build and the Docker-based SDK builds.
#
#   make fe                      build the fe-app bundle (committed main.js)
#   make apk  BRAND=daypass      build .apk packages via the 25.12 SDK image
#   make ipk  BRAND=daypass      build .ipk packages via the 24.10 SDK image
#   make all                     fe + apk + ipk for the default brand
#   make verify                  host-side artifact checks (out/)
#   make clean

BRAND   ?= daypass
VERSION ?=

.PHONY: all fe apk ipk verify clean

all: fe apk ipk

fe:
	cd fe-app && yarn install --frozen-lockfile && yarn build

apk:
	BRAND=$(BRAND) VERSION=$(VERSION) FORMAT=apk scripts/build.sh

ipk:
	BRAND=$(BRAND) VERSION=$(VERSION) FORMAT=ipk scripts/build.sh

verify:
	scripts/verify-pkg.sh out

clean:
	rm -rf out fe-app/node_modules fe-app/dist
