package spatial

import "core:testing"
import simcore "../core"

@(test)
test_rect_contains_edges :: proc(t: ^testing.T) {
	rect := Rect{
		center = simcore.vec2(0, 0),
		half_width = 2,
		half_height = 1,
	}

	testing.expect(t, rect_contains(rect, simcore.vec2(0, 0)))
	testing.expect(t, rect_contains(rect, simcore.vec2(2, 1)))
	testing.expect(t, !rect_contains(rect, simcore.vec2(2.1, 0)))
	testing.expect(t, !rect_contains(rect, simcore.vec2(0, -1.1)))
}
