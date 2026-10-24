# Native Local Viewer

The canonical local viewer is an Odin/Raylib 2D JSONL replay and inspection application. It consumes engine exports and contains no solver or integrator behavior.

Run with a file:

```sh
./sanxing view /tmp/sanxing-simple.jsonl
```

To simulate and then open the completed replay in one command:

```sh
./sanxing run engine/examples/simple_system.json
```

The launcher retains and prints its unique temporary replay path. This is sequential orchestration, not
live coupling: the viewer opens only after the headless engine finishes. The direct viewer command
`odin run viewers/local/src -- /tmp/sanxing-simple.jsonl` remains supported.

Or start without an argument and use the path field or drag-and-drop. Controls include playback, frame stepping, timeline seeking, speed, fit, middle-button pan, wheel zoom, trails, labels, and body inspection.

Verify the pure replay layer and viewer build:

```sh
odin test viewers/local/src/replay
odin check viewers/local/src
```

The viewer's `FrameSource` boundary is prepared for a future live engine adapter, but live execution and graphical simulation editing are not implemented yet.
