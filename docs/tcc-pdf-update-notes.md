# TCC/PDF Update Dossier

This document summarizes the Sanxing work completed through 2026-10-08 and compares the repository with `TCC___Engine_de_Simulação_do_Problema_dos_3_Corpos.pdf`. It is an English source document for revising the Portuguese thesis. It distinguishes implemented and verified behavior from partial features, planned work, and experimental evidence that has not yet been collected.

## 1. Executive Summary

Sanxing has progressed from an architectural proposal and an early Rust quadtree prototype to an Odin-first, headless two-dimensional N-body simulation engine. The current engine accepts strict JSON configuration, computes gravitational acceleration with either a direct brute-force solver or a Barnes-Hut solver, advances bodies with semi-implicit Euler integration, and exports simulation frames as JSON Lines (JSONL).

The engine is independent from its visualization layer. The canonical native Odin/Raylib viewer loads exported JSONL files and replays the simulation in 2D with playback, timeline, camera, trails, labels, selection, and body inspection. The viewer does not calculate forces or update physical state.

The project also contains an experiment-ready benchmark and analysis pipeline. It generates deterministic scenarios, runs brute-force and Barnes-Hut configurations, supports theta sweeps and warmups, records timing and solver-work metrics, measures force-approximation error, exports energy and momentum diagnostics, and produces aggregate CSV summaries and SVG figures. This infrastructure has been implemented and tested, but the definitive thesis experiment bundle has not yet been run from a clean, declared Git revision on a documented hardware/compiler configuration. Consequently, the thesis must not yet claim a measured speedup, scalability result, or accepted accuracy/performance tradeoff.

The current engine and native viewer pass static checking. All engine-package tests and all three native replay-parser tests pass. The former standalone HTML replay viewer is preserved under the web prototype directory.

## 2. Work Completed So Far

### 2.1 Project evolution

1. Initial modeling artifacts were created for the architecture, behavior, simulation activity, use cases, schedule, and interface concepts.
2. An early minimum quadtree prototype was created in Rust. That prototype was subsequently removed when the project was rebuilt as an Odin-first engine. Rust/Cargo is not part of the current architecture.
3. The headless Odin foundation was implemented with shared simulation types, vector operations, configuration validation, brute-force gravity, semi-implicit Euler integration, JSON input, JSONL output, tests, and an initial benchmark path.
4. A two-dimensional quadtree and Barnes-Hut solver were integrated, including accuracy comparison against brute force.
5. A standalone HTML 2D JSONL replay prototype was implemented and later moved under the web prototype directory.
6. The current experiment milestone improved degenerate quadtree handling, added solver-work instrumentation, introduced reproducible solver/theta benchmark sweeps, and added aggregate CSV summaries.
7. Dedicated scenario, diagnostics, and accuracy packages were added, together with two-body convergence inputs and perturbed Burrau three-body inputs.
8. A canonical experiment runner and standard-library Python analyzer were added to capture provenance, execute the complete evidence suite, calculate derived results, and generate thesis-ready SVG figures.
9. A native Odin/Raylib replay and inspection viewer was completed with a strict parser and extensible frame-source abstraction.

### 2.2 Current engine architecture

The current solution has three intentionally separate areas:

- **Headless Odin engine:** owns input validation, physical state, gravitational solvers, numerical integration, export contracts, deterministic benchmark generation, measurement, and result aggregation.
- **Local viewer:** the native Odin/Raylib application consumes simulation JSONL and renders an independent 2D replay with camera and inspection controls. It owns presentation and replay state only.
- **Future web viewer:** reserved for a separate implementation that will consume the same JSONL contract. It is not implemented yet.

The package responsibilities are:

