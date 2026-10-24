# Testing Guide

This runbook describes the checks that are useful for Sanxing in its current state. It covers the
headless Odin engine, experiment tooling, JSONL replay parser, native viewer, and canonical thesis
evidence pipeline. It does not treat live engine/viewer coupling, a supported web viewer, 3D rendering,
parallel execution, CSV input, or graphical simulation editing as implemented features.

Run commands from the repository root unless stated otherwise.

## Test Levels

Use the smallest level that matches the change, then run the broader levels before creating an
evidence revision.

| Level | When to run | Scope |
|---|---|---|
| Fast check | During implementation | Static checks and tests for the changed package |
| Full automated suite | Before every commit or handoff | Engine, analyzer, and replay-parser tests |
| Smoke suite | After CLI, export, benchmark, or analysis changes | Real small simulations and result files |
| Viewer acceptance | After viewer or JSONL-contract changes | Native build plus manual interaction checks |
| Canonical experiment | Only from a clean committed revision | Complete thesis evidence matrix |

## Prerequisites

Confirm the required tools are available:

```sh
odin version
python3 --version
git --version
```

The engine and analyzer use the Odin and Python standard libraries. The native viewer additionally
needs the Raylib and raygui bindings distributed with Odin and a working graphical environment.

## Fast Checks

For engine changes, begin with:

```sh
odin check engine/src
```

Then run the package tests closest to the change:

| Changed area | Command |
|---|---|
| Simulation types and validation | `odin test engine/src/core` |
| Brute-force or Barnes-Hut solver | `odin test engine/src/solvers` |
| Integrator | `odin test engine/src/integration` |
| Quadtree | `odin test engine/src/spatial` |
| JSONL frames or diagnostics export | `odin test engine/src/export` |
| JSON input | `odin test engine/src/input` |
| Benchmark CLI, records, or summaries | `odin test engine/src/benchmark` |
| Force-accuracy measurements | `odin test engine/src/accuracy` |
| Energy, momentum, or divergence | `odin test engine/src/diagnostics` |
| Deterministic generated scenarios | `odin test engine/src/scenarios` |
| Replay parsing and validation | `odin test viewers/local/src/replay` |
| Experiment manifest, analysis, plots, or validation | `python3 -m unittest tools/test_analyze_experiments.py` |
| Engine CLI parsing and help | `odin test engine/src/cli` |
| Repository launcher dispatch | `python3 -m unittest tools/test_cli_launcher.py` |

For Python and shell tooling changes, also run:

```sh
python3 -m py_compile tools/analyze_experiments.py tools/test_analyze_experiments.py
sh -n tools/run_thesis_experiments.sh
git diff --check
```

`git diff --check` should produce no output.

## Full Automated Suite

Run this before committing a milestone or preparing an experiment revision:

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
odin check viewers/local/src
python3 -m unittest tools/test_analyze_experiments.py
python3 -m unittest tools/test_cli_launcher.py
python3 -m py_compile tools/analyze_experiments.py tools/test_analyze_experiments.py
sh -n tools/run_thesis_experiments.sh
git diff --check
```

At the current checkpoint, the expected automated counts are:

- 45 engine tests;
- 3 replay-parser tests;
- 4 experiment-analyzer tests;
- 5 launcher integration tests.

Treat compilation failures, failed assertions, memory-tracker findings, Python exceptions, shell syntax
errors, and whitespace errors as failures. Do not update the expected counts merely to hide a missing
test; confirm why a count changed.

## Engine and Export Smoke Test

Create a disposable directory under `/tmp`:

```sh
SANXING_SMOKE_DIR=$(mktemp -d /tmp/sanxing-smoke.XXXXXX)
```

Run the example simulation with diagnostics:

```sh
odin run engine/src -o:speed -- simulate \
  engine/examples/simple_system.json \
  "$SANXING_SMOKE_DIR/frames.jsonl" \
  --diagnostics "$SANXING_SMOKE_DIR/diagnostics.jsonl"
```

Check its record counts:

```sh
wc -l "$SANXING_SMOKE_DIR/frames.jsonl" "$SANXING_SMOKE_DIR/diagnostics.jsonl"
```

The current ten-step example must produce 11 frame records and 11 diagnostics records: the initial
state plus one record after each step.

Check deterministic replay on the same machine, compiler, and settings:

```sh
odin run engine/src -o:speed -- simulate \
  engine/examples/simple_system.json \
  "$SANXING_SMOKE_DIR/frames-second.jsonl"
