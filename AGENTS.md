# Sanxing Agent Notes

Sanxing is an Odin-first N-body simulation engine. Keep physics logic in `engine/src`; viewers must consume exported data and must not reimplement solver or integrator behavior.

Do not restore the old Rust/Cargo prototype unless the user explicitly asks for it. The current skeleton uses Odin stdlib only.

UI architecture rules:

- Do not put physics logic in viewers.
- Do not make the engine depend on viewers.
- Do not implement 3D visualization yet; keep first-version visualization 2D.
- Prefer JSONL replay before live engine coupling.
- Keep local and web viewers independent.
- Update docs when changing UI architecture.

Useful commands:

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
odin test viewers/local/src/replay
odin check viewers/local/src
odin run engine/src -- simulate engine/examples/simple_system.json /tmp/sanxing-simple.jsonl
odin run engine/src -- benchmark /tmp/sanxing-bench.jsonl
odin run engine/src -- accuracy /tmp/sanxing-accuracy.jsonl --counts 100 --thetas 0,0.5
```
