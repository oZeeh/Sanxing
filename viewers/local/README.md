# Local Viewer

The local viewer consumes JSONL frames exported by the headless Odin engine. It is a standalone 2D replay tool and does not own solver, integrator, or state update behavior.

Open `index.html` directly in a browser, then load a `.jsonl` file produced by:

```sh
odin run engine/src -- simulate engine/examples/simple_system.json /tmp/sanxing-simple.jsonl
```

Current controls:

- load a local JSONL file
- play and pause replay
- step forward and backward
- scrub with the timeline
- show current frame, step, time, and body count

Physics logic remains in `engine/src`.
