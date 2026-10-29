# Sanxing Experiment Report — 20261027T225903Z-5053581

## Key findings

- Barnes-Hut theta=0.25 first outperformed brute force at N=5000.
- Barnes-Hut theta=0.5 first outperformed brute force at N=5000.
- Barnes-Hut theta=1 first outperformed brute force at N=500.
- Theta-zero maximum normalized L2 acceleration error was 4.40597e-15 (tolerance 1.0e-12).
- Orbital position error decreased at every timestep refinement.
- Maximum relative energy drift decreased at every timestep refinement.
- Maximum observed momentum-drift norm across orbit runs was 0.

## Warnings

- High timing variability (14.3%) for N=500, brute_force, theta=n/a.
- High timing variability (16.9%) for N=500, barnes_hut, theta=0.25.

## Generated evidence

- Runtime with standard-deviation error bars and speedup are in `figures/runtime.svg` and `figures/speedup.svg`.
- Direct/approximated work and traversal counts are in `figures/solver-work.svg` and `figures/tree-node-visits.svg`.
- Force approximation error is in `summary/accuracy.csv` and `figures/force-accuracy.svg`.
- Orbit convergence and conservation are in `summary/orbit-convergence.csv` and the three orbit figures.
- Perturbed trajectory separation is in `summary/trajectory-separation.csv` and its figure.

Timing covers the solver/integrator benchmark path, not complete application runtime. Force error compares accelerations on identical snapshots before integration. The Burrau result reports observed softened-system sensitivity and timestep dependence, not an exact reference trajectory.
