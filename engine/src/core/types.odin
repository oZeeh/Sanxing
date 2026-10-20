package core

import "core:math"

Vec2 :: struct {
	x: f64,
	y: f64,
}

Body :: struct {
	id:           string,
	mass:         f64,
	position:     Vec2,
	velocity:     Vec2,
	acceleration: Vec2,
}

Solver_Type :: enum {
	brute_force,
	barnes_hut,
}

SimulationConfig :: struct {
	gravitational_constant: f64,
	delta_time:             f64,
	steps:                  int,
	softening:              f64,
	theta:                  f64,
	solver:                 Solver_Type,
	export_enabled:         bool,
}

SimulationState :: struct {
	bodies: []Body,
	step:   int,
	time:   f64,
}

Step_Status :: enum {
	ok,
	unsupported_solver,
	invalid_config,
}

Solver_Stats :: struct {
	direct_interactions:       i64,
	approximated_interactions: i64,
	tree_node_visits:          i64,
}

Solver_Proc :: #type proc(
	bodies: []Body,
	config: SimulationConfig,
	stats: ^Solver_Stats,
) -> Step_Status
Integrator_Proc :: #type proc(bodies: []Body, config: SimulationConfig)

vec2 :: proc(x, y: f64) -> Vec2 {
	return Vec2{x = x, y = y}
}

vec2_zero :: proc() -> Vec2 {
	return Vec2{}
}

vec2_add :: proc(a, b: Vec2) -> Vec2 {
	return Vec2{x = a.x + b.x, y = a.y + b.y}
}

vec2_sub :: proc(a, b: Vec2) -> Vec2 {
	return Vec2{x = a.x - b.x, y = a.y - b.y}
}

vec2_scale :: proc(v: Vec2, scalar: f64) -> Vec2 {
	return Vec2{x = v.x * scalar, y = v.y * scalar}
}

vec2_length_sq :: proc(v: Vec2) -> f64 {
	return v.x * v.x + v.y * v.y
}

vec2_length :: proc(v: Vec2) -> f64 {
	return math.sqrt(vec2_length_sq(v))
}

vec2_normalize :: proc(v: Vec2) -> Vec2 {
	length := vec2_length(v)
	if length == 0 {
		return vec2_zero()
	}
	return vec2_scale(v, 1.0 / length)
}

validate_config :: proc(config: SimulationConfig) -> bool {
	if math.is_nan(config.gravitational_constant) ||
	   math.is_inf(config.gravitational_constant) ||
	   config.gravitational_constant < 0 {
		return false
	}
	if math.is_nan(config.delta_time) || math.is_inf(config.delta_time) || config.delta_time <= 0 {
		return false
	}
	if config.steps < 0 {
		return false
	}
	if math.is_nan(config.softening) || math.is_inf(config.softening) || config.softening < 0 {
		return false
	}
	if math.is_nan(config.theta) || math.is_inf(config.theta) || config.theta < 0 {
		return false
	}
	return true
}

step_state :: proc(
	state: ^SimulationState,
	config: SimulationConfig,
	solver: Solver_Proc,
	integrator: Integrator_Proc,
	stats: ^Solver_Stats = nil,
) -> Step_Status {
	if !validate_config(config) {
		return .invalid_config
	}

	status := solver(state.bodies, config, stats)
	if status != .ok {
		return status
	}

	integrator(state.bodies, config)
	state.step += 1
	state.time += config.delta_time
	return .ok
}
