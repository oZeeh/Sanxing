# Experiments Plan

Initial scale points:

- 100 bodies
- 500 bodies
- 1000 bodies
- 5000 bodies
- 10000 bodies if hardware allows

Metrics:

- total runtime
- average step time
- frames written
- output size
- body count
- solver
- compiler target and optimization mode

The first comparison is brute-force scaling across body counts. Later Barnes-Hut work must include both runtime comparison and accuracy/divergence comparison against brute force on shared initial conditions.
