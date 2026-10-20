# Architecture

Sanxing is split into three worlds.

## Headless Odin Engine

The Odin engine owns simulation state, validation, solvers, integration, and export contracts. It is designed to run without a viewer so experiments and benchmarks can be repeated from the command line.

Current packages:

- `core`: shared data types, vector helpers, validation, and step orchestration.
- `solvers`: solver registry, brute-force solver, and Barnes-Hut solver.
- `integration`: semi-implicit Euler.
- `spatial`: rectangle helpers and 2D quadtree construction with mass aggregation.
- `export`: JSONL frame writer.
- `benchmark`: deterministic performance workloads, timed samples, solver-work profiling, and aggregate summaries.
- `accuracy`: untimed Barnes-Hut acceleration comparison against brute force.
- `diagnostics`: energy, momentum, and trajectory comparison metrics.
- `scenarios`: versioned deterministic experiment initial conditions.

## Local Viewer

The canonical local viewer is an Odin application using Raylib and raygui. Its renderer and controls consume a viewer-owned immutable frame contract through a finite/seekable frame-source boundary. The current source is JSONL replay; a future live source may wrap an engine session without changing rendering or playback code. The viewer owns no physics rules.

## Future Web Viewer

The former standalone HTML replay tool is preserved under `viewers/web/prototype` as an unsupported prototype. A supported web viewer remains future work and must independently consume the same JSONL contract.
