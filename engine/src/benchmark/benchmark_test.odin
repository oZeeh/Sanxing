package benchmark

import "core:encoding/json"
import "core:os"
import "core:strings"
import "core:testing"

almost_equal :: proc(a, b: f64) -> bool {
	diff := a - b
	if diff < 0 {
		diff = -diff
	}
	return diff < 1e-12
}

@(test)
test_generate_bodies_is_deterministic :: proc(t: ^testing.T) {
	a := generate_bodies(3)
	defer destroy_bodies(a)
	b := generate_bodies(3)
	defer destroy_bodies(b)

	testing.expect_value(t, len(a), 3)
	testing.expect_value(t, a[0].id, "body_0")
	testing.expect(t, almost_equal(a[0].mass, b[0].mass))
	testing.expect(t, almost_equal(a[1].position.x, b[1].position.x))
	testing.expect(t, almost_equal(a[2].velocity.y, b[2].velocity.y))
}

@(test)
test_result_metrics :: proc(t: ^testing.T) {
	result := make_result(10, 5, 2, 0.25, "target", "opt")

	testing.expect_value(t, result.body_count, 10)
	testing.expect_value(t, result.steps, 5)
	testing.expect_value(t, result.sample_index, 2)
	testing.expect_value(t, result.solver, "brute_force")
	testing.expect(t, almost_equal(result.average_step_seconds, 0.05))
	testing.expect_value(t, result.interactions, i64(450))
	testing.expect(t, almost_equal(result.interactions_per_second, 1800))
	testing.expect_value(t, result.frames_written, 0)
	testing.expect_value(t, result.target_label, "target")
	testing.expect_value(t, result.opt_label, "opt")
}

@(test)
test_parse_options_failures :: proc(t: ^testing.T) {
	cases := [?][]string{
		[]string{"--counts", "0"},
		[]string{"--steps", "-1"},
		[]string{"--samples", "0"},
		[]string{"--target-label", ""},
		[]string{"--opt-label", ""},
		[]string{"--unknown", "x"},
		[]string{"--steps"},
	}

	for args in cases {
		options, _, ok := parse_options(args)
		if ok {
			destroy_options(&options)
		}
		testing.expect(t, !ok)
	}
}

@(test)
test_parse_options_success :: proc(t: ^testing.T) {
	options, _, ok := parse_options([]string{"--counts", "2,3", "--steps", "0", "--samples", "1", "--target-label", "cpu", "--opt-label", "debug"})
	defer if ok {
		destroy_options(&options)
	}

	testing.expect(t, ok)
	testing.expect_value(t, len(options.counts), 2)
	testing.expect_value(t, options.counts[0], 2)
	testing.expect_value(t, options.counts[1], 3)
	testing.expect_value(t, options.steps, 0)
	testing.expect_value(t, options.samples, 1)
	testing.expect_value(t, options.target_label, "cpu")
	testing.expect_value(t, options.opt_label, "debug")
}

@(test)
test_jsonl_result_structure :: proc(t: ^testing.T) {
	path := "/tmp/sanxing-benchmark-test.jsonl"
	os.remove(path)

	options, _, ok := parse_options([]string{"--counts", "2", "--steps", "1", "--samples", "1", "--target-label", "test-target", "--opt-label", "test-opt"})
	testing.expect(t, ok)
	defer destroy_options(&options)

	testing.expect(t, run(path, options))

	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	text := string(data)
	testing.expect(t, strings.contains(text, `"body_count":2`))
	testing.expect(t, strings.contains(text, `"steps":1`))
	testing.expect(t, strings.contains(text, `"sample_index":0`))
	testing.expect(t, strings.contains(text, `"solver":"brute_force"`))
	testing.expect(t, strings.contains(text, `"frames_written":0`))
	testing.expect(t, strings.contains(text, `"target_label":"test-target"`))
	testing.expect(t, strings.contains(text, `"opt_label":"test-opt"`))
	testing.expect(t, strings.ends_with(text, "\n"))

	value, parse_err := json.parse(data, .JSON)
	testing.expect(t, parse_err == nil)
	json.destroy_value(value)
}
