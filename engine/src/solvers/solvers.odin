package solvers

import "core:math"
import simcore "../core"
import "../spatial"

get_solver :: proc(kind: simcore.Solver_Type) -> simcore.Solver_Proc {
	switch kind {
	case .brute_force:
		return brute_force
	case .barnes_hut:
		return barnes_hut
	}
	return barnes_hut
}

brute_force :: proc(bodies: []simcore.Body, config: simcore.SimulationConfig) -> simcore.Step_Status {
	for &body in bodies {
		body.acceleration = simcore.vec2_zero()
	}

	for i in 0..<len(bodies) {
		accel := simcore.vec2_zero()
		for j in 0..<len(bodies) {
			if i == j {
				continue
			}

			delta := simcore.vec2_sub(bodies[j].position, bodies[i].position)
			distance_sq := simcore.vec2_length_sq(delta) + config.softening * config.softening
			if distance_sq == 0 {
				continue
			}

			scale := config.gravitational_constant * bodies[j].mass / (distance_sq * math.sqrt(distance_sq))
			accel = simcore.vec2_add(accel, simcore.vec2_scale(delta, scale))
		}
		bodies[i].acceleration = accel
	}

	return .ok
}

barnes_hut :: proc(bodies: []simcore.Body, config: simcore.SimulationConfig) -> simcore.Step_Status {
	for &body in bodies {
		body.acceleration = simcore.vec2_zero()
	}
	if len(bodies) == 0 {
		return .ok
	}

	bounds, bounds_ok := spatial.quadtree_bounds_for_bodies(bodies)
	if !bounds_ok {
		return .ok
	}
	root, tree_ok := spatial.quadtree_build(bounds, bodies)
	if !tree_ok {
		return .invalid_config
	}
	defer spatial.quadtree_destroy(root)

	theta := config.theta

	for i in 0..<len(bodies) {
		bodies[i].acceleration = barnes_hut_acceleration(root, bodies, i, config, theta)
	}
	return .ok
}

barnes_hut_acceleration :: proc(node: ^spatial.QuadNode, bodies: []simcore.Body, body_index: int, config: simcore.SimulationConfig, theta: f64) -> simcore.Vec2 {
	if node == nil || node.body_count == 0 {
		return simcore.vec2_zero()
	}

	if spatial.quadtree_is_leaf(node) {
		if node.body_index == body_index {
			return simcore.vec2_zero()
		}
		if node.body_index == -1 {
			return acceleration_from_mass(bodies[body_index].position, node.center_of_mass, node.total_mass, config)
		}
		return acceleration_from_mass(bodies[body_index].position, bodies[node.body_index].position, bodies[node.body_index].mass, config)
	}

	if !quadtree_node_contains_body(node, bodies, body_index) {
		delta := simcore.vec2_sub(node.center_of_mass, bodies[body_index].position)
		distance := math.sqrt(simcore.vec2_length_sq(delta) + config.softening * config.softening)
		width := spatial.rect_width(node.bounds)
		if distance > 0 && width / distance < theta {
			return acceleration_from_mass(bodies[body_index].position, node.center_of_mass, node.total_mass, config)
		}
	}

	accel := simcore.vec2_zero()
	for child in node.children {
		accel = simcore.vec2_add(accel, barnes_hut_acceleration(child, bodies, body_index, config, theta))
	}
	return accel
}

acceleration_from_mass :: proc(position, source_position: simcore.Vec2, source_mass: f64, config: simcore.SimulationConfig) -> simcore.Vec2 {
	delta := simcore.vec2_sub(source_position, position)
	distance_sq := simcore.vec2_length_sq(delta) + config.softening * config.softening
	if distance_sq == 0 {
		return simcore.vec2_zero()
	}
	scale := config.gravitational_constant * source_mass / (distance_sq * math.sqrt(distance_sq))
	return simcore.vec2_scale(delta, scale)
}

quadtree_node_contains_body :: proc(node: ^spatial.QuadNode, bodies: []simcore.Body, body_index: int) -> bool {
	if node == nil || body_index < 0 || body_index >= len(bodies) {
		return false
	}
	if !spatial.rect_contains(node.bounds, bodies[body_index].position) {
		return false
	}
	if spatial.quadtree_is_leaf(node) {
		return node.body_index == body_index
	}
	child_index := spatial.child_index_for(node.bounds, bodies[body_index].position)
	return quadtree_node_contains_body(node.children[child_index], bodies, body_index)
}
