#!/usr/bin/env bash
set -euo pipefail
# Minimal Swift toolchain installer (idempotent)
WORKSPACE="/home/kavia/workspace/code-generation/simple-arithmetic-calculator-323459-323468/calculator_frontend"
SWIFT_DIR="/opt/swift"
SWIFT_PROFILE="/etc/profile.d/swift.sh"
: "${SWIFT_URL:=}"
: "${SWIFT_SHA256:=}"
: "${SWIFT_ALLOW_UNPINNED:=0}"
: "${SWIFT_VERSION:=}"
STAMP_TMP="/tmp/.swift_installed_stamp.tmp"
STAMP="${SWIFT_DIR}/.installed_from"
MIN_FREE_MB=200
# preflight tools
for cmd in curl tar sha256sum mktemp mv sudo df grep find command; do command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: required command '$cmd' not found" >&2; exit 2; }; done
# derive URL if unpinned allowed
if [ -z "$SWIFT_URL" ]; then
  if [ "$SWIFT_ALLOW_UNPINNED" = "1" ] && [ -n "$SWIFT_VERSION" ]; then
    SWIFT_URL="https://swift.org/builds/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"
    echo "WARNING: SWIFT_ALLOW_UNPINNED=1 enabled; using swift ${SWIFT_VERSION} from swift.org" >&2
  else
    echo "ERROR: SWIFT_URL and SWIFT_SHA256 must be provided, or set SWIFT_ALLOW_UNPINNED=1 with SWIFT_VERSION to opt-in to unpinned install" >&2
    exit 3
  fi
fi
if [ -z "$SWIFT_SHA256" ] && [ "$SWIFT_ALLOW_UNPINNED" != "1" ]; then
  echo "ERROR: SWIFT_SHA256 missing. Provide SWIFT_SHA256 for deterministic install or set SWIFT_ALLOW_UNPINNED=1 with SWIFT_VERSION" >&2
  exit 4
fi
# check /tmp free space
avail_kb=$(df --output=avail /tmp | tail -1 | tr -d ' ' || echo 0)
avail_mb=$(( (avail_kb + 1023) / 1024 ))
if [ "$avail_mb" -lt "$MIN_FREE_MB" ]; then echo "ERROR: insufficient free space in /tmp: ${avail_mb}MB < ${MIN_FREE_MB}MB" >&2; exit 5; fi
# install minimal native deps only if clang missing
if ! command -v clang >/dev/null 2>&1; then
  sudo apt-get update -q && sudo apt-get install -y --no-install-recommends clang libc++-dev libcurl4-openssl-dev libssl-dev pkg-config ca-certificates >/dev/null || { echo "ERROR: apt-get install failed" >&2; exit 6; }
fi
# if already installed and stamp matches, source profile and exit
if [ -f "$STAMP" ] && [ -x "${SWIFT_DIR}/usr/bin/swift" ] && (grep -qF "${SWIFT_URL} ${SWIFT_SHA256:-UNPINNED}" "$STAMP" 2>/dev/null || true); then
  [ -f "$SWIFT_PROFILE" ] && source "$SWIFT_PROFILE" || true
  swift --version >/dev/null 2>&1 || true
  exit 0
fi
# download
TGZ="/tmp/swift-toolchain.tar.gz"
rm -f "$TGZ"
curl --fail --location --max-time 300 --retry 3 --retry-delay 2 "$SWIFT_URL" -o "$TGZ" || { echo "ERROR: swift download failed" >&2; exit 7; }
# checksum if provided
if [ -n "$SWIFT_SHA256" ]; then
  printf "%s  %s\n" "$SWIFT_SHA256" "$TGZ" | sha256sum -c - >/dev/null || { echo "ERROR: swift tarball checksum mismatch" >&2; rm -f "$TGZ"; exit 8; }
fi
# extract to temp dir and find topdir containing usr/bin/swift
tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
tar -xzf "$TGZ" -C "$tmpdir" || { echo "ERROR: tar extract failed" >&2; exit 9; }
topdir=$(find "$tmpdir" -type f -path "*/usr/bin/swift" -printf "%h\n" | sed 's#/usr/bin##' | head -n1 || true)
if [ -z "$topdir" ] || [ ! -x "$topdir/usr/bin/swift" ]; then echo "ERROR: swift binary not found in archive" >&2; exit 10; fi
# move into place atomically
sudo rm -rf "$SWIFT_DIR" && sudo mkdir -p "$(dirname "$SWIFT_DIR")"
sudo mv "$topdir" "$SWIFT_DIR" || { echo "ERROR: moving swift into ${SWIFT_DIR} failed" >&2; exit 11; }
sudo chown -R root:root "$SWIFT_DIR"
# profile persistence
if [ ! -f "$SWIFT_PROFILE" ]; then
  tmpprof=$(mktemp)
  cat > "$tmpprof" <<'EOF'
export PATH=/opt/swift/usr/bin:$PATH
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
EOF
  sudo mv "$tmpprof" "$SWIFT_PROFILE"; sudo chmod 644 "$SWIFT_PROFILE"
fi
# write stamp atomically
echo "${SWIFT_URL} ${SWIFT_SHA256:-UNPINNED}" > "$STAMP_TMP" && sudo mv "$STAMP_TMP" "$STAMP" && sudo chown root:root "$STAMP"
# source and validate
[ -f "$SWIFT_PROFILE" ] && source "$SWIFT_PROFILE" || true
if ! command -v swift >/dev/null 2>&1; then echo "ERROR: swift not found after install" >&2; exit 12; fi
swift --version || true
if ! swift package --help >/dev/null 2>&1; then echo "ERROR: SwiftPM (swift package) not available; ensure the toolchain includes SwiftPM" >&2; exit 13; fi
req_major=5; req_minor=8
ver=$(swift --version | head -1 | sed -n 's/.*Swift version \([0-9]\+\)\.\([0-9]\+\).*/\1 \2/p' || true)
if [ -n "$ver" ]; then set -- $ver; inst_major=$1; inst_minor=$2; if [ "$inst_major" -lt "$req_major" ] || { [ "$inst_major" -eq "$req_major" ] && [ "$inst_minor" -lt "$req_minor" ]; }; then echo "ERROR: installed Swift ${inst_major}.${inst_minor} is older than required ${req_major}.${req_minor}" >&2; exit 14; fi; fi
rm -f "$TGZ"
