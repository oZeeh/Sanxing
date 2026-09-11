package integration

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
test_semi_implicit_euler_updates_velocity_then_position :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body{
		{
			id = "one",
			mass = 1,
			position = simcore.vec2(0, 0),
			velocity = simcore.vec2(1, 0),
			acceleration = simcore.vec2(2, 0),
		},
	}
	config := simcore.SimulationConfig{delta_time = 0.5}

	semi_implicit_euler(bodies[:], config)

	testing.expect(t, almost_equal(bodies[0].velocity.x, 2.0))
	testing.expect(t, almost_equal(bodies[0].position.x, 1.0))
}
