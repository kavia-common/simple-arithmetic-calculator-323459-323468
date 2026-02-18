#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/simple-arithmetic-calculator-323459-323468/calculator_frontend"
cd "${WORKSPACE}"
[ -f /etc/profile.d/swift.sh ] && source /etc/profile.d/swift.sh || true
if [ "${SWIFT_TEST_PARALLEL:-0}" = "1" ]; then
  swift test --parallel
else
  swift test
fi
