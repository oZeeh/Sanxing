# UI Development Plan

This document defines the visualization layer plan for Sanxing, an undergraduate thesis project for a modular N-body physics simulation engine. The thesis proposal in `docs/TCC___Engine_de_Simulação_do_Problema_dos_3_Corpos.pdf` is the academic source of truth for project scope, terminology, architecture, methodology, and planned experiments.

Sanxing must remain an Odin-first headless engine. Visualization exists to inspect, replay, validate, compare, and present simulation results; it must not own physics behavior.

## Architecture Boundary

Sanxing is split into three independent worlds:

- Headless engine: owns simulation state, input validation, solvers, numerical integration, JSONL export, benchmark records, and experiment contracts.
- Local visualization: consumes exported or engine-provided simulation frames and renders them with a native 2D UI.
- Web visualization: future independent viewer that consumes the same stable JSONL frame contract.

The UI must never calculate gravitational forces, update body positions with its own physics rules, implement Barnes-Hut, implement quadtree solver logic, or duplicate integrator behavior. Brute-force calculation, Barnes-Hut, quadtree construction, softening, time stepping, acceleration updates, velocity updates, position updates, exports, and benchmarks belong in `engine/src`.

The engine must run without any viewer. Viewers may depend on stable engine outputs or public engine APIs; the engine must not depend on Raylib, raygui, Vite, PixiJS, Canvas, browser APIs, or viewer-specific types.

Visualization stays 2D for the first version. WebSocket live frames, WASM integration, distributed execution visualization, and 3D visualization are future work.

## Shared Frame Contract

The first shared contract is the engine JSONL simulation frame format documented in `docs/jsonl-format.md` and written by `engine/src/export/jsonl.odin`.

Expected simulation frame:

```json
{
  "step": 0,
  "time": 0.0,
  "bodies": [
    {
      "id": "body_1",
      "mass": 1000.0,
      "position": { "x": 0.0, "y": 0.0 },
      "velocity": { "x": 0.0, "y": 1.0 },
      "acceleration": { "x": 0.0, "y": 0.0 }
    }
  ]
}
```

Shared UI concepts:

- `SimulationFrame`: one exported engine state with `step`, `time`, and body snapshots.
- `BodyFrame`: per-body snapshot with `id`, `mass`, `position`, `velocity`, and `acceleration`.
- `Camera`: 2D view transform with pan, zoom, and world-to-screen conversion.
- `RenderedBody`: display-only projection of a `BodyFrame`, including screen position, radius, color, label visibility, and selection state.
- `EventLog`: viewer-owned UI log for file loading, playback state, selection, export actions, and non-physics errors.
- Timeline/replay state: current frame index, playback mode, playback speed, loaded frame count, and end-of-file state.

Viewer-specific fields such as colors, body radius, trail length, selection status, labels, camera state, timeline state, and UI events are rendering concerns. They must not be written back as physics state or used to alter solver output.

## Local Viewer Plan

Use Raylib + raygui for the local viewer. The first local viewer should be a JSONL replay tool, not a tightly coupled live simulation UI. This validates the engine export format, preserves the headless architecture, and supports thesis demonstrations using reproducible exported runs.

Recommended structure:

```text
viewers/
  local/
    README.md
    src/
      main.odin
      renderer.odin
      camera.odin
      ui.odin
      replay.odin
      colors.odin
```

Phase 1: Static JSONL replay

- Load JSONL simulation frames produced by the engine.
- Parse each line as a `SimulationFrame`.
- Render bodies in 2D.
- Support play, pause, step forward, and step backward.
- Show current step and simulated time.

Phase 2: Live engine view

- Initialize a simulation from engine-compatible config.
- Call engine step functions through a clean engine API.
- Render the current engine state.
- Keep all solver and integrator behavior inside `engine/src`.

Phase 3: Interaction and inspection

- Add camera pan and zoom.
- Add body trails.
- Add body labels.
- Add click/select body support.
- Show selected body mass, position, velocity, and acceleration.

Phase 4: Export and comparison support

- Trigger or save JSONL exports through engine-owned export behavior.
- Load previous runs.
- Support later visual comparison between solver outputs, especially brute-force and Barnes-Hut runs over shared initial conditions.

## Web Viewer Plan

The web viewer is future work. Do not implement it until there is a specific task for it. Its first version should be an independent JSONL player, not a live engine clone.

Use TypeScript + Vite. Prefer PixiJS if the implementation needs better 2D rendering performance with many bodies. Canvas 2D is acceptable for a smaller first version.

Recommended structure:

```text
viewers/
  web/
    README.md
    package.json
    index.html
    src/
      main.ts
      renderer/
        pixiRenderer.ts
        camera.ts
      replay/
        jsonlParser.ts
        timeline.ts
      ui/
        controls.ts
        panels.ts
      types/
        frame.ts
```

Phase 1: JSONL player

- Load a local JSONL file.
- Parse frames.
- Render particles in 2D.
- Support play and pause.
- Add a timeline slider.
- Add playback speed control.

Phase 2: Visualization controls

- Add trails.
- Add labels.
- Add zoom and pan.
- Add body scale controls.

Phase 3: Experiment visualization

- Compare brute-force and Barnes-Hut outputs.
- Show divergence metrics if the engine exports them.
- Support screenshots or visual assets for the thesis.

Phase 4: Future integration

- WebSocket live frames.
- WASM integration.
- Distributed execution visualization.
- 3D visualization.

Phase 4 items are not first-version requirements.

## Development Order

1. Define and protect the shared frame contract.
2. Implement and test JSONL export in the engine.
3. Create the local JSONL replay viewer.
4. Add camera, zoom, and pan.
5. Add play, pause, and timeline controls.
6. Add trails and labels.
7. Add body inspection.
8. Add live local engine execution through engine APIs.
9. Create the web JSONL replay viewer.
10. Add experiment comparison features.

## Success Criteria

- The engine runs without any viewer.
- The local viewer can replay engine-produced JSONL.
- The future web viewer can consume the same JSONL format.
- No physics logic is duplicated in the UI.
- The UI supports thesis validation, experiments, and presentation.
- The documentation protects the architecture from future accidental coupling.

## Documentation Rules

Update this document when changing UI architecture, viewer ownership, frame contracts, replay behavior, live engine integration, or experiment comparison support. Update `docs/jsonl-format.md` whenever the JSONL frame shape changes.
