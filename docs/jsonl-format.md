# JSONL and Experiment Formats

## Simulation Frames

The stable simulation-frame contract remains:

```json
{"step":0,"time":0.0,"bodies":[{"id":"body_1","mass":1.0,"position":{"x":0.0,"y":0.0},"velocity":{"x":0.0,"y":1.0},"acceleration":{"x":0.0,"y":0.0}}]}
```

There is one frame before stepping and one after each configured step. Required body fields are `id`, `mass`, `position`, `velocity`, and `acceleration`. Vectors contain finite `x` and `y` values. Consumers should require these fields while tolerating unknown fields for forward compatibility.

## Simulation Diagnostics

Passing `--diagnostics <path>` writes one engine-owned record for every simulation frame:

```json
{"schema_version":1,"record_type":"simulation_diagnostics","step":0,"time":0.0,"kinetic_energy":0.25,"potential_energy":-1.0,"total_energy":-0.75,"momentum":{"x":0.0,"y":0.0}}
```

Potential energy uses the same gravitational constant and softened distance as the engine force model.

## Performance Samples and Summary

Benchmark schema version 3 is performance-only:

```json
{"schema_version":3,"record_type":"benchmark_sample","run_id":"20261008-abc123","scenario":"scaling_golden_angle_v1","body_count":100,"steps":10,"sample_index":0,"warmups":2,"solver":"barnes_hut","theta":0.5,"theta_applicable":true,"elapsed_seconds":0.01,"average_step_seconds":0.001,"interactions":45000,"direct_interactions":20000,"approximated_interactions":25000,"tree_node_visits":90000,"interactions_per_second":4500000,"frames_written":0,"target_label":"local-x86_64","opt_label":"speed"}
```

- Raw JSONL is append-only and each record is one timed sample.
- Work counters come from one untimed deterministic replay per configuration.
- Brute force records theta as zero with `theta_applicable=false`.
- The optional CSV summary is replaced after a successful invocation and contains timing aggregates, work means, speedup, provenance labels, and `run_id`.
- Trajectory divergence is intentionally absent from performance records.

## Solver Accuracy

The `accuracy` command writes schema-version-1 `solver_accuracy` records and an optional CSV with the same columns:

```json
{"schema_version":1,"record_type":"solver_accuracy","run_id":"20261008-abc123","scenario":"force_accuracy_golden_angle_v1","body_count":100,"theta":0.5,"normalized_l2_acceleration_error":0.01,"mean_absolute_acceleration_error":0.1,"max_absolute_acceleration_error":0.5,"direct_interactions":20000,"approximated_interactions":25000,"tree_node_visits":90000,"target_label":"local-x86_64","opt_label":"speed"}
```

The command executes one brute-force and one Barnes-Hut force calculation on identical snapshots and does not integrate positions or velocities.
