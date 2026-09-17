package sim_input

import "core:strings"
import "core:testing"

has_error :: proc(result: ValidationResult, text: string) -> bool {
	for err in result.errors {
		if strings.contains(err, text) {
			return true
		}
	}
	return false
}

parse_test :: proc(text: string) -> (SimulationInput, ValidationResult, bool) {
	return parse_input(transmute([]byte)text)
}

@(test)
test_valid_simple_system :: proc(t: ^testing.T) {
	input, result, ok := load_input("engine/examples/simple_system.json")
	defer destroy_validation_result(&result)
	defer if ok {
		destroy_input(&input)
	}

	testing.expect(t, ok)
	testing.expect_value(t, len(input.bodies), 3)
	testing.expect_value(t, input.config.steps, 10)
	testing.expect_value(t, input.config.theta, 0.5)
}

@(test)
test_optional_theta :: proc(t: ^testing.T) {
	input, result, ok := parse_test(`{"config":{"gravitational_constant":1,"delta_time":1,"steps":0,"softening":0,"theta":0.7,"solver":"barnes_hut","export_enabled":true},"bodies":[{"id":"a","mass":1,"position":{"x":0,"y":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0}}]}`)
	defer destroy_validation_result(&result)
	defer if ok {
		destroy_input(&input)
	}

	testing.expect(t, ok)
	testing.expect_value(t, input.config.theta, 0.7)
}

@(test)
test_missing_required_fields :: proc(t: ^testing.T) {
	_, result, ok := parse_test(`{"config":{},"bodies":[]}`)
	defer destroy_validation_result(&result)

	testing.expect(t, !ok)
	testing.expect(t, has_error(result, "$.config.gravitational_constant: missing required field"))
	testing.expect(t, has_error(result, "$.bodies: must contain at least one body"))
}

@(test)
test_unknown_fields :: proc(t: ^testing.T) {
	_, result, ok := parse_test(`{"config":{"gravitational_constant":1,"delta_time":1,"steps":0,"softening":0,"solver":"brute_force","export_enabled":true,"extra":1},"bodies":[{"id":"a","mass":1,"position":{"x":0,"y":0,"z":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0},"extra":1}],"extra":1}`)
	defer destroy_validation_result(&result)

	testing.expect(t, !ok)
	testing.expect(t, has_error(result, "$.extra: unknown field"))
	testing.expect(t, has_error(result, "$.config.extra: unknown field"))
	testing.expect(t, has_error(result, "$.bodies[0].extra: unknown field"))
	testing.expect(t, has_error(result, "$.bodies[0].position.z: unknown field"))
}

@(test)
test_invalid_numeric_ranges :: proc(t: ^testing.T) {
	_, result, ok := parse_test(`{"config":{"gravitational_constant":-1,"delta_time":0,"steps":-1,"softening":-1,"theta":-1,"solver":"nope","export_enabled":"yes"},"bodies":[{"id":"a","mass":1,"position":{"x":0,"y":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0}}]}`)
	defer destroy_validation_result(&result)

	testing.expect(t, !ok)
	testing.expect(t, has_error(result, "$.config.gravitational_constant: must be >= 0"))
	testing.expect(t, has_error(result, "$.config.delta_time: must be > 0"))
	testing.expect(t, has_error(result, "$.config.steps: must be >= 0"))
	testing.expect(t, has_error(result, "$.config.softening: must be >= 0"))
	testing.expect(t, has_error(result, "$.config.theta: must be >= 0"))
	testing.expect(t, has_error(result, "$.config.solver: must be one of brute_force, barnes_hut"))
	testing.expect(t, has_error(result, "$.config.export_enabled: must be a boolean"))
}

@(test)
test_duplicate_ids_and_invalid_mass :: proc(t: ^testing.T) {
	_, result, ok := parse_test(`{"config":{"gravitational_constant":1,"delta_time":1,"steps":0,"softening":0,"solver":"brute_force","export_enabled":true},"bodies":[{"id":"a","mass":0,"position":{"x":0,"y":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0}},{"id":"a","mass":-1,"position":{"x":0,"y":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0}}]}`)
	defer destroy_validation_result(&result)

	testing.expect(t, !ok)
	testing.expect(t, has_error(result, "$.bodies[0].mass: must be > 0"))
	testing.expect(t, has_error(result, "$.bodies[1].id: must be unique"))
	testing.expect(t, has_error(result, "$.bodies[1].mass: must be > 0"))
}

@(test)
test_malformed_vectors :: proc(t: ^testing.T) {
	_, result, ok := parse_test(`{"config":{"gravitational_constant":1,"delta_time":1,"steps":0,"softening":0,"solver":"brute_force","export_enabled":true},"bodies":[{"id":"a","mass":1,"position":{"x":0},"velocity":{"x":"bad","y":0},"acceleration":0}]}`)
	defer destroy_validation_result(&result)

	testing.expect(t, !ok)
	testing.expect(t, has_error(result, "$.bodies[0].position.y: missing required field"))
	testing.expect(t, has_error(result, "$.bodies[0].velocity.x: must be a number"))
	testing.expect(t, has_error(result, "$.bodies[0].acceleration: must be an object"))
}