cmp "$SANXING_SMOKE_DIR/frames.jsonl" "$SANXING_SMOKE_DIR/frames-second.jsonl"
```

The first command above includes diagnostics but diagnostics are written separately, so the two frame
files should be identical. `cmp` should produce no output.

## Benchmark and Accuracy Smoke Test

Use deliberately small counts. Smoke timings are only functional checks and must not be quoted as
scientific results.

```sh
odin run engine/src -o:speed -- benchmark \
  "$SANXING_SMOKE_DIR/performance.jsonl" \
  --summary "$SANXING_SMOKE_DIR/performance.csv" \
  --solver both --thetas 0.5 --counts 10,25 \
  --steps 2 --samples 2 --warmups 1 \
  --run-id smoke --target-label local-smoke --opt-label speed

odin run engine/src -o:speed -- accuracy \
  "$SANXING_SMOKE_DIR/accuracy.jsonl" \
  --summary "$SANXING_SMOKE_DIR/accuracy.csv" \
  --counts 10,25 --thetas 0,0.5 \
  --run-id smoke --target-label local-smoke --opt-label speed

wc -l "$SANXING_SMOKE_DIR/performance.jsonl" \
  "$SANXING_SMOKE_DIR/performance.csv" \
  "$SANXING_SMOKE_DIR/accuracy.jsonl" \
  "$SANXING_SMOKE_DIR/accuracy.csv"
