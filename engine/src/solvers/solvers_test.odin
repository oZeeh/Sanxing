package solvers

import simcore "../core"
import "core:testing"

almost_equal :: proc(a, b: f64) -> bool {
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff < 1e-9
}

@(test)
test_brute_force_two_body_direction_and_magnitude :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body {
		{id = "a", mass = 1, position = simcore.vec2(0, 0)},
		{id = "b", mass = 2, position = simcore.vec2(2, 0)},
	}
	config := simcore.SimulationConfig {
		gravitational_constant = 1,
		delta_time             = 1,
		steps                  = 1,
		softening              = 0,
		theta                  = 0.5,
		solver                 = .brute_force,
	}

	stats: simcore.Solver_Stats
	status := brute_force(bodies[:], config, &stats)

	testing.expect_value(t, status, simcore.Step_Status.ok)
	testing.expect(t, almost_equal(bodies[0].acceleration.x, 0.5))
	testing.expect(t, almost_equal(bodies[0].acceleration.y, 0))
	testing.expect(t, almost_equal(bodies[1].acceleration.x, -0.25))
	testing.expect(t, almost_equal(bodies[1].acceleration.y, 0))
	testing.expect_value(t, stats.direct_interactions, i64(2))
	testing.expect_value(t, stats.approximated_interactions, i64(0))
}

@(test)
test_barnes_hut_empty_system_ok :: proc(t: ^testing.T) {
	bodies: [0]simcore.Body
	status := barnes_hut(bodies[:], simcore.SimulationConfig{theta = 0.5}, nil)
	testing.expect_value(t, status, simcore.Step_Status.ok)
}

@(test)
test_barnes_hut_matches_brute_force_with_tight_theta :: proc(t: ^testing.T) {
	brute_bodies := [?]simcore.Body {
		{id = "a", mass = 1.0, position = simcore.vec2(-1, 0.1)},
		{id = "b", mass = 2.0, position = simcore.vec2(2, -0.2)},
		{id = "c", mass = 0.5, position = simcore.vec2(0.2, 1.5)},
		{id = "d", mass = 1.5, position = simcore.vec2(-0.4, -1.2)},
	}
	tree_bodies := brute_bodies
	config := simcore.SimulationConfig {
		gravitational_constant = 1,
		delta_time             = 1,
		steps                  = 1,
		softening              = 0.001,
		theta                  = 1e-12,
		solver                 = .barnes_hut,
	}

	brute_status := brute_force(brute_bodies[:], config, nil)
	tree_status := barnes_hut(tree_bodies[:], config, nil)

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
	status := solver(bodies[:], simcore.SimulationConfig{theta = 0.5}, nil)
	testing.expect_value(t, status, simcore.Step_Status.ok)
}

@(test)
test_barnes_hut_coincident_bodies_match_brute_force :: proc(t: ^testing.T) {
	brute_bodies := [?]simcore.Body {
		{id = "a", mass = 1, position = simcore.vec2(0, 0)},
		{id = "b", mass = 2, position = simcore.vec2(0, 0)},
		{id = "c", mass = 3, position = simcore.vec2(1e-15, 0)},
	}
	tree_bodies := brute_bodies
	config := simcore.SimulationConfig {
		gravitational_constant = 1,
		delta_time             = 1,
		softening              = 0.001,
		theta                  = 0,
		solver                 = .barnes_hut,
	}

	brute_stats, tree_stats: simcore.Solver_Stats
	brute_status := brute_force(brute_bodies[:], config, &brute_stats)
	tree_status := barnes_hut(tree_bodies[:], config, &tree_stats)

	testing.expect_value(t, brute_status, simcore.Step_Status.ok)
	testing.expect_value(t, tree_status, simcore.Step_Status.ok)
	for body, i in brute_bodies {
		testing.expect(t, almost_equal(tree_bodies[i].acceleration.x, body.acceleration.x))
		testing.expect(t, almost_equal(tree_bodies[i].acceleration.y, body.acceleration.y))
	}
	testing.expect_value(t, tree_stats.direct_interactions, brute_stats.direct_interactions)
	testing.expect_value(t, tree_stats.approximated_interactions, i64(0))
}

@(test)
test_barnes_hut_reports_approximated_work :: proc(t: ^testing.T) {
	bodies := make([]simcore.Body, 64)
	defer delete(bodies)
	for i in 0 ..< len(bodies) {
		bodies[i].mass = 1
		bodies[i].position = simcore.vec2(f64(i % 8), f64(i / 8))
	}
	config := simcore.SimulationConfig {
		gravitational_constant = 1,
		delta_time             = 1,
		softening              = 0.001,
		theta                  = 1,
		solver                 = .barnes_hut,
	}
	stats: simcore.Solver_Stats
	status := barnes_hut(bodies, config, &stats)

	testing.expect_value(t, status, simcore.Step_Status.ok)
	testing.expect(t, stats.approximated_interactions > 0)
	testing.expect(t, stats.tree_node_visits > 0)
	testing.expect(
		t,
		stats.direct_interactions + stats.approximated_interactions <
		i64(len(bodies) * (len(bodies) - 1)),
	)
}
