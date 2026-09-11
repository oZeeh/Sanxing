package spatial

import simcore "../core"

Rect :: struct {
	center: simcore.Vec2,
	half_width: f64,
	half_height: f64,
}

QuadNode :: struct {
	bounds: Rect,
	body_index: int,
	total_mass: f64,
	center_of_mass: simcore.Vec2,
	children: [4]^QuadNode,
}

rect_contains :: proc(rect: Rect, point: simcore.Vec2) -> bool {
	return point.x >= rect.center.x - rect.half_width &&
	       point.x <= rect.center.x + rect.half_width &&
	       point.y >= rect.center.y - rect.half_height &&
	       point.y <= rect.center.y + rect.half_height
}

quadtree_build_stub :: proc(bounds: Rect, bodies: []simcore.Body) -> (^QuadNode, bool) {
	return nil, false
}
