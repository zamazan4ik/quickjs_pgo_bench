#!/usr/bin/env python3
"""Run the web-tooling-benchmark against several qjs binaries and summarize.

    scripts/bench.py [--runs N] [--cpu C] name=path/to/qjs [name=path ...]

Binaries are run round-robin (A B C A B C ...) so slow drift (thermals, background
load) affects all of them equally. Each run is pinned to one CPU with taskset.
Raw per-run results go to results/raw.jsonl, the summary to results/summary.md.
"""
import argparse, json, os, re, statistics, subprocess, sys, time, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WTB = os.path.join(ROOT, "web-tooling-benchmark")
LINE = re.compile(r"^\s*([\w-]+):\s+([\d.]+) runs/s")
GEO = re.compile(r"Geometric mean:\s+([\d.]+)")


def run_once(qjs, cpu):
    cmd = ["taskset", "-c", str(cpu), qjs, "--stack-size", "2048", "--script", "dist/cli.js"]
    out = subprocess.run(cmd, cwd=WTB, capture_output=True, text=True, check=True).stdout
    res = {}
    for line in out.splitlines():
        m = GEO.search(line)
        if m:
            res["geomean"] = float(m.group(1))
            continue
        m = LINE.match(line)
        if m:
            res[m.group(1)] = float(m.group(2))
    if "geomean" not in res:
        raise RuntimeError(f"benchmark failed for {qjs}:\n{out}")
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--cpu", type=int, default=2)
    ap.add_argument("--out", default=os.path.join(ROOT, "results"))
    ap.add_argument("bins", nargs="+")
    a = ap.parse_args()
    bins = [(n, os.path.abspath(p)) for n, p in (b.split("=", 1) for b in a.bins)]
    os.makedirs(a.out, exist_ok=True)
    data = {n: [] for n, _ in bins}
    with open(os.path.join(a.out, "raw.jsonl"), "a") as raw:
        for i in range(a.runs):
            for name, path in bins:
                t = time.time()
                r = run_once(path, a.cpu)
                data[name].append(r)
                raw.write(json.dumps({"bin": name, "run": i, **r}) + "\n"); raw.flush()
                print(f"[{i+1}/{a.runs}] {name:24s} geomean={r['geomean']:.3f} ({time.time()-t:.0f}s)", flush=True)

    keys = [k for k in data[bins[0][0]][0] if k != "geomean"] + ["geomean"]
    med = {n: {k: statistics.median(r[k] for r in rs) for k in keys} for n, rs in data.items()}
    sd = {n: statistics.stdev([r["geomean"] for r in rs]) if len(rs) > 1 else 0 for n, rs in data.items()}
    names = [n for n, _ in bins]
    lines = [f"Median of {a.runs} runs, runs/s (higher is better), pinned to CPU {a.cpu}\n",
             "| benchmark | " + " | ".join(names) + " |",
             "|---|" + "---:|" * len(names)]
    for k in keys:
        lines.append(f"| {'**'+k+'**' if k=='geomean' else k} | " + " | ".join(f"{med[n][k]:.2f}" for n in names) + " |")
    lines.append("| geomean stdev | " + " | ".join(f"{sd[n]:.3f}" for n in names) + " |")
    summary = "\n".join(lines)
    with open(os.path.join(a.out, "summary.md"), "w") as f:
        f.write(summary + "\n")
    with open(os.path.join(a.out, "medians.json"), "w") as f:
        json.dump(med, f, indent=1)
    print(summary)


if __name__ == "__main__":
    main()
