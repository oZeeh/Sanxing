package solvers

import "core:math"
import simcore "../core"

get_solver :: proc(kind: simcore.Solver_Type) -> simcore.Solver_Proc {
	switch kind {
	case .brute_force:
		return brute_force
	case .barnes_hut:
		return barnes_hut
	}
	return barnes_hut
}

brute_force :: proc(bodies: []simcore.Body, config: simcore.SimulationConfig) -> simcore.Step_Status {
	for &body in bodies {
		body.acceleration = simcore.vec2_zero()
	}

	for i in 0..<len(bodies) {
		accel := simcore.vec2_zero()
		for j in 0..<len(bodies) {
			if i == j {
				continue
			}

			delta := simcore.vec2_sub(bodies[j].position, bodies[i].position)
			distance_sq := simcore.vec2_length_sq(delta) + config.softening * config.softening
			if distance_sq == 0 {
				continue
			}

			scale := config.gravitational_constant * bodies[j].mass / (distance_sq * math.sqrt(distance_sq))
			accel = simcore.vec2_add(accel, simcore.vec2_scale(delta, scale))
		}
		bodies[i].acceleration = accel
	}

	return .ok
}

barnes_hut :: proc(bodies: []simcore.Body, config: simcore.SimulationConfig) -> simcore.Step_Status {
	return .unsupported_solver
}
