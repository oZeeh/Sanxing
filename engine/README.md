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

The runtime requires the `simulate` or `benchmark` subcommand. The current simulation runtime supports the `brute_force` and `barnes_hut` solvers. Barnes-Hut uses a 2D quadtree and the configured opening threshold `theta`.

Simulation inputs are strict JSON. Top-level, `config`, body, and vector objects reject unknown fields and all required fields must be present. Bodies require unique nonempty `id` values, positive `mass`, and finite `position`, `velocity`, and `acceleration` vectors. Config requires nonnegative `gravitational_constant`, positive `delta_time`, nonnegative integer `steps`, nonnegative `softening`, a solver of `brute_force` or `barnes_hut`, and boolean `export_enabled`. Config may also include optional nonnegative `theta`; when omitted, it defaults to `0.5`.

Run compute-only benchmarks:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl
```

Benchmark defaults are counts `100,500,1000,5000,10000`, `10` steps, `3` timed samples per count, solver `brute_force`, and `theta` `0.5`. Results are appended as JSONL records with `body_count`, `steps`, `sample_index`, `solver`, `theta`, `elapsed_seconds`, `average_step_seconds`, `interactions`, `interactions_per_second`, `average_position_divergence`, `max_position_divergence`, `frames_written`, `target_label`, and `opt_label`. Supported flags are `--counts`, `--steps`, `--samples`, `--solver`, `--theta`, `--target-label`, and `--opt-label`.