| Package | Current responsibility |
|---|---|
| `core` | Simulation types, vector helpers, configuration validation, step coordination, and solver statistics contract |
| `input` | Strict JSON parsing and validation |
| `solvers` | Solver selection, direct brute-force gravity, and Barnes-Hut traversal |
| `spatial` | Quadtree bounds, insertion, subdivision, leaf buckets, mass, and center-of-mass aggregation |
| `integration` | Semi-implicit Euler state update |
| `export` | Simulation-frame JSONL writer |
| `benchmark` | Deterministic performance inputs, timed samples, one-time work profiling, sweeps, and CSV aggregation |
| `scenarios` | Shared deterministic body generation and owned state cloning |
| `diagnostics` | Kinetic, potential, and total energy; momentum; and trajectory divergence |
| `accuracy` | Barnes-Hut acceleration-error sweeps against direct-force results |

Relevant repository descriptions are available in [Architecture](architecture.md), [Simulation Model](simulation-model.md), [JSONL and Benchmark Formats](jsonl-format.md), and the [Engine README](../engine/README.md).

### 2.3 Implemented physical and numerical model

Each body has an identifier, mass, two-dimensional position, velocity, and acceleration. For target body `i` and source body `j`, the direct solver applies:

```text
delta = position_j - position_i
distance_sq = dot(delta, delta) + softening^2
acceleration_i += delta * (G * mass_j / (distance_sq * sqrt(distance_sq)))
```

The softening parameter prevents the inverse-distance calculation from becoming singular for very close bodies. Inputs are unit-agnostic but must use one internally consistent unit system.

The integrator is semi-implicit Euler:

```text
velocity += acceleration * delta_time
position += velocity * delta_time
```

The simulation writes its initial state before the first solver step and one state after every successful step. A configuration with `steps = N` therefore produces `N + 1` frames when export is enabled.

### 2.4 Strict input and validation

The engine accepts a simulation JSON object containing `config` and `bodies`. Unknown fields are rejected at the top level and inside configuration, body, and vector objects. Required fields must be present.

Validation currently enforces:

- unique, nonempty body identifiers;
- positive body mass;
- finite position, velocity, and acceleration components;
- a finite, nonnegative gravitational constant;
- a finite, positive time step;
- a nonnegative integer step count;
- finite, nonnegative softening and theta values;
- a solver value of `brute_force` or `barnes_hut`;
- a Boolean export flag.

`theta` is optional in input and defaults to `0.5`. JSON input is implemented. CSV input and graphical configuration are not implemented.

### 2.5 Brute-force solver

The direct solver evaluates every ordered target/source pair except self-interactions. Its per-step work is therefore `N(N-1)` direct contributions, giving quadratic time complexity, `O(N^2)`. It resets acceleration before computing the next state and provides the reference acceleration used to assess Barnes-Hut force error.

### 2.6 Quadtree and Barnes-Hut solver

The Barnes-Hut solver constructs a square two-dimensional quadtree around all bodies. Every node tracks its bounds, total body count, total mass, and center of mass. Internal nodes contain four children. Leaves contain body indices.

The current implementation preserves multiple bodies in the same leaf when subdivision reaches a maximum depth or minimum spatial size. This prevents coincident or nearly coincident bodies from being lost or causing unbounded subdivision. Exact traversal with `theta = 0` has been tested against brute force, including coincident-body cases.

For a target body outside a candidate node, Barnes-Hut accepts the node as an aggregate source when:

```text
node_width / softened_distance < theta
```

Otherwise, traversal continues into the node's children. A smaller theta is more conservative and generally performs more direct work; a larger theta permits more approximations. A node that contains the target body is not accepted as one aggregate, which prevents self-force through the node's center of mass.

### 2.7 Export and replay viewer

Simulation output uses one JSON object per line. Each frame contains `step`, `time`, and the complete body snapshots required for replay. The stable body fields are `id`, `mass`, `position`, `velocity`, and `acceleration`.

The current local viewer is the native Odin/Raylib application in `viewers/local/src`. It can:

- load a local engine-generated JSONL file;
- validate complete required frame/body fields, finite values, unique IDs, and monotonic frame order;
- render bodies with stable fitted 2D camera bounds, pan, and zoom;
- play and pause the replay;
- move one frame forward or backward;
- scrub through the timeline;
- control speed, trails, and labels;
- select a body and inspect mass, position, velocity, and acceleration.

