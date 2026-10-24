# Experiments Plan

Sanxing separates performance, solver approximation error, numerical integration validity, and trajectory sensitivity. Late-time positional divergence is not treated as a direct Barnes-Hut force-error measurement.

## Canonical Execution

Definitive results must come from a clean Git revision:

```sh
tools/run_thesis_experiments.sh experiments/results/<UTC-date>-<short-commit>
```

The runner refuses an existing output directory or dirty worktree. It records the Git revision, Odin version, timestamp, platform, processor, commands, optimization mode, and complete matrix in `manifest.json`. Raw data, summaries, trajectories, diagnostics, SVG plots, and a Markdown report remain together in that result bundle.

## Performance Suite

- Scenario: `scaling_golden_angle_v1`.
- Bodies: `100,500,1000,5000,10000`.
- Solvers: brute force and Barnes-Hut.
- Barnes-Hut theta: `0.25,0.5,1.0`.
- Workload: 10 integration steps, 10 timed samples, and 2 warmups per configuration.
- Build: `-o:speed`.
- Metrics: mean, sample standard deviation, minimum and maximum elapsed time, mean step time, speedup, direct and approximated interactions, node visits, and interactions per second.

The scenario is a deterministic scaling workload. Its trajectory is not used as an accuracy claim. Timed samples contain only normal solver and integrator work; solver-work profiling occurs once per configuration outside timing.

## Force-Accuracy Suite

The `accuracy` command compares accelerations from Barnes-Hut and brute force on identical initial snapshots without integration:

- Scenario: `force_accuracy_golden_angle_v1`.
- Bodies: `100,500,1000,5000,10000`.
- Theta: `0,0.25,0.5,1.0`.
- Metrics: normalized L2 acceleration error, mean absolute vector error, maximum absolute vector error, and solver-work counters.
- Exact control: theta zero must remain below normalized error `1e-12`.

## Integrator and Sensitivity Suites

The two-body circular-orbit fixtures run one period at 100, 200, and 400 steps. Semi-implicit Euler is retained; the evidence reports phase error, total-energy drift, and momentum drift and verifies that errors decrease as the timestep is refined.

The softened Burrau/Pythagorean fixtures use masses `3,4,5`, zero initial velocities, `G=1`, softening `0.001`, and base/perturbed initial positions differing by `1e-10` in the mass-3 x-coordinate. Brute-force runs use timesteps `0.001` and `0.0005` through simulated time 20. The analysis reports observed separation and timestep dependence, not an exact or Lyapunov reference solution.

## Analysis

`tools/analyze_experiments.py` uses only the Python standard library. It produces:

- runtime plots with standard-deviation error bars and speedup plots;
- Barnes-Hut direct/approximated interaction, tree-visit, and force-error plots;
- Euler position-convergence, energy-drift, and momentum-drift tables/plots;
- full trajectory-separation CSV and a downsampled SVG;
- a concise report with key numeric findings, anomaly warnings, and interpretation limits.

After analysis, the runner validates the expected matrix and artifact set. A successful bundle is marked
`complete` in `manifest.json`, which also records file sizes and SHA-256 digests. An interrupted or
incomplete run remains marked `running` and must not be treated as definitive evidence.

Do not commit measurements as representative thesis results without their manifest. A run from a dirty tree is a pilot even if all commands succeed.
