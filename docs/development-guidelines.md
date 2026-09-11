# Development Guidelines

- Prefer Odin stdlib first. Add third-party dependencies only when they remove meaningful complexity and are documented.
- Keep simulations deterministic for the same input, compiler target, and runtime settings.
- Avoid hidden mutable globals in solver, integrator, exporter, and benchmark paths.
- Update docs when changing JSON input, JSONL output, physics behavior, or package ownership.
- Keep module ownership clear: engine packages own physics and data contracts; viewers render exported state.
- Barnes-Hut and quadtree code must not claim correctness until compared against brute force.
- Benchmarks must report measured results only; do not commit placeholder numbers as real data.
