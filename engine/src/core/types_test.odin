package core

import "core:testing"

almost_equal :: proc(a, b: f64) -> bool {
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff < 1e-9
}

@(test)
test_vec2_math :: proc(t: ^testing.T) {
	a := vec2(3, 4)
	b := vec2(1, -2)

	testing.expect_value(t, vec2_add(a, b), vec2(4, 2))
	testing.expect_value(t, vec2_sub(a, b), vec2(2, 6))
	testing.expect_value(t, vec2_scale(b, 3), vec2(3, -6))
	testing.expect(t, almost_equal(vec2_length(a), 5.0))

	n := vec2_normalize(a)
	testing.expect(t, almost_equal(n.x, 0.6))
	testing.expect(t, almost_equal(n.y, 0.8))
}

@(test)
test_validate_config :: proc(t: ^testing.T) {
	config := SimulationConfig{
		gravitational_constant = 1,
		delta_time = 0.1,
		steps = 1,
		softening = 0,
		solver = .brute_force,
		export_enabled = true,
	}

	testing.expect(t, validate_config(config))
	config.delta_time = 0
	testing.expect(t, !validate_config(config))
}