It does not run the engine, edit simulation bodies, calculate forces, or continue a simulation. A live engine connection, graphical configuration, and a supported independent web viewer remain future work. The former HTML viewer is preserved at `viewers/web/prototype/index.html`.

### 2.8 Benchmark and comparison infrastructure

The benchmark command now supports:

- configurable body counts, steps, timed samples, and unrecorded warmups;
- `brute_force`, `barnes_hut`, or `both` solver modes;
- one theta value or a unique theta sweep;
- target and optimization labels for provenance;
- append-only raw JSONL sample records;
- an optional CSV summary for the current invocation.

The canonical experiment runner uses body counts `100, 500, 1000, 5000, 10000`, 10 steps, ten timed samples, two warmups, one brute-force configuration per body count, and Barnes-Hut theta values `0.25`, `0.5`, and `1.0`. Initial conditions come from the deterministic `scaling_golden_angle_v1` scenario. The older three-sample/one-warmup values in the prose experiment plan should be updated to match this definitive protocol.

Benchmark schema version 3 records:

- elapsed time and mean time per step;
- total, direct, and approximated force contributions;
- nonempty quadtree node visits;
- interactions per second;
- solver, theta applicability, sample index, warmup count, scenario, and body count;
- a run identifier plus target and optimization labels;
- a frame count of zero because benchmark export is disabled.

Timing covers the normal simulation steps only. Work counters are collected once per configuration in a separate deterministic replay so instrumentation does not contaminate elapsed time. Force accuracy is measured by the separate `accuracy` command.

The optional CSV summary groups the current invocation by body count, solver, theta, run identifier, target label, and optimization label. It contains mean, sample standard deviation, minimum and maximum elapsed time, mean step time, averaged work metrics, and speedup relative to the matching brute-force mean. Raw JSONL is append-only; the requested summary file is replaced only after all samples complete successfully.

### 2.9 Accuracy, diagnostics, and canonical experiment tooling

The dedicated `accuracy` command compares Barnes-Hut acceleration vectors with direct-solver acceleration vectors before integration changes the state. For every body count and theta, it records normalized L2 acceleration error, mean absolute acceleration error, maximum absolute acceleration error, and Barnes-Hut work counters. Theta zero is included as an exact-control configuration. Raw accuracy records use JSONL and an optional CSV summary contains one row per body-count/theta pair.

The diagnostics package calculates kinetic energy, softened gravitational potential energy, total energy, and total linear momentum. The `simulate` command can write a separate diagnostics JSONL stream with one record for the initial state and every exported step. Two-body circular-orbit fixtures at 100, 200, and 400 steps support a timestep-convergence study. Tests verify that position and energy error decrease when the timestep is halved.

The experiment fixtures also contain a Burrau-style three-body system and a version perturbed by `1e-10` in one initial x-coordinate, each at timesteps `0.001` and `0.0005`. These runs support an observed trajectory-sensitivity study while exposing timestep dependence. They must not be presented as an exact unsoftened reference solution.

`tools/run_thesis_experiments.sh` defines the canonical evidence bundle. It refuses to run from a dirty tracked revision, creates an immutable run identifier, records a machine/compiler manifest, executes performance and force-accuracy matrices, generates convergence and sensitivity trajectories with diagnostics, and calls `tools/analyze_experiments.py`. The analyzer produces summary CSV files, a concise report, and SVG figures for runtime, speedup, force error, orbit convergence, and trajectory separation.

### 2.10 Verification completed

On 2026-10-08, the current working tree passed:

| Verification | Result |
|---|---:|
| `odin check engine/src` | Passed |
| Core tests | 2 passed |
| Solver tests | 6 passed |
| Integration tests | 2 passed |
| Spatial tests | 6 passed |
| Export tests | 2 passed |
| Input tests | 7 passed |
| Benchmark tests | 10 passed |
| Accuracy tests | 2 passed |
| Diagnostics tests | 2 passed |
| Scenario tests | 2 passed |
| **Engine total** | **41 passed** |
| Native replay parser tests | 3 passed |

