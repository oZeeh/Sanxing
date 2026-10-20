# Roadmap

## Completed Foundation

1. Brute-force solver, semi-implicit Euler, strict JSON input, and JSONL frame export.
2. Quadtree construction and Barnes-Hut with brute-force divergence checks.
3. Standalone local 2D JSONL replay viewer.

## Completed Experiment Infrastructure

1. Preserve every body in degenerate quadtree leaves and validate exact-mode behavior.
2. Instrument direct interactions, approximated interactions, and tree traversal work.
3. Run reproducible brute-force/Barnes-Hut/theta benchmark sweeps.
4. Generate aggregate CSV summaries with variability, solver-work, and speedup metrics.
5. Separate performance timing from direct Barnes-Hut acceleration-error measurement.
6. Export energy and momentum diagnostics and provide reproducible experiment tooling.
7. Build the native Odin/Raylib replay and body-inspection viewer.

## Current Milestone: Thesis Evidence

1. Commit a clean serial baseline and run the canonical experiment bundle.
2. Review generated runtime, speedup, force-error, convergence, conservation, and sensitivity evidence.
3. Incorporate tables, plots, limitations, and scope corrections into the thesis manuscript.

## Post-Thesis

1. Extract a reusable live engine session API and add a live source to the native viewer.
2. Add graphical simulation editing and optional CSV input through engine-owned validation.
3. Turn the browser prototype into an independent supported web JSONL viewer.
4. Explore parallelism, distributed execution, WASM, and finally 3D only after the serial results are accepted.
