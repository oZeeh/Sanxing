package integration

import "core:testing"
import simcore "../core"
import "../diagnostics"
import "../solvers"
import "core:math"

almost_equal :: proc(a, b: f64) -> bool {
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff < 1e-9
}

orbit_error :: proc(step_count: int) -> (f64, f64) {
	speed := math.sqrt(0.5)
	period := math.PI * math.sqrt(2.0)
	bodies := [?]simcore.Body{
		{id = "a", mass = 1, position = simcore.vec2(-0.5, 0), velocity = simcore.vec2(0, -speed)},
		{id = "b", mass = 1, position = simcore.vec2(0.5, 0), velocity = simcore.vec2(0, speed)},
	}
	config := simcore.SimulationConfig{gravitational_constant = 1, delta_time = period / f64(step_count), steps = step_count, softening = 0, theta = 0, solver = .brute_force}
	initial_energy := diagnostics.snapshot(bodies[:], config).total_energy
	state := simcore.SimulationState{bodies = bodies[:]}
	for _ in 0 ..< step_count {
		if simcore.step_state(&state, config, solvers.brute_force, semi_implicit_euler) != .ok { return 1e300, 1e300 }
	}
	position_error := simcore.vec2_length(simcore.vec2_sub(bodies[0].position, simcore.vec2(-0.5, 0)))
	energy_error := math.abs(diagnostics.snapshot(bodies[:], config).total_energy - initial_energy)
	return position_error, energy_error
}

@(test)
test_circular_orbit_converges_when_timestep_is_halved :: proc(t: ^testing.T) {
	error_100, energy_100 := orbit_error(100)
	error_200, energy_200 := orbit_error(200)
	error_400, energy_400 := orbit_error(400)
	testing.expect(t, error_200 < error_100)
	testing.expect(t, error_400 < error_200)
	testing.expect(t, energy_200 < energy_100)
	testing.expect(t, energy_400 < energy_200)
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
