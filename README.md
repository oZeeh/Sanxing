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
./sanxing run engine/examples/simple_system.json
```

This runs the headless simulation and opens its completed JSONL replay in the native viewer. The launcher
prints and retains the generated replay path under `/tmp`. To choose the path or run without a viewer:

```sh
./sanxing simulate engine/examples/simple_system.json /tmp/sanxing-simple.jsonl
./sanxing view /tmp/sanxing-simple.jsonl
```

Use `./sanxing --help` or `./sanxing help simulate` for structured command help. Direct
`odin run engine/src -- ...` commands remain supported. A simulation output contains `steps + 1` JSON
lines when export is enabled.

Try the longer compact three-body close-encounter example:

```sh
./sanxing run engine/examples/close_encounter.json
```

Run benchmarks:

```sh
./sanxing benchmark /tmp/sanxing-bench.jsonl
```

Benchmark solver and accuracy options:

```sh
./sanxing benchmark /tmp/sanxing-bench.jsonl --solver barnes_hut --theta 0.5
```

Run a reproducible comparison sweep and generate a summary:

```sh
./sanxing benchmark /tmp/sanxing-bench.jsonl \
  --summary /tmp/sanxing-bench-summary.csv \
  --solver both --thetas 0.25,0.5,1.0 --warmups 1 \
  --run-id pilot --target-label local-x86_64 --opt-label default
```

Measure force-approximation error without integration:

```sh
./sanxing accuracy /tmp/sanxing-accuracy.jsonl \
  --summary /tmp/sanxing-accuracy.csv --counts 100,500,1000 \
  --thetas 0,0.25,0.5,1.0 --run-id pilot
```

Run the native viewer:

```sh
./sanxing view /tmp/sanxing-simple.jsonl
```

## Verify

See the [testing guide](docs/testing-guide.md) for the full automated, smoke, viewer, and thesis-evidence
test procedures.

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
odin test engine/src/cli
odin test viewers/local/src/replay
python3 -m unittest tools/test_analyze_experiments.py
python3 -m unittest tools/test_cli_launcher.py
```

## Layout

- `engine/src`: headless Odin engine packages.
- `engine/examples`: JSON input examples.
- `docs`: architecture, model, contract, experiment, and roadmap notes.
- `viewers/local`: canonical native JSONL replay and inspection viewer.
- `viewers/web`: preserved browser prototype and future independent web viewer.
- `tools`: clean-run experiment orchestration and standard-library analysis.