End-to-end smoke checks also generated 11 simulation frames and 11 diagnostics records from the 10-step example, ran a small brute-force/Barnes-Hut comparison, produced raw benchmark JSONL and a grouped CSV summary, and produced raw and summarized force-accuracy records. The timing and error numbers from these smoke checks are not scientific results and must not be copied into the thesis results section. The canonical experiment runner itself has not been executed because it correctly requires a clean tracked revision.

## 3. PDF Requirements and Repository Intersection

### 3.1 Specific objectives

| PDF objective | Status | Repository evidence and required PDF treatment |
|---|---|---|
| Implement an N-body gravitational numerical model | Implemented | Describe 2D bodies, softened gravity, state stepping, and semi-implicit Euler. |
| Integrate hierarchical spatial decomposition | Implemented | Describe the quadtree, mass aggregation, Barnes-Hut traversal, theta, and degenerate leaves. |
| Investigate parallel and distributed execution | Planned | Literature investigation exists, but no parallel or distributed implementation is present. Keep this as future work or narrow the objective. |
| Support local and later web visualization | Partial | Native offline local 2D JSONL replay and inspection exists; the independent supported web viewer remains future work. |
| Parameterize through JSON, CSV, and GUI | Partial | Strict JSON input exists. CSV input and GUI-based configuration do not. Revise the objective or identify them as future work. |
| Compare performance, scalability, and trajectory divergence | Infrastructure implemented / evidence pending | Performance, force accuracy, conservation, convergence, and perturbed-trajectory tooling exist. The canonical evidence bundle and scientific analysis are still required. |

### 3.2 Functional requirements

| Requirement | Status | Current behavior / PDF update |
|---|---|---|
| RF01 — Define a body system | Implemented through JSON | Bodies can be declared with identifiers, mass, position, velocity, and acceleration. Interactive creation is not implemented. |
| RF02 — Enter simulation parameters | Partial | Strict JSON is supported. CSV and graphical entry are not supported. |
| RF03 — Execute the simulation | Implemented | The CLI advances deterministic simulation state for the configured number of steps. |
| RF04 — Calculate physical interactions | Implemented | Direct and Barnes-Hut gravitational acceleration are available. |
| RF05 — Apply optimization methods | Implemented for Barnes-Hut | Hierarchical approximation is available. Parallel optimization is not. |
| RF06 — Visualize the simulation | Implemented as offline replay | The local viewer replays exported states. It is not a live simulation controller. |
| RF07 — Export data | Implemented | Simulation frames and raw benchmark samples use JSONL; benchmark aggregates use CSV. |
| RF08 — Compare approaches | Infrastructure implemented; results pending | Both solvers and theta sweeps can be compared for runtime, work, and instantaneous force error; separate paired runs assess trajectory sensitivity. The thesis dataset remains to be generated. |

### 3.3 Nonfunctional requirements

| Requirement | Status | Current behavior / PDF update |
|---|---|---|
| RNF01 — Computational performance | Evidence pending | The engine and benchmark path exist, but acceptable performance must be established from measured experiments. |
| RNF02 — Parallel execution support | Planned | No threads, processes, or distributed execution are implemented. Do not present this as achieved. |
| RNF03 — Portability | Partial | The headless engine and native local replay are separated. A dedicated supported web application is not implemented. |
| RNF04 — Modularity | Implemented | Physics, spatial organization, integration, input, export, benchmarks, and viewing have separate ownership. |
| RNF05 — Extensibility | Implemented at the architecture level | Solver and integrator procedure contracts and stable exported frames allow later extensions. |
| RNF06 — Reproducibility | Implemented at the infrastructure level | Strict inputs, shared deterministic scenarios, raw records, summaries, run identifiers, a machine/compiler manifest, canonical fixtures, and a clean-revision experiment runner are available. Final experiments must still be executed and archived. |

