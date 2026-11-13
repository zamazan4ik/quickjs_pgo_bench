# PGO benchmarks for QuickJS-ng (GCC and Clang)

Measures the effect of Profile-Guided Optimization on the QuickJS-ng `qjs` binary using
[quickjs-ng/web-tooling-benchmark](https://github.com/quickjs-ng/web-tooling-benchmark), the suite
suggested in [quickjs-ng/quickjs discussion #1915](https://github.com/quickjs-ng/quickjs/discussions/1915#discussioncomment-19586805).

Results: see [RESULTS.md](RESULTS.md).

## Layout

| Path | What |
|---|---|
| `scripts/build.sh <gcc\|clang\|clang-ir> <release\|instrumented\|pgo> [profile]` | Builds `qjs` (`qjs_exe` CMake target) into `build/<compiler>-<mode>[-<profile>]/` |
| `scripts/train.sh <gcc\|clang\|clang-ir> <wtb\|microbench>` | Runs the instrumented `qjs` on a training workload and stores the profile in `profiles/<compiler>-<profile>/` |
| `scripts/bench.py [--runs N] [--cpu C] name=path ...` | Runs the benchmark round-robin over the binaries, pinned to one CPU; writes `results/raw.jsonl`, `results/summary.md`, `results/medians.json` |
| `scripts/run_all.sh [runs]` | Everything end to end: clone, build all variants, train, benchmark |
| `results/env.txt` | Commits, compiler versions, CPU, kernel of the recorded run |

## Reproduce

Requirements: `git`, `cmake`, `make`, GCC, Clang + `llvm-profdata`, `python3`, `taskset` (util-linux).

```bash
scripts/run_all.sh 10
```

## Build variants

All builds are CMake `Release` (`-O3 -DNDEBUG`) with no other changes; only the PGO flags differ.

| Variant | GCC flags | Clang flags |
|---|---|---|
| release | — | — |
| instrumented | `-fprofile-generate=<dir> -fprofile-prefix-path=<builddir> -fprofile-update=prefer-atomic` | `-fprofile-instr-generate=<dir>/qjs-%p.profraw` |
| pgo | `-fprofile-use=<dir> -fprofile-prefix-path=<builddir> -fprofile-partial-training -fprofile-correction -Werror=missing-profile` | `-fprofile-instr-use=<merged.profdata>` |

Clang is tested in two flavours: `clang` = front-end (AST) PGO as above, and `clang-ir` =
IR-level PGO (`-fprofile-generate=<dir>` / `-fprofile-use=<merged.profdata>`). Both use
`clang-release` as their baseline.

`-fprofile-prefix-path` makes GCC's `.gcda` names relative to the build directory, so the
profile collected in `build/gcc-instrumented` can be reused from `build/gcc-pgo-*`.
`-Werror=missing-profile` makes sure the build fails instead of silently ignoring the profile.

## Training workloads

* **wtb**: one full run of the web-tooling-benchmark itself, so training data = benchmark data
  (best case, typical for how PGO is deployed for a known workload).
* **microbench**: QuickJS's own `tests/microbench.js` — a different set of synthetic
  micro-benchmarks. It shows how much of the win survives when the profile does *not* come
  from the measured workload.

## Methodology notes

* Benchmark command: `qjs --stack-size 2048 --script dist/cli.js` (from the suite's README),
  run from inside `web-tooling-benchmark/`. The suite runs 17 benchmarks (coffeescript is disabled
  upstream) and prints runs/s for each plus a geometric mean.
* Each binary is run N times, interleaved round-robin, pinned with `taskset -c 2`; the median
  of the N runs is reported for each benchmark.
