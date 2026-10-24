# UI Development Plan

Sanxing remains an Odin-first headless engine. Visualization consumes exported state and never calculates forces, constructs quadtrees, integrates motion, or mutates engine physics.

## Current Native Viewer

`viewers/local/src` is the canonical local application and uses the Odin-distributed Raylib and raygui bindings. It provides:

- command-line, path-field, and drag-and-drop JSONL loading;
- strict required-field and finite-number validation with line-numbered errors;
- play, pause, stepping, timeline seeking, and speed control;
- stable fitted camera bounds, middle-button pan, wheel zoom, and reset;
- configurable trails and labels;
- body selection and inspection of mass, position, velocity, and acceleration.

The viewer stores immutable `SimulationFrame` and `BodyFrame` snapshots. Rendering and playback consume a `FrameSource` boundary with finite/seekable capability flags. `JsonlReplaySource` is the only implemented source.

## Future Live Operation

Live operation is deliberately deferred until the serial thesis results are accepted. Its implementation order is:

1. Extract CLI orchestration into a reusable engine session package owning configuration validation, solver choice, stepping, and export.
2. Add a `LiveEngineSource` adapter that converts engine state to immutable viewer frames.
3. Add graphical body/config editing and optional CSV import through engine-owned validation.
4. Preserve JSONL replay as an independent mode and keep the engine runnable without any viewer.

The source boundary exists now so live operation does not require renderer, camera, timeline, or inspector rewrites.

The repository launcher may run a simulation and open its finished replay as one user command. This
workflow remains offline and sequential; it is not the deferred `LiveEngineSource`.

## Web Prototype and Later Work

The previous standalone HTML replay tool is preserved at `viewers/web/prototype/index.html`. It is an unsupported prototype, not a second local viewer. A supported web viewer must remain independent, consume the documented simulation-frame contract, and begin as JSONL replay.

WebSocket streaming, WASM, distributed-execution visualization, and 3D are post-thesis work. First-version visualization remains 2D.

## Contract and Documentation Rules

- The engine never imports Raylib, raygui, browser, or viewer types.
- Viewers may ignore unknown frame fields but must require the documented core frame fields.
- UI colors, radii, trails, camera state, playback state, selection, and logs never become physics state.
- Update this file and `docs/jsonl-format.md` whenever ownership, frame shape, or replay/live behavior changes.
