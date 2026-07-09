#!/bin/sh
# build.sh — build the daypass package set inside the OpenWrt SDK via Docker,
# then copy the resulting .apk/.ipk out of the image into out/<brand>-<format>/.
#
#   BRAND=daypass VERSION=1.2.3 FORMAT=apk scripts/build.sh
#
# Environment:
#   BRAND      brand id, selects branding/<BRAND>.mk        (default: daypass)
#   FORMAT     apk | ipk                                     (default: apk)
#   VERSION    digit-led package version, never 'v'-prefixed (default: 0.<YYYYMMDD>)
#   SDK_IMAGE  use this SDK base image instead of building docker/sdk/* — e.g. a
#              prebuilt itdoginfo/openwrt-sdk-<fmt>:<tag>. When set, docker/sdk is
#              NOT built.
#   OUT_DIR    artifact output dir                           (default: out/<brand>-<format>)
#
# 'make package/<DIR>/compile' targets the neutral DIRECTORY name (core, luci-app);
# the package NAME is brand-driven (PKG_NAME:=$(BRAND_PKG)) so the produced file is
# <brand>_<version>...  The BRAND/VERSION flow via --build-arg into the Dockerfile.
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT"

BRAND=${BRAND:-daypass}
FORMAT=${FORMAT:-apk}
VERSION=${VERSION:-}

# Digit-led version (apk requires it). Strip any accidental leading 'v'.
VERSION=${VERSION#v}
[ -n "$VERSION" ] || VERSION="0.$(date +%Y%m%d)"
case $VERSION in
  [0-9]*) : ;;
  *) echo "build.sh: VERSION must be digit-led (got '$VERSION')" >&2; exit 2 ;;
esac

case $FORMAT in
  apk) DEFAULT_SDK="daypass/sdk-apk:25.12" ;;
  ipk) DEFAULT_SDK="daypass/sdk-ipk:24.10" ;;
  *)   echo "build.sh: FORMAT must be apk or ipk (got '$FORMAT')" >&2; exit 2 ;;
esac

[ -f "branding/$BRAND.mk" ] || { echo "build.sh: unknown BRAND '$BRAND' (no branding/$BRAND.mk)" >&2; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "build.sh: docker not found on PATH" >&2; exit 2; }

# Did the caller supply their own SDK base? If so, don't build docker/sdk.
if [ -n "${SDK_IMAGE:-}" ]; then CALLER_SDK=1; else CALLER_SDK=0; fi
SDK_IMAGE=${SDK_IMAGE:-$DEFAULT_SDK}

PKG_IMAGE="daypass-build:${BRAND}-${FORMAT}-${VERSION}"
CONTAINER="daypass-extract-${BRAND}-${FORMAT}-$$"
OUT_DIR=${OUT_DIR:-"$REPO_ROOT/out/${BRAND}-${FORMAT}"}

# 1. SDK base image.
if [ "$CALLER_SDK" = 1 ]; then
  echo ">> Using caller-supplied SDK image: $SDK_IMAGE (docker/sdk not built)"
else
  echo ">> Building SDK base image $SDK_IMAGE from docker/sdk/Dockerfile-sdk-$FORMAT"
  docker build -f "docker/sdk/Dockerfile-sdk-$FORMAT" -t "$SDK_IMAGE" docker/sdk
fi

# 2. Package build image.
echo ">> Building $BRAND $FORMAT packages (version $VERSION) on $SDK_IMAGE"
docker build \
  -f "docker/Dockerfile-$FORMAT" \
  --build-arg SDK_IMAGE="$SDK_IMAGE" \
  --build-arg BRAND="$BRAND" \
  --build-arg VERSION="$VERSION" \
  -t "$PKG_IMAGE" \
  "$REPO_ROOT"

# 3. Extract artifacts (docker create + docker cp).
echo ">> Extracting *.$FORMAT artifacts to $OUT_DIR"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

docker create --name "$CONTAINER" "$PKG_IMAGE" >/dev/null
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT INT TERM

STAGE=$(mktemp -d)
# The per-arch tree holds utilities/ + luci/ subdirs; grab it all, then filter.
if ! docker cp "$CONTAINER:/builder/bin/packages/." "$STAGE/" 2>/dev/null; then
  docker cp "$CONTAINER:/builder/bin/." "$STAGE/"
fi

find "$STAGE" -type f -name "*.$FORMAT" -exec cp {} "$OUT_DIR/" \;
rm -rf "$STAGE"

FOUND=$(find "$OUT_DIR" -type f -name "*.$FORMAT" | wc -l | tr -d ' ')
if [ "$FOUND" -eq 0 ]; then
  echo "build.sh: no *.$FORMAT artifacts were produced" >&2
  exit 1
fi

echo ">> $FOUND artifact(s) in $OUT_DIR:"
ls -1 "$OUT_DIR"
