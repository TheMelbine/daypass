#!/bin/sh
# run-qemu.sh — best-effort QEMU harness: boot an official OpenWrt x86-64 image,
# install the built artifacts over SSH, and run the smoke suite.
#
#   FORMAT=apk BRAND=daypass tests/vm/run-qemu.sh
#
#   FORMAT=apk  -> OpenWrt 25.12 (apk packages)   [default]
#   FORMAT=ipk  -> OpenWrt 24.10 (ipk packages)
#
# Networking: user-mode NIC = WAN (with an SSH hostfwd so the host can reach the
# guest); an optional tap NIC = LAN for client-side traffic tests.
#
# This is intentionally documented + guarded rather than turnkey: image URLs,
# console wiring and first-boot SSH differ between releases. Everything is
# overridable via env. It exits 77 (skip) when prerequisites are missing.
#
# Prereqs: qemu-system-x86_64, ssh/scp, and (for the guest's empty root password
# on first boot) sshpass. Point PROXY_URL at tests/vm/proxy-endpoint.sh output to
# give the guest a real upstream.
set -eu

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FORMAT=${FORMAT:-apk}
BRAND=${BRAND:-daypass}
SSH_PORT=${SSH_PORT:-5555}
SSH_HOST=${SSH_HOST:-127.0.0.1}
WORK=${WORK:-$REPO_ROOT/tests/vm/.work}
MEM=${MEM:-512}
TAP_IF=${TAP_IF:-}                 # e.g. tap0 for a LAN-side NIC; empty = WAN only
PROXY_URL=${PROXY_URL:-}           # socks5://host:port to drop into the proxy section

case $FORMAT in
  apk) REL=${REL:-25.12.3} ;;
  ipk) REL=${REL:-24.10.6} ;;
  *)   echo "run-qemu: FORMAT must be apk or ipk" >&2; exit 2 ;;
esac

# Official combined ext4 EFI image (writable rootfs so we can install packages).
IMG_URL=${IMG_URL:-"https://downloads.openwrt.org/releases/${REL}/targets/x86/64/openwrt-${REL}-x86-64-generic-ext4-combined-efi.img.gz"}

command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "SKIP run-qemu: qemu-system-x86_64 not installed"; exit 77; }
command -v ssh >/dev/null 2>&1               || { echo "SKIP run-qemu: ssh not installed"; exit 77; }

ARTDIR="$REPO_ROOT/out/${BRAND}-${FORMAT}"
if ! ls "$ARTDIR"/*."$FORMAT" >/dev/null 2>&1; then
  echo "SKIP run-qemu: no artifacts in $ARTDIR — run 'BRAND=$BRAND FORMAT=$FORMAT scripts/build.sh' first"
  exit 77
fi

mkdir -p "$WORK"
IMG="$WORK/openwrt-${REL}-${FORMAT}.img"
if [ ! -f "$IMG" ]; then
  echo ">> fetching $IMG_URL"
  if command -v wget >/dev/null 2>&1; then wget -qO "$IMG.gz" "$IMG_URL";
  elif command -v curl >/dev/null 2>&1; then curl -fsSL -o "$IMG.gz" "$IMG_URL";
  else echo "SKIP run-qemu: need wget or curl to fetch the image"; exit 77; fi
  gunzip -f "$IMG.gz"
  # grow the disk so package installs have room
  qemu-img resize "$IMG" 512M >/dev/null 2>&1 || true
fi

# assemble NICs: user-mode WAN with SSH hostfwd (+ optional tap LAN)
NET="-netdev user,id=wan,hostfwd=tcp:${SSH_HOST}:${SSH_PORT}-:22 -device virtio-net-pci,netdev=wan"
if [ -n "$TAP_IF" ]; then
  NET="$NET -netdev tap,id=lan,ifname=${TAP_IF},script=no,downscript=no -device virtio-net-pci,netdev=lan"
fi

echo ">> booting OpenWrt $REL ($FORMAT) — serial log: $WORK/serial.log"
# shellcheck disable=SC2086
qemu-system-x86_64 -M q35 -m "$MEM" -nographic -serial "file:$WORK/serial.log" \
  -drive file="$IMG",format=raw,if=virtio \
  $NET \
  -pidfile "$WORK/qemu.pid" -daemonize
QEMU_PID=$(cat "$WORK/qemu.pid" 2>/dev/null || true)
cleanup() { [ -n "${QEMU_PID:-}" ] && kill "$QEMU_PID" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

COMMON="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"
# ssh uses -p for the port; scp uses -P. On first boot OpenWrt root has an empty
# password, so wrap with sshpass -p '' when available (otherwise a key/agent is
# expected to be set up out-of-band).
if command -v sshpass >/dev/null 2>&1; then PASS="sshpass -p ''"; else PASS=""; fi
SSH="$PASS ssh $COMMON -p $SSH_PORT"
SCP="$PASS scp $COMMON -P $SSH_PORT"

echo ">> waiting for guest SSH on ${SSH_HOST}:${SSH_PORT} (up to 120s)"
i=0; ready=0
while [ "$i" -lt 60 ]; do
  if eval "$SSH root@$SSH_HOST 'echo ok'" >/dev/null 2>&1; then ready=1; break; fi
  i=$((i + 1)); sleep 2
done
if [ "$ready" != 1 ]; then
  echo "run-qemu: guest never became reachable over SSH."
  echo "  Common cause: the guest's user-mode NIC is LAN (192.168.1.1/firewalled) not WAN,"
  echo "  or dropbear isn't up yet. Inspect $WORK/serial.log, or set TAP_IF / adjust firewall."
  exit 1
fi

echo ">> installing artifacts"
eval "$SCP $ARTDIR/*.$FORMAT root@$SSH_HOST:/tmp/"
if [ "$FORMAT" = apk ]; then
  eval "$SSH root@$SSH_HOST 'apk add --allow-untrusted /tmp/*.apk'"
else
  eval "$SSH root@$SSH_HOST 'opkg install /tmp/*.ipk'"
fi

if [ -n "$PROXY_URL" ]; then
  echo ">> configuring proxy: $PROXY_URL"
  eval "$SSH root@$SSH_HOST \"uci set $BRAND.main.proxy_string='$PROXY_URL' 2>/dev/null; \
    uci set $BRAND.main.enabled=1; uci set $BRAND.main.type=raw 2>/dev/null; uci commit $BRAND\""
fi

echo ">> pushing + running the smoke suite"
eval "$SSH root@$SSH_HOST 'mkdir -p /tmp/smoke'"
eval "$SCP $REPO_ROOT/tests/smoke/*.sh root@$SSH_HOST:/tmp/smoke/"
eval "$SSH root@$SSH_HOST 'sh /tmp/smoke/run-all.sh'"
rc=$?

echo ">> smoke suite exit: $rc"
exit "$rc"
