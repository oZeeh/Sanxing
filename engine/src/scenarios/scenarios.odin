package scenarios

import simcore "../core"
import "core:fmt"
import "core:math"

GOLDEN_ANGLE :: 2.39996322972865332
GOLDEN_ANGLE_SCENARIO :: "scaling_golden_angle_v1"
FORCE_ACCURACY_SCENARIO :: "force_accuracy_golden_angle_v1"

golden_angle_bodies :: proc(count: int, allocator := context.allocator) -> []simcore.Body {
	bodies := make([]simcore.Body, count, allocator)
	for i in 0 ..< count {
		index := f64(i)
		radius := math.sqrt(index + 1) / math.sqrt(f64(count))
		angle := index * GOLDEN_ANGLE
		bodies[i] = simcore.Body {
			id           = fmt.aprintf("body_%d", i, allocator = allocator),
			mass         = 1.0 + f64(i % 17) * 0.001,
			position     = simcore.vec2(radius * math.cos(angle), radius * math.sin(angle)),
			velocity     = simcore.vec2(-math.sin(angle) * 0.01, math.cos(angle) * 0.01),
			acceleration = simcore.vec2_zero(),
		}
	}
	return bodies
}

clone_bodies :: proc(source: []simcore.Body, allocator := context.allocator) -> []simcore.Body {
	bodies := make([]simcore.Body, len(source), allocator)
	for body, i in source {
		bodies[i] = body
		bodies[i].id = fmt.aprintf("%s", body.id, allocator = allocator)
	}
	return bodies
}

destroy_bodies :: proc(bodies: []simcore.Body) {
	for body in bodies {
		delete(body.id)
	}
	delete(bodies)
}
