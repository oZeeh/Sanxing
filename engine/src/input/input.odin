package sim_input

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import simcore "../core"

SimulationInput :: struct {
	config: simcore.SimulationConfig,
	bodies: []simcore.Body,
	source_data: []byte,
}

ValidationResult :: struct {
	errors: [dynamic]string,
}

destroy_validation_result :: proc(result: ^ValidationResult) {
	for err in result.errors {
		delete(err)
	}
	delete(result.errors)
}

destroy_input :: proc(input: ^SimulationInput) {
	for body in input.bodies {
		delete(body.id)
	}
	delete(input.bodies)
	delete(input.source_data)
	input^ = SimulationInput{}
}

add_error :: proc(result: ^ValidationResult, path, message: string) {
	append(&result.errors, fmt.aprintf("%s: %s", path, message))
}

is_finite :: proc(value: f64) -> bool {
	return !math.is_nan(value) && !math.is_inf(value)
}

as_object :: proc(value: json.Value) -> (json.Object, bool) {
	#partial switch v in value {
	case json.Object:
		return v, true
	}
	return nil, false
}

as_array :: proc(value: json.Value) -> (json.Array, bool) {
	#partial switch v in value {
	case json.Array:
		return v, true
	}
	return nil, false
}

as_string :: proc(value: json.Value) -> (string, bool) {
	#partial switch v in value {
	case json.String:
		return string(v), true
	}
	return "", false
}

as_bool :: proc(value: json.Value) -> (bool, bool) {
	#partial switch v in value {
	case json.Boolean:
		return bool(v), true
	}
	return false, false
}

as_f64 :: proc(value: json.Value) -> (f64, bool) {
	#partial switch v in value {
	case json.Float:
		return f64(v), true
	case json.Integer:
		return f64(v), true
	}
	return 0, false
}

as_int :: proc(value: json.Value) -> (int, bool) {
	#partial switch v in value {
	case json.Integer:
		return int(v), true
	}
	return 0, false
}

has_key :: proc(obj: json.Object, key: string) -> bool {
	_, ok := obj[key]
	return ok
}

check_unknown_keys :: proc(result: ^ValidationResult, obj: json.Object, path: string, allowed: []string) {
	for key in obj {
		known := false
		for allowed_key in allowed {
			if key == allowed_key {
				known = true
				break
			}
		}
		if !known {
			add_error(result, fmt.tprintf("%s.%s", path, key), "unknown field")
		}
	}
}

require_value :: proc(result: ^ValidationResult, obj: json.Object, path, key: string) -> (json.Value, bool) {
	value, ok := obj[key]
	if !ok {
		add_error(result, fmt.tprintf("%s.%s", path, key), "missing required field")
		return nil, false
	}
	return value, true
}

read_f64 :: proc(result: ^ValidationResult, obj: json.Object, path, key: string) -> (f64, bool) {
	value, ok := require_value(result, obj, path, key)
	if !ok {
		return 0, false
	}
	number, number_ok := as_f64(value)
	if !number_ok {
		add_error(result, fmt.tprintf("%s.%s", path, key), "must be a number")
		return 0, false
	}
	if !is_finite(number) {
		add_error(result, fmt.tprintf("%s.%s", path, key), "must be finite")
		return 0, false
	}
	return number, true
}

read_int :: proc(result: ^ValidationResult, obj: json.Object, path, key: string) -> (int, bool) {
	value, ok := require_value(result, obj, path, key)
	if !ok {
		return 0, false
	}
	number, number_ok := as_int(value)
	if !number_ok {
		add_error(result, fmt.tprintf("%s.%s", path, key), "must be an integer")
		return 0, false
	}
	return number, true
}

read_vec2 :: proc(result: ^ValidationResult, obj: json.Object, path, key: string) -> (simcore.Vec2, bool) {
	value, ok := require_value(result, obj, path, key)
	if !ok {
		return {}, false
	}
	vec_obj, obj_ok := as_object(value)
	vec_path := fmt.tprintf("%s.%s", path, key)
	if !obj_ok {
		add_error(result, vec_path, "must be an object")
		return {}, false
	}

	check_unknown_keys(result, vec_obj, vec_path, []string{"x", "y"})
	x, x_ok := read_f64(result, vec_obj, vec_path, "x")
	y, y_ok := read_f64(result, vec_obj, vec_path, "y")
	return simcore.vec2(x, y), x_ok && y_ok
}

