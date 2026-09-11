package solvers

import "core:testing"
import simcore "../core"

almost_equal :: proc(a, b: f64) -> bool {
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff < 1e-9
}

@(test)
test_brute_force_two_body_direction_and_magnitude :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body{
		{
			id = "a",
			mass = 1,
			position = simcore.vec2(0, 0),
		},
		{
			id = "b",
			mass = 2,
			position = simcore.vec2(2, 0),
		},
	}
	config := simcore.SimulationConfig{
		gravitational_constant = 1,
		delta_time = 1,
		steps = 1,
		softening = 0,
		solver = .brute_force,
	}

	status := brute_force(bodies[:], config)

	testing.expect_value(t, status, simcore.Step_Status.ok)
	testing.expect(t, almost_equal(bodies[0].acceleration.x, 0.5))
	testing.expect(t, almost_equal(bodies[0].acceleration.y, 0))
	testing.expect(t, almost_equal(bodies[1].acceleration.x, -0.25))
	testing.expect(t, almost_equal(bodies[1].acceleration.y, 0))
}

@(test)
test_barnes_hut_is_explicitly_unsupported :: proc(t: ^testing.T) {
	bodies: [0]simcore.Body
	status := barnes_hut(bodies[:], simcore.SimulationConfig{})
	testing.expect_value(t, status, simcore.Step_Status.unsupported_solver)
}
