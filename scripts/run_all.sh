#!/usr/bin/env bash
# End-to-end reproduction: fetch sources, build all variants, train, benchmark.
#   scripts/run_all.sh [runs]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNS="${1:-10}"
cd "$ROOT"

[ -d quickjs ] || git clone https://github.com/quickjs-ng/quickjs.git
[ -d web-tooling-benchmark ] || git clone https://github.com/quickjs-ng/web-tooling-benchmark.git

{
  echo "date: $(date -Is)"
  echo "quickjs-ng: $(git -C quickjs rev-parse HEAD)"
  echo "web-tooling-benchmark: $(git -C web-tooling-benchmark rev-parse HEAD)"
  echo "gcc: $(/usr/bin/gcc --version | head -1)"
  echo "clang: $(/usr/bin/clang --version | head -1)"
  echo "cpu: $(lscpu | sed -n 's/^Model name: *//p')"
  echo "kernel: $(uname -r)"
  echo "governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
} > results-env.txt
mkdir -p results; mv results-env.txt results/env.txt

for c in gcc clang clang-ir; do
  [ "$c" = clang-ir ] || scripts/build.sh "$c" release   # clang-ir baseline == clang-release
  scripts/build.sh "$c" instrumented
  for p in wtb microbench; do
    scripts/train.sh "$c" "$p"
    scripts/build.sh "$c" pgo "$p"
  done
done

rm -f results/raw.jsonl
python3 scripts/bench.py --runs "$RUNS" \
  gcc-release=build/gcc-release/qjs \
  gcc-pgo-wtb=build/gcc-pgo-wtb/qjs \
  gcc-pgo-microbench=build/gcc-pgo-microbench/qjs \
  clang-release=build/clang-release/qjs \
  clang-pgo-wtb=build/clang-pgo-wtb/qjs \
  clang-pgo-microbench=build/clang-pgo-microbench/qjs \
  clang-ir-pgo-wtb=build/clang-ir-pgo-wtb/qjs \
  clang-ir-pgo-microbench=build/clang-ir-pgo-microbench/qjs