```

Expected counts are:

| File | Records/lines | Reason |
|---|---:|---|
| `performance.jsonl` | 8 | 2 body counts × 2 solvers/configurations × 2 samples |
| `performance.csv` | 5 | Header plus 4 aggregate configurations |
| `accuracy.jsonl` | 4 | 2 body counts × 2 theta values |
| `accuracy.csv` | 5 | Header plus 4 accuracy configurations |

Inspect the CSV files and confirm:

- every requested body count and configuration appears exactly once in each summary;
- brute-force speedup is `1`;
- Barnes-Hut timing and work fields are finite and nonnegative;
- theta zero has normalized acceleration error at or below `1e-12`;
- run, target, and optimization labels match the command;
- raw JSONL files retain one object per line.

Re-running a benchmark against the same JSONL path should append raw records. Its summary describes
only the current invocation, so use new paths when record counts matter.

## Negative CLI and Input Checks

Most invalid-input cases are covered by automated tests. When changing argument or input validation,
also try representative failures manually:

```sh
odin run engine/src -- unknown
odin run engine/src -- benchmark /tmp/invalid.jsonl --counts 0
odin run engine/src -- benchmark /tmp/invalid.jsonl --solver unsupported
odin run engine/src -- accuracy /tmp/invalid.jsonl --thetas -1
```

Each command should exit unsuccessfully and explain the invalid command or option. Do not use the same
output path as valued results when exercising failure behavior.

For JSON parser changes, test at least one input with each relevant defect: missing required field,
unknown field, duplicate body ID, nonpositive mass, invalid solver, invalid timestep, and a non-finite
number representation. The parser must reject invalid input before simulation begins.

## Numerical Behavior Checks

Automated tests establish the main invariants, but changes to physics, integration, quadtree traversal,
or scenarios should be reviewed against these expectations:

- Brute force evaluates every ordered pair except self-interactions.
- Barnes-Hut with theta zero agrees with brute-force acceleration within `1e-12` normalized L2 error.
- Coincident and nearly coincident bodies remain represented in degenerate quadtree leaves.
- Solver acceleration is reset before each force calculation.
- Semi-implicit Euler updates velocity before position.
- Two-body position and energy errors decrease as the timestep is refined.
- Total linear momentum drift remains near floating-point noise for the symmetric two-body fixtures.
- Performance timing excludes JSONL export and the separate instrumented work replay.
- Force accuracy is measured before integration and is not inferred from late trajectory divergence.

If any expectation changes intentionally, update the tests, simulation model, experiment plan, and
thesis wording together.

## Native Viewer Acceptance Test

First build the viewer and prepare a replay:

```sh
odin check viewers/local/src
odin run engine/src -- simulate engine/examples/simple_system.json /tmp/sanxing-viewer.jsonl
odin run viewers/local/src -- /tmp/sanxing-viewer.jsonl
```

Also verify the combined user workflow:

```sh
./sanxing run engine/examples/simple_system.json
```

The engine must finish before the window opens, the printed temporary replay must remain after the
viewer closes, and an engine failure must prevent the viewer from launching.

Manually verify:

- the replay opens from the command-line path;
- starting without a path allows path-field loading and drag-and-drop;
- play, pause, previous frame, next frame, timeline seeking, and speed control work;
- the first and last frame cannot be stepped past;
- fit produces stable bounds without visible camera jitter;
- middle-button pan, wheel zoom, and camera reset work;
- trails and labels can be toggled;
- selecting a body displays its ID, mass, position, velocity, and acceleration;
- selection remains associated with the body ID while frames change;
- malformed JSONL reports a useful line-numbered error rather than crashing;
- unknown extra frame fields are ignored, while missing required fields are rejected.

The viewer passes only if it remains a consumer of exported snapshots. It must not calculate forces,
construct a quadtree, integrate bodies, or mutate simulation physics.

The preserved browser prototype under `viewers/web/prototype` is unsupported and is not a release gate.

## Experiment Analyzer Tests

Run:

```sh
python3 -m unittest -v tools/test_analyze_experiments.py
```

The tests cover:

- manifest schema, matrices, and exact command capture;
- a synthetic end-to-end analysis and bundle-completion pass;
- rejection of a missing matrix row;
- rejection of misaligned paired trajectories.

For analyzer changes, inspect the synthetic outputs indirectly through the assertions and add a focused
test for every new derived metric or validation rule. The analyzer must fail rather than mark a bundle
complete when required input or output is absent.

## Canonical Thesis Experiment

Run the canonical experiment only after all preceding checks pass and the intended source has been
committed. The runner rejects tracked or untracked worktree changes.

Confirm the baseline:

```sh
git status --short
git log -1 --oneline
```

`git status --short` must produce no output. Then choose a new directory that does not already exist:

```sh
tools/run_thesis_experiments.sh experiments/results/<UTC-date>-<short-commit>
```

This run can be computationally expensive, especially the 10,000-body direct-solver configurations.
Do not use a laptop battery-only session, a thermally unstable environment, or a machine with competing
heavy workloads. Preserve failures and impractical scale points rather than editing them out.

A successful run must leave `manifest.json` with `status` equal to `complete`. The manifest must include:

- the exact Git commit and a clean-state marker;
- Odin, Python, operating-system, processor, and target information;
- exact command arguments;
- performance, force-accuracy, convergence, and sensitivity matrices;
- completion time;
- sizes and SHA-256 hashes for every required artifact.

The bundle must contain:

- raw performance and accuracy JSONL;
- performance and accuracy CSV summaries;
- seven trajectories and seven diagnostics streams;
- orbit-convergence and trajectory-separation summaries;
- runtime, speedup, solver-work, tree-visit, force-error, orbit, and sensitivity SVG figures;
- a Markdown report containing numeric findings and automated warnings.

If the run is interrupted or validation fails, its manifest should remain `running`. Keep the directory
for diagnosis, but do not present it as definitive evidence and do not resume by appending unrelated
samples under the same run ID.

## Reviewing a Completed Evidence Bundle

Automated completion proves structural integrity, not scientific validity. Review the generated report,
CSV files, and figures and answer all of the following:

- At which body count, if any, does each Barnes-Hut theta outperform brute force?
- Are timing standard deviations small enough to support the comparison?
- Do interaction and node-visit trends explain the runtime behavior?
- Does increasing theta reduce work while increasing acceleration error?
- Is every theta-zero normalized L2 error at or below `1e-12`?
- Do orbit position error and maximum relative energy drift decrease with timestep refinement?
- Is momentum drift consistent with floating-point noise?
- Do the paired Burrau runs show separation, and is the interpretation stable across both timesteps?
- Are there anomalous or missing measurements that require a rerun or explicit limitation?
- Are claims limited to the tested serial engine, hardware, compiler, scenarios, and matrix?

Never describe benchmark timing as complete application runtime. Never use the scaling scenario as a
trajectory-accuracy claim, or the Burrau separation as an exact solution or Lyapunov exponent.

## Recommended Checkpoints

Before a normal code commit:

1. Run the relevant package tests.
2. Run `odin check engine/src`.
3. Run the analyzer tests if experiment tooling changed.
4. Run `git diff --check`.

Before an evidence-baseline commit:

1. Run the full automated suite.
2. Run the engine/export and benchmark/accuracy smoke tests.
3. Complete the native viewer acceptance test if the viewer or frame contract changed.
4. Review documentation against the implemented behavior.
5. Commit and verify a clean worktree.

After the evidence-baseline commit:

1. Run the canonical experiment once in a new results directory.
2. Review all automated warnings and scientific questions above.
3. Preserve the complete bundle and its manifest.
4. Only then incorporate measured tables, plots, and conclusions into the thesis.
