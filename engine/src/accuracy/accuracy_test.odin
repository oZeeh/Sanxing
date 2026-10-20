package accuracy

import "../scenarios"
import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_theta_zero_is_exact_control :: proc(t: ^testing.T) {
	raw := "/tmp/sanxing-accuracy-test.jsonl"
	summary := "/tmp/sanxing-accuracy-test.csv"
	os.remove(raw); os.remove(summary)
	defer os.remove(raw); defer os.remove(summary)
	options, _, ok := parse_options([]string{"--counts", "16", "--thetas", "0,0.5", "--run-id", "test", "--summary", summary})
	testing.expect(t, ok)
	defer destroy_options(&options)
	testing.expect(t, run(raw, options))
	data, err := os.read_entire_file(raw, context.allocator)
	testing.expect(t, err == nil)
	defer delete(data)
	text := string(data)
	testing.expect(t, strings.contains(text, `"schema_version":1`))
	testing.expect(t, strings.contains(text, `"run_id":"test"`))
	testing.expect(t, strings.contains(text, `"theta":0`))
	testing.expect(t, strings.contains(text, `"normalized_l2_acceleration_error":0`))
}

@(test)
test_error_metric_detects_difference :: proc(t: ^testing.T) {
	baseline := scenarios.golden_angle_bodies(2)
	defer scenarios.destroy_bodies(baseline)
	candidate := scenarios.clone_bodies(baseline)
	defer scenarios.destroy_bodies(candidate)
	baseline[0].acceleration.x = 1
	candidate[0].acceleration.x = 2
	normalized, mean, maximum := measure_acceleration_error(candidate, baseline)
	testing.expect(t, normalized > 0)
	testing.expect_value(t, mean, 0.5)
	testing.expect_value(t, maximum, 1.0)
}
