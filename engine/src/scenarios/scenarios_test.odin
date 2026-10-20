package scenarios

import "core:testing"

@(test)
test_golden_angle_bodies_are_deterministic :: proc(t: ^testing.T) {
	a := golden_angle_bodies(3)
	defer destroy_bodies(a)
	b := golden_angle_bodies(3)
	defer destroy_bodies(b)

	testing.expect_value(t, len(a), 3)
	testing.expect_value(t, a[0].id, "body_0")
	testing.expect_value(t, a[1].mass, b[1].mass)
	testing.expect_value(t, a[2].position, b[2].position)
}

@(test)
test_clone_bodies_owns_ids :: proc(t: ^testing.T) {
	source := golden_angle_bodies(2)
	defer destroy_bodies(source)
	clone := clone_bodies(source)
	defer destroy_bodies(clone)

	testing.expect_value(t, clone[1], source[1])
}
