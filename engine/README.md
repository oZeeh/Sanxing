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

The runtime requires the `simulate` or `benchmark` subcommand. The current simulation runtime supports the `brute_force` solver. Selecting `barnes_hut` validates as input but exits cleanly with an unsupported-solver message.

Simulation inputs are strict JSON. Top-level, `config`, body, and vector objects reject unknown fields and all required fields must be present. Bodies require unique nonempty `id` values, positive `mass`, and finite `position`, `velocity`, and `acceleration` vectors. Config requires nonnegative `gravitational_constant`, positive `delta_time`, nonnegative integer `steps`, nonnegative `softening`, a solver of `brute_force` or `barnes_hut`, and boolean `export_enabled`.

Run compute-only benchmarks:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl
```

Benchmark defaults are counts `100,500,1000,5000,10000`, `10` steps, and `3` timed samples per count. Results are appended as JSONL records with `body_count`, `steps`, `sample_index`, `solver`, `elapsed_seconds`, `average_step_seconds`, `interactions`, `interactions_per_second`, `frames_written`, `target_label`, and `opt_label`. Supported flags are `--counts`, `--steps`, `--samples`, `--target-label`, and `--opt-label`.
