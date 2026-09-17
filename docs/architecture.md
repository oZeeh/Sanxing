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
- `benchmark`: deterministic body generation, timed samples, solver selection, and divergence records.

## Local Viewer

The local viewer consumes JSONL frames produced by the engine. Its first version is `viewers/local/index.html`, a standalone 2D replay tool with file loading, play/pause, stepping, timeline scrubbing, and frame metadata. It must not own physics rules, force equations, or integrator code.

## Future Web Viewer

The web viewer will use the same JSONL contract as the local viewer. Any live or WASM mode must keep physics behavior aligned with the headless engine.
