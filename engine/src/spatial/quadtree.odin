package spatial

import simcore "../core"

MAX_DEPTH :: 32
MIN_HALF_SIZE :: 1e-12

Rect :: struct {
	center:      simcore.Vec2,
	half_width:  f64,
	half_height: f64,
}

QuadNode :: struct {
	bounds:         Rect,
	body_indices:   [dynamic]int,
	body_count:     int,
	total_mass:     f64,
	center_of_mass: simcore.Vec2,
	children:       [4]^QuadNode,
}

rect_contains :: proc(rect: Rect, point: simcore.Vec2) -> bool {
	return(
		point.x >= rect.center.x - rect.half_width &&
		point.x <= rect.center.x + rect.half_width &&
		point.y >= rect.center.y - rect.half_height &&
		point.y <= rect.center.y + rect.half_height \
	)
}

rect_width :: proc(rect: Rect) -> f64 {
	return rect.half_width * 2
}

rect_height :: proc(rect: Rect) -> f64 {
	return rect.half_height * 2
}

quadtree_create :: proc(bounds: Rect) -> ^QuadNode {
	node := new(QuadNode)
	node.bounds = bounds
	return node
}

quadtree_destroy :: proc(node: ^QuadNode) {
	if node == nil {
		return
	}
	for child in node.children {
		quadtree_destroy(child)
	}
	delete(node.body_indices)
	free(node)
}

quadtree_is_leaf :: proc(node: ^QuadNode) -> bool {
	for child in node.children {
		if child != nil {
			return false
		}
	}
	return true
}

child_bounds :: proc(bounds: Rect, index: int) -> Rect {
	quarter_width := bounds.half_width * 0.5
	quarter_height := bounds.half_height * 0.5
	x_offset := quarter_width
	y_offset := quarter_height
	if index == 0 || index == 2 {
		x_offset = -quarter_width
	}
	if index == 0 || index == 1 {
		y_offset = -quarter_height
	}
	return Rect {
		center = simcore.vec2(bounds.center.x + x_offset, bounds.center.y + y_offset),
		half_width = quarter_width,
		half_height = quarter_height,
	}
}

child_index_for :: proc(bounds: Rect, point: simcore.Vec2) -> int {
	east := point.x >= bounds.center.x
	north := point.y >= bounds.center.y
	if !east && !north {
		return 0
	}
	if east && !north {
		return 1
	}
	if !east && north {
		return 2
	}
	return 3
}

quadtree_subdivide :: proc(node: ^QuadNode) {
	for i in 0 ..< 4 {
		node.children[i] = quadtree_create(child_bounds(node.bounds, i))
	}
}

quadtree_add_mass :: proc(node: ^QuadNode, body: simcore.Body) {
	previous_mass := node.total_mass
	node.total_mass += body.mass
	if node.total_mass == 0 {
		node.center_of_mass = simcore.vec2_zero()
		return
	}
	node.center_of_mass = simcore.vec2(
		(node.center_of_mass.x * previous_mass + body.position.x * body.mass) / node.total_mass,
		(node.center_of_mass.y * previous_mass + body.position.y * body.mass) / node.total_mass,
	)
}

quadtree_insert :: proc(
	node: ^QuadNode,
	bodies: []simcore.Body,
	body_index: int,
	depth := 0,
) -> bool {
	if node == nil || body_index < 0 || body_index >= len(bodies) {
		return false
	}
	body := bodies[body_index]
	if !rect_contains(node.bounds, body.position) {
		return false
	}

	node.body_count += 1
	quadtree_add_mass(node, body)

	if quadtree_is_leaf(node) {
		if len(node.body_indices) == 0 {
			append(&node.body_indices, body_index)
			return true
		}

		if depth >= MAX_DEPTH ||
		   node.bounds.half_width <= MIN_HALF_SIZE ||
		   node.bounds.half_height <= MIN_HALF_SIZE {
			append(&node.body_indices, body_index)
			return true
		}

		old_body_indices := node.body_indices
		node.body_indices = nil
		quadtree_subdivide(node)
		for old_body_index in old_body_indices {
			child_index := child_index_for(node.bounds, bodies[old_body_index].position)
			if !quadtree_insert(node.children[child_index], bodies, old_body_index, depth + 1) {
				delete(old_body_indices)
				return false
			}
		}
		delete(old_body_indices)
	}

	child_index := child_index_for(node.bounds, body.position)
	return quadtree_insert(node.children[child_index], bodies, body_index, depth + 1)
}

quadtree_build :: proc(bounds: Rect, bodies: []simcore.Body) -> (^QuadNode, bool) {
	root := quadtree_create(bounds)
	for body, i in bodies {
		if !rect_contains(bounds, body.position) {
			quadtree_destroy(root)
			return nil, false
		}
		if !quadtree_insert(root, bodies, i) {
			quadtree_destroy(root)
			return nil, false
		}
	}
	return root, true
}

quadtree_bounds_for_bodies :: proc(bodies: []simcore.Body) -> (Rect, bool) {
	if len(bodies) == 0 {
		return Rect{}, false
	}

	min_x := bodies[0].position.x
	max_x := bodies[0].position.x
	min_y := bodies[0].position.y
	max_y := bodies[0].position.y
	for body in bodies[1:] {
		if body.position.x < min_x {
			min_x = body.position.x
		}
		if body.position.x > max_x {
			max_x = body.position.x
		}
		if body.position.y < min_y {
			min_y = body.position.y
		}
		if body.position.y > max_y {
			max_y = body.position.y
		}
	}

	width := max_x - min_x
	height := max_y - min_y
	half_size := width * 0.5
	if height > width {
		half_size = height * 0.5
	}
	if half_size < 1 {
		half_size = 1
	}
	half_size *= 1.000001

	return Rect {
			center = simcore.vec2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5),
			half_width = half_size,
			half_height = half_size,
		},
		true
}
