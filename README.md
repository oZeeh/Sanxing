# Sanxing

Sanxing is a headless Odin N-body simulation engine skeleton for three-body and larger gravitational systems.

The current implementation:

- loads a strict JSON simulation file,
- runs brute-force and Barnes-Hut gravitational solvers,
- integrates with semi-implicit Euler,
- writes one JSONL frame before stepping and one frame after each step.
- emits compute-only benchmark JSONL records, including Barnes-Hut divergence against brute force.

## Quick Start

```sh
odin run engine/src -- simulate engine/examples/simple_system.json /tmp/sanxing-simple.jsonl
```

The output file contains `steps + 1` JSON lines.

Run benchmarks:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl
```

Benchmark solver and accuracy options:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl --solver barnes_hut --theta 0.5
```

## Verify

```sh
odin check engine/src
odin test engine/src/core
odin test engine/src/solvers
odin test engine/src/integration
odin test engine/src/spatial
odin test engine/src/export
odin test engine/src/input
odin test engine/src/benchmark
```

## Layout

- `engine/src`: headless Odin engine packages.
- `engine/examples`: JSON input examples.
- `docs`: architecture, model, contract, experiment, and roadmap notes.
- `viewers/local`: local viewer placeholder.
- `viewers/web`: future web viewer placeholder.
