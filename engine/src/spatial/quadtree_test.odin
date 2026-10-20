package spatial

import simcore "../core"
import "core:testing"

almost_equal :: proc(a, b: f64) -> bool {
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff < 1e-9
}

@(test)
test_rect_contains_edges :: proc(t: ^testing.T) {
	rect := Rect {
		center      = simcore.vec2(0, 0),
		half_width  = 2,
		half_height = 1,
	}

	testing.expect(t, rect_contains(rect, simcore.vec2(0, 0)))
	testing.expect(t, rect_contains(rect, simcore.vec2(2, 1)))
	testing.expect(t, !rect_contains(rect, simcore.vec2(2.1, 0)))
	testing.expect(t, !rect_contains(rect, simcore.vec2(0, -1.1)))
}

@(test)
test_bounds_for_empty_tree :: proc(t: ^testing.T) {
	bodies: [0]simcore.Body
	_, ok := quadtree_bounds_for_bodies(bodies[:])
	testing.expect(t, !ok)
}

@(test)
test_single_body_tree :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body{{mass = 2, position = simcore.vec2(1, -1)}}
	bounds, bounds_ok := quadtree_bounds_for_bodies(bodies[:])
	testing.expect(t, bounds_ok)

	root, ok := quadtree_build(bounds, bodies[:])
	defer quadtree_destroy(root)

	testing.expect(t, ok)
	testing.expect(t, root != nil)
	testing.expect(t, quadtree_is_leaf(root))
	testing.expect_value(t, len(root.body_indices), 1)
	testing.expect_value(t, root.body_indices[0], 0)
	testing.expect_value(t, root.body_count, 1)
	testing.expect(t, almost_equal(root.total_mass, 2))
	testing.expect(t, almost_equal(root.center_of_mass.x, 1))
	testing.expect(t, almost_equal(root.center_of_mass.y, -1))
}

@(test)
test_subdivision_and_mass_aggregation :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body {
		{mass = 1, position = simcore.vec2(-1, -1)},
		{mass = 3, position = simcore.vec2(1, 1)},
	}
	bounds := Rect {
		center      = simcore.vec2(0, 0),
		half_width  = 2,
		half_height = 2,
	}

	root, ok := quadtree_build(bounds, bodies[:])
	defer quadtree_destroy(root)

	testing.expect(t, ok)
	testing.expect(t, !quadtree_is_leaf(root))
	testing.expect_value(t, root.body_count, 2)
	testing.expect(t, almost_equal(root.total_mass, 4))
	testing.expect(t, almost_equal(root.center_of_mass.x, 0.5))
	testing.expect(t, almost_equal(root.center_of_mass.y, 0.5))
	testing.expect(t, root.children[0] != nil)
	testing.expect(t, root.children[3] != nil)
	testing.expect_value(t, root.children[0].body_indices[0], 0)
	testing.expect_value(t, root.children[3].body_indices[0], 1)
}

@(test)
test_edge_positions_insert :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body {
		{mass = 1, position = simcore.vec2(-2, -2)},
		{mass = 1, position = simcore.vec2(2, 2)},
	}
	bounds := Rect {
		center      = simcore.vec2(0, 0),
		half_width  = 2,
		half_height = 2,
	}

	root, ok := quadtree_build(bounds, bodies[:])
	defer quadtree_destroy(root)

	testing.expect(t, ok)
	testing.expect_value(t, root.body_count, 2)
}

@(test)
test_coincident_bodies_remain_in_leaf_bucket :: proc(t: ^testing.T) {
	bodies := [?]simcore.Body {
		{mass = 1, position = simcore.vec2(0, 0)},
		{mass = 2, position = simcore.vec2(0, 0)},
		{mass = 3, position = simcore.vec2(0, 0)},
	}
	bounds := Rect {
		center      = simcore.vec2(0, 0),
		half_width  = 1,
		half_height = 1,
	}

	root, ok := quadtree_build(bounds, bodies[:])
	defer quadtree_destroy(root)

	testing.expect(t, ok)
	current := root
	for !quadtree_is_leaf(current) {
		current = current.children[child_index_for(current.bounds, simcore.vec2(0, 0))]
	}
	testing.expect_value(t, current.body_count, 3)
	testing.expect_value(t, len(current.body_indices), 3)
	testing.expect_value(t, current.body_indices[0], 0)
	testing.expect_value(t, current.body_indices[1], 1)
	testing.expect_value(t, current.body_indices[2], 2)
}
