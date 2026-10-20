# Sanxing Engine

This directory contains the headless Odin simulation engine.

Run the sample system:

```sh
odin run src -- simulate examples/simple_system.json /tmp/sanxing-simple.jsonl
```

From the repository root, use:

```sh
odin run engine/src -- simulate engine/examples/simple_system.json /tmp/sanxing-simple.jsonl
```

The runtime requires the `simulate`, `benchmark`, or `accuracy` subcommand. The current simulation runtime supports the `brute_force` and `barnes_hut` solvers. Barnes-Hut uses a 2D quadtree and the configured opening threshold `theta`.

Simulation inputs are strict JSON. Top-level, `config`, body, and vector objects reject unknown fields and all required fields must be present. Bodies require unique nonempty `id` values, positive `mass`, and finite `position`, `velocity`, and `acceleration` vectors. Config requires nonnegative `gravitational_constant`, positive `delta_time`, nonnegative integer `steps`, nonnegative `softening`, a solver of `brute_force` or `barnes_hut`, and boolean `export_enabled`. Config may also include optional nonnegative `theta`; when omitted, it defaults to `0.5`.

Run compute-only benchmarks:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl
```

Benchmark defaults are counts `100,500,1000,5000,10000`, `10` steps, `3` timed samples, `1` unrecorded warmup, and solver `brute_force`. Raw results are appended as schema-versioned JSONL records. Solver work is collected in an untimed deterministic replay so timing measures the normal solver path.

Run both solvers across a Barnes-Hut theta sweep and write a summary CSV:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl \
  --summary /tmp/sanxing-bench-summary.csv \
  --solver both --thetas 0.25,0.5,1.0 \
  --warmups 1 --run-id pilot --target-label local-x86_64 --opt-label default
```

Supported flags are `--counts`, `--steps`, `--samples`, `--warmups`, `--solver`, `--theta`, `--thetas`, `--summary`, `--run-id`, `--target-label`, and `--opt-label`. `--solver both` runs brute force once and Barnes-Hut once per theta for every body count. Solver-work profiling runs once per configuration outside the timed samples. Raw JSONL remains append-only; the optional summary CSV is replaced with aggregates for the current invocation.

Force accuracy is measured without advancing or integrating the system:

```sh
odin run engine/src -- accuracy /tmp/sanxing-accuracy.jsonl \
  --summary /tmp/sanxing-accuracy.csv \
  --counts 100,500,1000,5000,10000 --thetas 0,0.25,0.5,1.0 \
  --run-id pilot --target-label local-x86_64 --opt-label speed
```

Simulation can also write engine-owned conservation diagnostics:

```sh
odin run engine/src -- simulate examples/simple_system.json /tmp/frames.jsonl \
  --diagnostics /tmp/diagnostics.jsonl
```