read_config :: proc(result: ^ValidationResult, obj: json.Object) -> (simcore.SimulationConfig, bool) {
	config_value, ok := require_value(result, obj, "$", "config")
	if !ok {
		return {}, false
	}
	config_obj, obj_ok := as_object(config_value)
	if !obj_ok {
		add_error(result, "$.config", "must be an object")
		return {}, false
	}

	check_unknown_keys(result, config_obj, "$.config", []string{
		"gravitational_constant",
		"delta_time",
		"steps",
		"softening",
		"solver",
		"export_enabled",
	})

	config: simcore.SimulationConfig
	all_ok := true
	if value, value_ok := read_f64(result, config_obj, "$.config", "gravitational_constant"); value_ok {
		config.gravitational_constant = value
		if value < 0 {
			add_error(result, "$.config.gravitational_constant", "must be >= 0")
			all_ok = false
		}
	} else {
		all_ok = false
	}
	if value, value_ok := read_f64(result, config_obj, "$.config", "delta_time"); value_ok {
		config.delta_time = value
		if value <= 0 {
			add_error(result, "$.config.delta_time", "must be > 0")
			all_ok = false
		}
	} else {
		all_ok = false
	}
	if value, value_ok := read_int(result, config_obj, "$.config", "steps"); value_ok {
		config.steps = value
		if value < 0 {
			add_error(result, "$.config.steps", "must be >= 0")
			all_ok = false
		}
	} else {
		all_ok = false
	}
	if value, value_ok := read_f64(result, config_obj, "$.config", "softening"); value_ok {
		config.softening = value
		if value < 0 {
			add_error(result, "$.config.softening", "must be >= 0")
			all_ok = false
		}
	} else {
		all_ok = false
	}

	solver_value, solver_ok := require_value(result, config_obj, "$.config", "solver")
	if solver_ok {
		solver_name, string_ok := as_string(solver_value)
		if !string_ok {
			add_error(result, "$.config.solver", "must be a string")
			all_ok = false
		} else if solver_name == "brute_force" {
			config.solver = .brute_force
		} else if solver_name == "barnes_hut" {
			config.solver = .barnes_hut
		} else {
			add_error(result, "$.config.solver", "must be one of brute_force, barnes_hut")
			all_ok = false
		}
	} else {
		all_ok = false
	}

	export_value, export_ok := require_value(result, config_obj, "$.config", "export_enabled")
	if export_ok {
		export_enabled, bool_ok := as_bool(export_value)
		if !bool_ok {
			add_error(result, "$.config.export_enabled", "must be a boolean")
			all_ok = false
		} else {
			config.export_enabled = export_enabled
		}
	} else {
		all_ok = false
	}

	return config, all_ok
}

read_bodies :: proc(result: ^ValidationResult, obj: json.Object) -> ([]simcore.Body, bool) {
	start_error_count := len(result.errors)
	bodies_value, ok := require_value(result, obj, "$", "bodies")
	if !ok {
		return nil, false
	}
	body_array, array_ok := as_array(bodies_value)
	if !array_ok {
		add_error(result, "$.bodies", "must be an array")
		return nil, false
	}
	if len(body_array) == 0 {
		add_error(result, "$.bodies", "must contain at least one body")
		return nil, false
	}

	bodies := make([]simcore.Body, len(body_array))
	seen_ids := make(map[string]bool)
	defer delete(seen_ids)

	all_ok := true
	for body_value, i in body_array {
		body_path := fmt.tprintf("$.bodies[%d]", i)
		body_obj, obj_ok := as_object(body_value)
		if !obj_ok {
			add_error(result, body_path, "must be an object")
			all_ok = false
			continue
		}

		check_unknown_keys(result, body_obj, body_path, []string{
			"id",
			"mass",
			"position",
			"velocity",
			"acceleration",
		})

		id_value, id_ok := require_value(result, body_obj, body_path, "id")
		if id_ok {
			id, string_ok := as_string(id_value)
			if !string_ok {
				add_error(result, fmt.tprintf("%s.id", body_path), "must be a string")
				all_ok = false
			} else if id == "" {
				add_error(result, fmt.tprintf("%s.id", body_path), "must be nonempty")
				all_ok = false
			} else {
				if seen_ids[id] {
					add_error(result, fmt.tprintf("%s.id", body_path), "must be unique")
					all_ok = false
				}
				seen_ids[id] = true
				bodies[i].id = strings.clone(id)
			}
		} else {
			all_ok = false
		}

		if mass, mass_ok := read_f64(result, body_obj, body_path, "mass"); mass_ok {
			bodies[i].mass = mass
			if mass <= 0 {
				add_error(result, fmt.tprintf("%s.mass", body_path), "must be > 0")
				all_ok = false
			}
		} else {
			all_ok = false
		}

		if position, vec_ok := read_vec2(result, body_obj, body_path, "position"); vec_ok {
			bodies[i].position = position
		} else {
			all_ok = false
		}
		if velocity, vec_ok := read_vec2(result, body_obj, body_path, "velocity"); vec_ok {
			bodies[i].velocity = velocity
		} else {
			all_ok = false
		}
		if acceleration, vec_ok := read_vec2(result, body_obj, body_path, "acceleration"); vec_ok {
			bodies[i].acceleration = acceleration
		} else {
			all_ok = false
		}
	}

	if !all_ok || len(result.errors) > start_error_count {
		for body in bodies {
			delete(body.id)
		}
		delete(bodies)
		return nil, false
	}

	return bodies, true
}

parse_input :: proc(data: []byte) -> (SimulationInput, ValidationResult, bool) {
	result: ValidationResult
	root, parse_err := json.parse(data, .JSON, true)
	if parse_err != nil {
		add_error(&result, "$", fmt.tprintf("invalid JSON: %v", parse_err))
		return {}, result, false
	}
	defer json.destroy_value(root)

	root_obj, root_ok := as_object(root)
	if !root_ok {
		add_error(&result, "$", "must be an object")
		return {}, result, false
	}

	check_unknown_keys(&result, root_obj, "$", []string{"config", "bodies"})
	config, config_ok := read_config(&result, root_obj)
	bodies, bodies_ok := read_bodies(&result, root_obj)
	if len(result.errors) > 0 || !config_ok || !bodies_ok {
		if bodies_ok {
			for body in bodies {
				delete(body.id)
			}
			delete(bodies)
		}
		return {}, result, false
	}

	return SimulationInput{config = config, bodies = bodies}, result, true
}

load_input :: proc(path: string) -> (SimulationInput, ValidationResult, bool) {
	result: ValidationResult
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		add_error(&result, "$", fmt.tprintf("failed to read input: %v", read_err))
		return {}, result, false
	}

	input, validation, ok := parse_input(data)
	if !ok {
		delete(data)
		return {}, validation, false
	}

	input.source_data = data
	return input, validation, true
}
