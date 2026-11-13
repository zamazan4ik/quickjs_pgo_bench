#!/usr/bin/env bash
# Build QuickJS-ng `qjs` in one of three modes for a given compiler.
#
#   scripts/build.sh <gcc|clang|clang-ir> <release|instrumented|pgo> [profile-name]
#
#   gcc       - GCC, -fprofile-generate / -fprofile-use
#   clang     - Clang, front-end PGO: -fprofile-instr-generate / -fprofile-instr-use
#   clang-ir  - Clang, IR-level PGO:  -fprofile-generate / -fprofile-use
#
#   release       - plain CMake Release build (-O3 -DNDEBUG), the baseline
#   instrumented  - PGO instrumentation build (GCC: -fprofile-generate,
#                   Clang: -fprofile-instr-generate)
#   pgo           - build optimized with a collected profile
#                   (profile-name defaults to "wtb"; see scripts/train.sh)
#
# Output: build/<compiler>-<mode>[-<profile>]/qjs
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/quickjs"
COMP="${1:?compiler: gcc|clang}"
MODE="${2:?mode: release|instrumented|pgo}"
PROF="${3:-wtb}"

# Use real compilers, bypass ccache wrappers (ccache + PGO profiles don't mix well)
case "$COMP" in
  gcc)   CC=/usr/bin/gcc ;;
  clang|clang-ir) CC=/usr/bin/clang ;;
  *) echo "unknown compiler $COMP" >&2; exit 1 ;;
esac

PROFDIR="$ROOT/profiles/$COMP-$PROF"
EXTRA=""
case "$MODE" in
  release)
    BDIR="$ROOT/build/$COMP-release" ;;
  instrumented)
    BDIR="$ROOT/build/$COMP-instrumented"
    if [ "$COMP" = gcc ]; then
      # .gcda files go to profiles/gcc-raw; -fprofile-prefix-path makes their
      # mangled names relative to the build dir so a different build dir can use them
      EXTRA="-fprofile-generate=$ROOT/profiles/gcc-raw -fprofile-prefix-path=$BDIR -fprofile-update=prefer-atomic"
    elif [ "$COMP" = clang-ir ]; then
      EXTRA="-fprofile-generate=$ROOT/profiles/clang-ir-raw"
    else
      # raw profiles go to profiles/clang-raw (one file per process, %p = pid)
      EXTRA="-fprofile-instr-generate=$ROOT/profiles/clang-raw/qjs-%p.profraw"
    fi ;;
  pgo)
    BDIR="$ROOT/build/$COMP-pgo-$PROF"
    if [ "$COMP" = gcc ]; then
      [ -d "$PROFDIR" ] || { echo "missing profile dir $PROFDIR" >&2; exit 1; }
      EXTRA="-fprofile-use=$PROFDIR -fprofile-prefix-path=$BDIR -fprofile-partial-training -fprofile-correction -Werror=missing-profile"
    elif [ "$COMP" = clang-ir ]; then
      [ -f "$PROFDIR/merged.profdata" ] || { echo "missing $PROFDIR/merged.profdata" >&2; exit 1; }
      EXTRA="-fprofile-use=$PROFDIR/merged.profdata -Wno-profile-instr-unprofiled"
    else
      [ -f "$PROFDIR/merged.profdata" ] || { echo "missing $PROFDIR/merged.profdata" >&2; exit 1; }
      EXTRA="-fprofile-instr-use=$PROFDIR/merged.profdata -Wno-profile-instr-unprofiled -Wno-profile-instr-out-of-date"
    fi ;;
  *) echo "unknown mode $MODE" >&2; exit 1 ;;
esac

rm -rf "$BDIR"
cmake -S "$SRC" -B "$BDIR" -G "Unix Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_C_FLAGS="$EXTRA" \
  -DCMAKE_EXE_LINKER_FLAGS="$EXTRA" \
  -DQJS_BUILD_EXAMPLES=OFF >/dev/null
cmake --build "$BDIR" --target qjs_exe -j "$(nproc)" >/dev/null
echo "built $BDIR/qjs"
