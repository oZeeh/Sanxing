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
- theta
- average position divergence against brute force
- max position divergence against brute force
- compiler target and optimization mode

The first comparison is brute-force scaling across body counts. Barnes-Hut benchmark runs should use the same deterministic initial conditions as brute force and record both runtime and accuracy/divergence data.
