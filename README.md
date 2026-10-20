# Sanxing

Sanxing is a headless Odin N-body simulation engine skeleton for three-body and larger gravitational systems.

The current implementation:

- loads a strict JSON simulation file,
- runs brute-force and Barnes-Hut gravitational solvers,
- integrates with semi-implicit Euler,
- writes one JSONL frame before stepping and one frame after each step,
- emits schema-versioned compute-only benchmark records with measured solver work,
- measures Barnes-Hut acceleration error independently from trajectory integration,
- writes optional energy and momentum diagnostics,
- runs comparative solver/theta sweeps and writes aggregate CSV summaries,
- includes a native Odin/Raylib JSONL replay and inspection viewer.

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

Run a reproducible comparison sweep and generate a summary:

```sh
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl \
  --summary /tmp/sanxing-bench-summary.csv \
  --solver both --thetas 0.25,0.5,1.0 --warmups 1 \
  --run-id pilot --target-label local-x86_64 --opt-label default
```

Measure force-approximation error without integration:

```sh
odin run engine/src -- accuracy /tmp/sanxing-accuracy.jsonl \
  --summary /tmp/sanxing-accuracy.csv --counts 100,500,1000 \
  --thetas 0,0.25,0.5,1.0 --run-id pilot
```

Run the native viewer:

```sh
odin run viewers/local/src -- /tmp/sanxing-simple.jsonl
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
odin test engine/src/accuracy
odin test engine/src/diagnostics
odin test engine/src/scenarios
odin test viewers/local/src/replay
```

## Layout

- `engine/src`: headless Odin engine packages.
- `engine/examples`: JSON input examples.
- `docs`: architecture, model, contract, experiment, and roadmap notes.
- `viewers/local`: canonical native JSONL replay and inspection viewer.
- `viewers/web`: preserved browser prototype and future independent web viewer.
- `tools`: clean-run experiment orchestration and standard-library analysis.
