# Thesis Scope Reconciliation

The repository implementation and the current thesis PDF differ in several places. Apply these corrections to the editable manuscript when its source becomes available.

## Accepted Version-One Scope

- Configuration input is strict JSON. CSV input and graphical body/config editing are future live-viewer work.
- The evaluated engine is serial. Parallel and distributed execution are future work after the serial baseline is validated.
- Local visualization is the native Odin/Raylib replay and inspection viewer.
- The browser application is an unsupported prototype; a supported web viewer is future work.
- Visualization is 2D. WASM, WebSockets, and 3D are outside the thesis implementation scope.

## Experimental Claims

- Performance evidence compares brute force and Barnes-Hut across body counts and theta values.
- Barnes-Hut approximation accuracy is measured from acceleration vectors before integration.
- Semi-implicit Euler is retained and evaluated through timestep refinement and conservation diagnostics.
- The softened Burrau experiment demonstrates observed sensitivity and timestep dependence; it is not presented as an exact trajectory or Lyapunov-exponent calculation.

## Manuscript Sections to Update

Revise the objectives, RF02, RNF02, hypothesis, methodology, architecture discussion, experiment section, result analysis, limitations, and future-work section so they match the scope above. Do not claim that CSV input, live graphical configuration, parallelism, distributed execution, or a production web viewer were implemented.
