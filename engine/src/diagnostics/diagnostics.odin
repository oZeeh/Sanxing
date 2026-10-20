package diagnostics

import simcore "../core"
import "core:math"

Snapshot :: struct {
	kinetic_energy:   f64,
	potential_energy: f64,
	total_energy:     f64,
	momentum:         simcore.Vec2,
}

snapshot :: proc(bodies: []simcore.Body, config: simcore.SimulationConfig) -> Snapshot {
	result: Snapshot
	for body in bodies {
		result.kinetic_energy += 0.5 * body.mass * simcore.vec2_length_sq(body.velocity)
		result.momentum = simcore.vec2_add(result.momentum, simcore.vec2_scale(body.velocity, body.mass))
	}
	for i in 0 ..< len(bodies) {
		for j in i + 1 ..< len(bodies) {
			delta := simcore.vec2_sub(bodies[j].position, bodies[i].position)
			distance := math.sqrt(simcore.vec2_length_sq(delta) + config.softening * config.softening)
			if distance > 0 {
				result.potential_energy -= config.gravitational_constant * bodies[i].mass * bodies[j].mass / distance
			}
		}
	}
	result.total_energy = result.kinetic_energy + result.potential_energy
	return result
}

position_divergence :: proc(candidate, baseline: []simcore.Body) -> (f64, f64, bool) {
	if len(candidate) == 0 || len(candidate) != len(baseline) { return 0, 0, false }
	total, maximum := 0.0, 0.0
	for body, i in candidate {
		if body.id != baseline[i].id { return 0, 0, false }
		distance := simcore.vec2_length(simcore.vec2_sub(body.position, baseline[i].position))
		total += distance
		if distance > maximum { maximum = distance }
	}
	return total / f64(len(candidate)), maximum, true
}
