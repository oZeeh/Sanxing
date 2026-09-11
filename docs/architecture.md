# Architecture

Sanxing is split into three worlds.

## Headless Odin Engine

The Odin engine owns simulation state, validation, solvers, integration, and export contracts. It is designed to run without a viewer so experiments and benchmarks can be repeated from the command line.

Current packages:

- `core`: shared data types, vector helpers, validation, and step orchestration.
- `solvers`: solver registry, working brute-force solver, Barnes-Hut unsupported stub.
- `integration`: semi-implicit Euler.
- `spatial`: rectangle and quadtree placeholder types.
- `export`: JSONL frame writer.
- `benchmark`: benchmark data shapes only.

## Local Viewer

The local viewer will consume JSONL frames produced by the engine. It must not own physics rules, force equations, or integrator code.

## Future Web Viewer

The web viewer will use the same JSONL contract as the local viewer. Any live or WASM mode must keep physics behavior aligned with the headless engine.
