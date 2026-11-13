# QuickJS-ng PGO results: web-tooling-benchmark

**Setup** (`results/env.txt`): quickjs-ng `f265a18`, web-tooling-benchmark `a0b6a35`,
GCC 16.2.1, Clang 23.1.5, AMD Ryzen 9 5900X, Linux 7.3.3 (Fedora 45), `performance` governor.
CMake `Release` (`-O3`) builds. 10 runs per binary, interleaved round-robin, pinned to one core,
median reported. Throughput is in runs/s, so higher is better.

## Summary (geometric mean over 17 benchmarks)

| Compiler / PGO flavour | Baseline | PGO, trained on the suite | PGO, trained on `tests/microbench.js` |
|---|---:|---:|---:|
| GCC 16 (`-fprofile-generate/-use`) | 1.85 | 1.98 (**+7.0%**) | 1.91 (+3.2%) |
| Clang 23, IR PGO (`-fprofile-generate/-use`) | 1.90 | 2.20 (**+15.8%**) | 2.08 (+9.2%) |
| Clang 23, front-end PGO (`-fprofile-instr-generate/-instr-use`) | 1.90 | 1.88 (−1.1%) | 1.81 (−5.0%) |

Run-to-run stdev of the geomean is 0.017–0.032 runs/s (about 1–1.5%).

* **PGO pays off with both compilers.** The best result is Clang with IR-level PGO: +16% when
  trained on the suite, every benchmark faster (+8% typescript up to +28% chai). It is also the
  fastest binary overall: about 11% faster than GCC+PGO and 19% faster than the GCC baseline.
* **GCC + PGO:** +7%. Every benchmark improves, from +1.4% (typescript) to +15.6% (source-map).
* **Choose the Clang PGO flavour carefully.** Front-end/AST PGO (`-fprofile-instr-*`, the
  coverage-style instrumentation) does *not* help QuickJS here and is slightly slower than no PGO.
  The profile was applied correctly (no out-of-date or unprofiled warnings; 2295 functions in the profile).
  IR PGO instruments after early inlining and gives much better results for interpreters like this.
* **Training on a different workload still helps.** QuickJS's own synthetic `tests/microbench.js`
  gives about half to two thirds of the win (+3.2% GCC, +9.2% Clang IR). The win is not only an
  artifact of training on the benchmark itself. A broader, more realistic training set would
  probably land between the two columns.
* Without PGO, Clang is about 2.7% faster than GCC on this suite.

## Per-benchmark results (median runs/s)

| benchmark | gcc-release | gcc-pgo-wtb | gcc-pgo-microbench | clang-release | clang-pgo-wtb | clang-pgo-microbench | clang-ir-pgo-wtb | clang-ir-pgo-microbench |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| acorn | 0.74 | 0.78 | 0.78 | 0.74 | 0.76 | 0.73 | 0.84 | 0.83 |
| babel | 1.83 | 1.94 | 1.85 | 1.91 | 1.83 | 1.77 | 2.13 | 2.06 |
| babel-minify | 2.51 | 2.57 | 2.54 | 2.60 | 2.50 | 2.47 | 2.87 | 2.81 |
| babylon | 1.23 | 1.30 | 1.29 | 1.30 | 1.29 | 1.22 | 1.45 | 1.40 |
| buble | 2.54 | 2.70 | 2.63 | 2.61 | 2.58 | 2.51 | 2.99 | 2.91 |
| chai | 4.03 | 4.50 | 4.41 | 4.15 | 4.05 | 3.91 | 5.32 | 4.68 |
| espree | 0.54 | 0.56 | 0.57 | 0.52 | 0.56 | 0.52 | 0.59 | 0.58 |
| esprima | 1.00 | 1.07 | 1.06 | 1.04 | 1.02 | 0.97 | 1.21 | 1.14 |
| jshint | 2.42 | 2.60 | 2.45 | 2.42 | 2.47 | 2.37 | 2.83 | 2.67 |
| lebab | 2.04 | 2.25 | 2.09 | 2.12 | 2.07 | 2.01 | 2.51 | 2.34 |
| postcss | 2.12 | 2.25 | 2.11 | 2.11 | 2.08 | 2.00 | 2.53 | 2.35 |
| prepack | 2.22 | 2.33 | 2.24 | 2.30 | 2.23 | 2.16 | 2.58 | 2.49 |
| prettier | 1.51 | 1.63 | 1.49 | 1.51 | 1.52 | 1.43 | 1.71 | 1.62 |
| source-map | 1.63 | 1.89 | 1.79 | 1.69 | 1.65 | 1.60 | 2.11 | 1.95 |
| terser | 5.75 | 6.17 | 5.95 | 5.92 | 5.97 | 5.65 | 6.94 | 6.37 |
| typescript | 2.82 | 2.86 | 2.87 | 3.05 | 2.92 | 2.77 | 3.30 | 3.00 |
| uglify-js | 1.67 | 1.81 | 1.73 | 1.68 | 1.73 | 1.65 | 2.00 | 1.88 |
| **geomean** | 1.85 | 1.98 | 1.91 | 1.90 | 1.88 | 1.81 | 2.20 | 2.08 |

## Caveats

* The suite runs each benchmark with `minSamples: 1`, so a single run is noisy. Results here are
  medians of 10 full-suite runs.
* One machine (Zen 3) and one compiler version each. Other CPUs will differ in magnitude.
* Only the `qjs` CLI is measured. Applications that embed `libqjs` would need their own
  instrumented build of the library.
* Instrumented-binary training time was about 40–75 s per profile.

## Raw data

`results/raw.jsonl` holds every run of every binary. `results/medians.json` and
`results/summary.md` hold the summaries, and `results/bench.log` holds the console log.