## 4. Insertion-Ready English Material

The following text can be translated into Portuguese and adapted to the thesis template. Citations already used in the PDF should be retained where they support the corresponding statements.

### 4.1 Proposed revised abstract

This work presents the design and implementation of Sanxing, a modular two-dimensional N-body simulation engine written in Odin. The engine uses a headless architecture that separates physical simulation from visualization and supports strict JSON configuration, JSON Lines export, and deterministic experimental execution. Gravitational interactions can be calculated through a direct quadratic method or through the Barnes-Hut algorithm using a quadtree and a configurable opening threshold. Body states are advanced with the semi-implicit Euler method. A standalone local viewer consumes exported frames and replays simulations without duplicating physical behavior. The experimental infrastructure records execution time, direct and approximated interactions, quadtree traversal work, instantaneous acceleration error, trajectory divergence, energy, and momentum. A canonical pipeline captures execution provenance and generates aggregate tables and figures for solver, threshold, convergence, and sensitivity analyses. The implementation establishes a reproducible basis for evaluating the performance-accuracy tradeoff of hierarchical approximation. Parallel and distributed execution, live visualization, and a web viewer remain subjects for future work.

Suggested keywords: N-body problem; physics engine; Barnes-Hut algorithm; quadtree; numerical simulation; performance evaluation.

### 4.2 Methodology update

The research was conducted as an applied experimental software project. Development proceeded incrementally, beginning with a direct gravitational solver used as a behavioral and accuracy reference. The physical state, validation, numerical integration, and data-export mechanisms were implemented in an independent headless core. A two-dimensional quadtree was then integrated with a Barnes-Hut solver to reduce the number of individual force contributions by approximating sufficiently distant groups of bodies.

Both solvers use identical initial conditions, configuration values, and integration behavior. This separation makes performance differences attributable to the force-calculation strategy rather than to different state-update rules. Barnes-Hut approximation accuracy is evaluated separately by comparing acceleration vectors before integration.

The scaling scenario is generated deterministically so every solver and theta configuration begins from the same body distribution. Each configuration receives unrecorded warmups followed by repeated timed samples. Timed execution excludes JSONL frame export and work-counter instrumentation. Solver work is measured once during a separate deterministic replay. Raw samples are stored as schema-versioned JSONL, and the current invocation can be aggregated into CSV with timing variability, work, and speedup metrics.

The canonical serial evaluation uses 100, 500, 1,000, 5,000, and 10,000 bodies when supported by the test hardware; 10 integration steps; ten timed samples; two warmups; brute force; and Barnes-Hut theta values of 0.25, 0.5, and 1.0. A separate force-accuracy sweep evaluates theta values 0, 0.25, 0.5, and 1.0 against direct acceleration. Two-body orbital runs evaluate timestep convergence and conservation, while paired perturbed Burrau runs investigate sensitivity to initial conditions at two timesteps. The experiment manifest records the Git revision, dirty state, Odin version, platform, machine, processor, Python version, and declared performance matrix.

### 4.3 Implementation section

Sanxing was implemented in Odin using only the language's standard library. The command-line application exposes separate simulation and benchmark workflows. The simulation workflow parses and validates a JSON input, initializes the state, selects the configured solver, calculates acceleration, integrates velocity and position, and optionally exports the initial and subsequent states to JSONL.

The direct solver iterates over every ordered pair of distinct bodies and therefore performs `N(N-1)` source contributions per step. It serves both as a functional solver and as the reference for evaluating the approximation introduced by Barnes-Hut.

The Barnes-Hut implementation builds a square quadtree from the current body positions at each solver step. Node mass and center of mass are accumulated during insertion. During traversal, a node that does not contain the target body can be approximated as a single source when the ratio between its width and its softened distance from the target is lower than theta. Nodes that do not satisfy this criterion are traversed recursively. Leaves evaluate their stored bodies directly.

