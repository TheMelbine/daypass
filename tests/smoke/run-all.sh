#!/bin/sh
# run-all.sh — POSIX / BusyBox-ash smoke runner for an installed daypass brand.
#
# Runs on a real router or a QEMU VM. The brand NAME is auto-detected from the
# installed tree (an /etc/config/<name> that also has /usr/bin/<name>,
# /etc/init.d/<name> and /usr/share/<name>/lists.json). Override with NAME=.
#
# Each numbered check is a standalone script that echoes a clear PASS/FAIL line
# and exits 0 (pass), 1 (fail), or 77 (skip — precondition/tool missing). They
# are SOURCED here in a subshell so their exit codes are captured while they
# inherit the detected $NAME.
#
#   NAME=daypass sh tests/smoke/run-all.sh
set -u

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

detect_name() {
  for cfg in /etc/config/*; do
    [ -f "$cfg" ] || continue
    n=${cfg##*/}
    if [ -x "/usr/bin/$n" ] && [ -x "/etc/init.d/$n" ] && [ -f "/usr/share/$n/lists.json" ]; then
      echo "$n"; return 0
    fi
  done
  return 1
}

NAME=${NAME:-$(detect_name || true)}
if [ -z "${NAME:-}" ]; then
  echo "run-all: could not detect an installed brand (need /etc/config/<name> with"
  echo "         matching /usr/bin/<name>, /etc/init.d/<name>, /usr/share/<name>/lists.json)."
  echo "         Pass NAME=<brand> explicitly to run anyway."
  exit 1
fi
export NAME
echo "=== daypass smoke suite — brand: $NAME ==="

pass=0; fail=0; skip=0; failed_list=""
for t in "$DIR"/[0-9][0-9]-*.sh; do
  [ -f "$t" ] || continue
  echo
  echo "--- ${t##*/} ---"
  ( . "$t" ); rc=$?
  case $rc in
    0)  pass=$((pass + 1)) ;;
    77) skip=$((skip + 1)); echo "SKIP ${t##*/}" ;;
    *)  fail=$((fail + 1)); failed_list="$failed_list ${t##*/}" ;;
  esac
done

echo
echo "=== results: pass=$pass fail=$fail skip=$skip ==="
[ -n "$failed_list" ] && echo "failed:$failed_list"
[ "$fail" -eq 0 ]
