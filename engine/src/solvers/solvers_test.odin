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
		theta = 0.5,
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
test_barnes_hut_empty_system_ok :: proc(t: ^testing.T) {
	bodies: [0]simcore.Body
	status := barnes_hut(bodies[:], simcore.SimulationConfig{theta = 0.5})
	testing.expect_value(t, status, simcore.Step_Status.ok)
}

@(test)
test_barnes_hut_matches_brute_force_with_tight_theta :: proc(t: ^testing.T) {
	brute_bodies := [?]simcore.Body{
		{id = "a", mass = 1.0, position = simcore.vec2(-1, 0.1)},
		{id = "b", mass = 2.0, position = simcore.vec2(2, -0.2)},
		{id = "c", mass = 0.5, position = simcore.vec2(0.2, 1.5)},
		{id = "d", mass = 1.5, position = simcore.vec2(-0.4, -1.2)},
	}
	tree_bodies := brute_bodies
	config := simcore.SimulationConfig{
		gravitational_constant = 1,
		delta_time = 1,
		steps = 1,
		softening = 0.001,
		theta = 1e-12,
		solver = .barnes_hut,
	}

	brute_status := brute_force(brute_bodies[:], config)
	tree_status := barnes_hut(tree_bodies[:], config)

	testing.expect_value(t, brute_status, simcore.Step_Status.ok)
	testing.expect_value(t, tree_status, simcore.Step_Status.ok)
	for body, i in brute_bodies {
		testing.expect(t, almost_equal(tree_bodies[i].acceleration.x, body.acceleration.x))
		testing.expect(t, almost_equal(tree_bodies[i].acceleration.y, body.acceleration.y))
	}
}

@(test)
test_get_solver_returns_barnes_hut :: proc(t: ^testing.T) {
	solver := get_solver(.barnes_hut)
	bodies: [0]simcore.Body
	status := solver(bodies[:], simcore.SimulationConfig{theta = 0.5})
	testing.expect_value(t, status, simcore.Step_Status.ok)
}