To handle degenerate spatial distributions, leaves may retain multiple body indices after the configured maximum subdivision depth or minimum region size is reached. This preserves coincident and nearly coincident bodies and allows an exact Barnes-Hut traversal (`theta = 0`) to reproduce the direct solver within the tested floating-point tolerance.

The numerical integrator uses semi-implicit Euler, updating velocity from the current acceleration before updating position from the new velocity. Although simple, this method provides a clearly defined and consistently shared integration rule for both solvers. The current study evaluates solver behavior under this fixed integrator rather than comparing multiple integration schemes.

Simulation diagnostics are exported separately from renderable frames. At every recorded state, the diagnostics path calculates kinetic energy, softened gravitational potential energy, total energy, and total linear momentum. This permits the numerical behavior of the integrator to be evaluated without adding analysis fields to the stable viewer frame contract.

Force approximation is also evaluated independently from trajectory divergence. The accuracy command computes both solvers on identical initial states before integration and reports normalized L2 acceleration error together with mean and maximum absolute error. This isolates the Barnes-Hut force approximation from accumulated integration error.

### 4.4 Visualization section

The visualization layer is intentionally independent from the simulation engine. The implemented native Odin/Raylib viewer loads JSONL files produced by the engine and replays their frames in a two-dimensional viewport. It provides playback and timeline controls, speed control, fitted camera bounds, pan and zoom, trails, labels, body selection, and complete body-state inspection.

The viewer does not calculate gravitational interactions, rebuild the quadtree, or integrate motion. This boundary prevents the interface from becoming a second physical implementation and allows exported simulations to be inspected reproducibly. The present viewer is an offline replay tool; live engine control, body editing, and a supported separate web viewer are outside the implemented scope.

### 4.5 Validation section

Automated engine tests cover vector operations, configuration validation, direct gravitational direction and magnitude, Barnes-Hut solver selection, tight-theta equivalence, coincident bodies, approximation counters, quadtree construction and aggregation, boundary positions, semi-implicit Euler update order and timestep convergence, JSONL frame structure, strict input validation, deterministic scenario generation and cloning, energy, momentum, divergence, force-error metrics, command-line option validation, work metrics, theta-zero controls, comparison matrices, CSV aggregation, and output-path safety.

At the documented checkpoint, the engine and native viewer passed static checking, all engine package tests passed, and all three replay-parser tests passed. End-to-end smoke execution confirmed `steps + 1` frames and diagnostics records, schema-v3 benchmark JSONL/CSV, force-accuracy JSONL/CSV, and deterministic analysis artifacts.

### 4.6 Limitations and future work

The current model is two-dimensional, uses a single semi-implicit Euler integrator, and executes serially. Barnes-Hut performance and error depend on theta and on the spatial distribution of bodies. Energy and momentum diagnostics are available, but definitive conservation results still depend on executing and analyzing the canonical clean-revision runs. The native local viewer replays completed exports and is not connected live to the engine. CSV simulation input, graphical body editing, a supported separate web viewer, parallel execution, distributed execution, WASM integration, and 3D visualization have not been implemented.

Future work should first complete and analyze the serial experiment matrix. After the serial implementation and measurement method are validated, the project can investigate a reusable live engine session, graphical configuration, parallel solver execution, alternative numerical integrators, additional initial-condition families, and an independent supported web replay interface.

### 4.7 Conclusion outline to complete after experiments

The final conclusion should:

1. Restate that the modular headless engine, direct solver, Barnes-Hut solver, export contract, replay viewer, and comparison infrastructure were implemented.
2. Answer whether and from which body count Barnes-Hut outperformed brute force on the declared environment.
3. Explain how theta changed runtime, interaction count, and instantaneous acceleration error.
4. State whether the measured results support the proposal's hierarchical-decomposition hypothesis.
5. Avoid drawing conclusions about parallel or distributed execution because those strategies were not implemented.
6. Summarize limitations and identify the next experiment or implementation milestone.

