# JSONL Format

The engine writes one JSON object per line. Simulation frames and benchmark records are separate command outputs.

## Simulation Frames

Frame shape:

```json
{"step":0,"time":0,"bodies":[{"id":"alpha","mass":1,"position":{"x":-1,"y":0},"velocity":{"x":0,"y":-0.25},"acceleration":{"x":0,"y":0}}]}
```

Rules:

- Frame `0` is written before any solver or integrator step.
- One frame is written after every successful step.
- Total line count is `steps + 1`.
- Viewers consume JSONL as a contract and must not infer different physics behavior.
- Body fields are `id`, `mass`, `position`, `velocity`, and `acceleration`.
- Vectors are objects with `x` and `y` float fields.

## Benchmark Records

Benchmark shape:

```json
{"body_count":100,"steps":10,"sample_index":0,"solver":"brute_force","elapsed_seconds":0.1,"average_step_seconds":0.01,"interactions":99000,"interactions_per_second":990000,"frames_written":0,"target_label":"unspecified","opt_label":"unspecified"}
```

Rules:

- Benchmark output is appended to the target JSONL file.
- Each record is one timed sample for one body count.
- Defaults are counts `100,500,1000,5000,10000`, `10` steps, and `3` samples per count.
- Export is disabled during benchmarks, so `frames_written` is always `0`.
