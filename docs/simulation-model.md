# Simulation Model

The state model is a list of bodies plus a current `step` and `time`.

Each `Body` has:

- `id`
- `mass`
- `position`
- `velocity`
- `acceleration`

The brute-force solver computes acceleration on every body `i` from every other body `j`.

```text
delta = position_j - position_i
distance_sq = dot(delta, delta) + softening * softening
acceleration_i += delta * (G * mass_j / (distance_sq * sqrt(distance_sq)))
```

Softening prevents singularities when bodies are very close. It is part of the model and must be recorded in input configuration.

Integration currently uses semi-implicit Euler:

```text
velocity += acceleration * delta_time
position += velocity * delta_time
```

The engine does not impose real-world units. Inputs are unit-consistent values chosen by the experiment.