## 5. Experimental Evidence Still Required

The following work must be completed before writing the definitive results and conclusion sections:

1. Commit or otherwise establish the exact clean Git revision to be evaluated.
2. Run the canonical experiment script with a new, nonexistent results directory.
3. Preserve the generated manifest, exact command, run identifier, raw JSONL, summary CSV, trajectories, diagnostics, report, figures, and any deviations from the declared matrix.
4. Inspect failed or impractical scale points and report them rather than silently removing them.
5. Create a performance table containing body count, solver, theta, timing mean, timing standard deviation, speedup, direct interactions, approximated interactions, and node visits.
6. Plot runtime against body count for all solver/theta configurations.
7. Plot Barnes-Hut speedup relative to brute force.
8. Analyze normalized L2, mean absolute, and maximum absolute acceleration error against theta and body count.
9. Plot direct versus approximated interactions to connect runtime behavior with the algorithm's reduced work.
10. Report two-body orbital position error, energy error, and momentum norm for the three timesteps.
11. Analyze separation between base and perturbed Burrau trajectories and compare the two timesteps.
12. Discuss crossover behavior, variability, approximation/error tradeoffs, convergence, sensitivity, anomalous measurements, and hardware/compiler limitations.

Canonical experiment command:

```sh
tools/run_thesis_experiments.sh <new-results-directory>
```

Before the definitive run, replace any machine-specific placeholder label in the script if it does not describe the actual target. Do not describe the performance benchmark as measuring complete application runtime. It deliberately excludes export and instrumented profiling replays in order to measure the normal solver/integrator path. Likewise, distinguish instantaneous force error from accumulated trajectory sensitivity.

## 6. Tables and Figures to Add or Replace

### 6.1 Current architecture diagram

Replace the direct `Interface -> Simulation Engine` relationship with the implemented first-version flow:

```text
Strict JSON input
       |
       v
Headless Odin engine
  |-- input and validation
  |-- brute-force / Barnes-Hut solver
  |-- semi-implicit Euler
  |-- diagnostics, accuracy, benchmark, and comparison
       |
       +----> Simulation JSONL ----> Independent local 2D replay viewer
       |
       +----> Diagnostics / benchmark / accuracy JSONL
                                      |
                                      v
                           CSV summaries and SVG figures
```

Parallelization and the web viewer should be visually marked as future components, not active engine modules.

### 6.2 Suggested implementation figures

- Package/responsibility diagram for `core`, `input`, `solvers`, `spatial`, `integration`, `export`, and `benchmark`.
- Quadtree example showing node bounds, bodies, total mass, and center of mass.
- Barnes-Hut traversal decision showing `width / distance < theta`.
- Simulation data flow from JSON configuration to JSONL replay.
- Benchmark flow separating warmups, timed run, one-time work-profiling replay, raw record, and summary aggregation.
- Force-accuracy flow comparing direct and Barnes-Hut acceleration before integration.
- Diagnostics flow for energy and momentum alongside, but separate from, simulation frames.
- Screenshot of the implemented local replay viewer with a loaded simulation.

### 6.3 Suggested result figures

- Mean elapsed time versus body count, with variability.
- Barnes-Hut speedup versus body count for each theta.
- Direct and approximated contributions versus body count.
- Tree-node visits versus body count and theta.
- Normalized L2 acceleration error versus theta and body count.
- Normalized acceleration error versus theta and body count.
- Two-body orbit position and energy error versus timestep.
- Perturbed Burrau trajectory separation at both timesteps.
- A compact test and validation summary table.

## 7. Existing PDF Corrections

### 7.1 Structural corrections

- Replace every unresolved `Section ??` reference with the final section number.
- Add explicit implementation, experimental results, discussion, limitations, and conclusion sections.
- Change future-tense descriptions to past tense only for features verified in this dossier.
- Ensure the methodology distinguishes completed implementation from the experiment matrix that remains to be executed.
- Update diagrams and their explanations to match offline JSONL replay and the independent headless engine.

