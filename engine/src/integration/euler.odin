package integration

import simcore "../core"

semi_implicit_euler :: proc(bodies: []simcore.Body, config: simcore.SimulationConfig) {
	dt := config.delta_time
	for &body in bodies {
		body.velocity = simcore.vec2_add(body.velocity, simcore.vec2_scale(body.acceleration, dt))
		body.position = simcore.vec2_add(body.position, simcore.vec2_scale(body.velocity, dt))
	}
}
