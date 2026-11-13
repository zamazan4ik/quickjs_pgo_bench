#!/usr/bin/env bash
# Collect a PGO profile with the instrumented build and store it under profiles/<compiler>-<name>.
#
#   scripts/train.sh <gcc|clang|clang-ir> <wtb|microbench>
#
#   wtb         - one full run of the web-tooling-benchmark (same workload as the benchmark)
#   microbench  - QuickJS's own tests/microbench.js (a *different* workload; used to check
#                 that the PGO win is not just an artifact of training on the benchmark)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMP="${1:?compiler: gcc|clang|clang-ir}"
NAME="${2:?profile: wtb|microbench}"
QJS="$ROOT/build/$COMP-instrumented/qjs"
RAW="$ROOT/profiles/$COMP-raw"
OUT="$ROOT/profiles/$COMP-$NAME"

[ -x "$QJS" ] || "$ROOT/scripts/build.sh" "$COMP" instrumented
rm -rf "$RAW" "$OUT"; mkdir -p "$RAW" "$OUT"

case "$NAME" in
  wtb)
    (cd "$ROOT/web-tooling-benchmark" && "$QJS" --stack-size 2048 --script dist/cli.js) ;;
  microbench)
    (cd "$ROOT/quickjs" && "$QJS" tests/microbench.js) ;;
  *) echo "unknown profile $NAME" >&2; exit 1 ;;
esac

if [ "$COMP" = gcc ]; then
  cp "$RAW"/*.gcda "$OUT"/
else
  llvm-profdata merge -o "$OUT/merged.profdata" "$RAW"/*.profraw
fi
echo "profile stored in $OUT"