### 7.2 Scope corrections

- Do not imply that parallel or distributed processing has been implemented.
- Do not imply that the current interface configures or modifies bodies.
- Do not claim CSV simulation input; CSV currently exists only as benchmark summary output.
- Describe visualization as post-execution replay, not live presentation during solver execution.
- Describe the native Odin/Raylib viewer and its passing replay-parser tests as the implemented local visualization.
- Describe the web viewer, WASM, live coupling, 3D visualization, and distributed processing as future work.
- State that the active implementation is written in Odin; the removed Rust quadtree was only an early prototype.

### 7.3 Editorial and reference corrections

- Rewrite the English abstract for academic grammar and consistent terminology.
- Correct `Bayres-Hut` to `Barnes-Hut`.
- Remove accidental capitalization such as `PROBLEM` and `WITH`.
- Correct the duplicated `2026, 2026` in the Figure 3 attribution.
- Complete the missing years in the Nielsen Norman Group and Excalidraw citations if required by the selected citation standard.
- Correct the malformed Greengard URL beginning with `hhttps`.
- Check whether organization names used as authors comply with the institution's bibliography rules.
- Ensure every cited access date reflects the actual access date and that sources labeled 2026 genuinely have that publication year rather than only a 2026 access date.
- Standardize `N-body`, `N-corpos`, `Barnes-Hut`, `quadtree`, `JSON`, and `JSONL` terminology throughout the paper.
- Review the title: the implementation and experiments address the general N-body problem, not only the three-body problem.

## 8. Traceability and Source Links

Use these repository sources when revising the thesis:

- [Project overview](../README.md)
- [Engine usage and validation contract](../engine/README.md)
- [Architecture](architecture.md)
- [Simulation model](simulation-model.md)
- [JSONL and benchmark formats](jsonl-format.md)
- [Experiment plan](experiments-plan.md)
- [UI architecture and development plan](ui-development-plan.md)
- [Roadmap](roadmap.md)
- [Local viewer documentation](../viewers/local/README.md)
- [Example simulation input](../engine/examples/simple_system.json)
- [`accuracy` experiment package](../engine/src/accuracy/accuracy.odin)
- [`diagnostics` package](../engine/src/diagnostics/diagnostics.odin)
- [Shared deterministic scenarios](../engine/src/scenarios/scenarios.odin)
- [Canonical experiment runner](../tools/run_thesis_experiments.sh)
- [Experiment analyzer](../tools/analyze_experiments.py)

## 9. Final Thesis Update Checklist

- [ ] Replace the abstract and correct its terminology.
- [ ] Update the introduction's document-organization paragraph and resolve all section references.
- [ ] Convert completed methodology steps from future to past tense.
- [ ] Add the actual Odin implementation and package architecture.
- [ ] Document strict JSON validation and the simulation input schema.
- [ ] Document softened direct gravity and semi-implicit Euler.
- [ ] Document quadtree construction, Barnes-Hut theta, and degenerate leaves.
- [ ] Document simulation and diagnostics JSONL, benchmark JSONL schema version 3, accuracy JSONL, and CSV summaries.
- [ ] Document force-accuracy, conservation, timestep-convergence, and perturbed-trajectory methods.
- [ ] Update the architecture, behavior, activity, and sequence diagrams to match offline replay and current package ownership.
- [ ] Add an implemented-viewer screenshot and replace claims of live interaction.
- [ ] Add the passing engine and native replay-parser test totals from the final verification run.
- [ ] Execute and archive the full experiment matrix with environment metadata.
- [ ] Add result tables and plots based on the archived outputs.
- [ ] Analyze timing variability, speedup, work reduction, force error, trajectory sensitivity, and crossover points.
- [ ] Write the conclusion from measured evidence.
- [ ] Move parallelism, distribution, web viewing, live coupling, and 3D visualization to future work unless they are implemented later.
- [ ] Correct incomplete citations, malformed links, duplicated dates, and inconsistent terminology.
