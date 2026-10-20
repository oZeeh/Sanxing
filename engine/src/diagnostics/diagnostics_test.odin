package diagnostics

import simcore "../core"
import "core:testing"

@(test)
test_two_body_energy_and_momentum :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body{
		{id = "a", mass = 1, position = simcore.vec2(-0.5, 0), velocity = simcore.vec2(0, -0.5)},
		{id = "b", mass = 1, position = simcore.vec2(0.5, 0), velocity = simcore.vec2(0, 0.5)},
	}
	value := snapshot(bodies[:], simcore.SimulationConfig{gravitational_constant = 1})
	testing.expect_value(t, value.kinetic_energy, 0.25)
	testing.expect_value(t, value.potential_energy, -1.0)
	testing.expect_value(t, value.total_energy, -0.75)
	testing.expect_value(t, value.momentum, simcore.vec2_zero())
}

@(test)
test_position_divergence_requires_matching_ids :: proc(t: ^testing.T) {
	a := [?]simcore.Body{{id = "a", position = simcore.vec2(1, 0)}}
	b := [?]simcore.Body{{id = "a", position = simcore.vec2(3, 0)}}
	mean, maximum, ok := position_divergence(a[:], b[:])
	testing.expect(t, ok)
	testing.expect_value(t, mean, 2.0)
	testing.expect_value(t, maximum, 2.0)
}
