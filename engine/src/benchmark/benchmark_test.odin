package benchmark

import simcore "../core"
import "../scenarios"
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

line_count :: proc(text: string) -> int {
	count := 0
	for character in text {
		if character == '\n' {
			count += 1
		}
	}
	return count
}

@(test)
test_generate_bodies_is_deterministic :: proc(t: ^testing.T) {
	a := scenarios.golden_angle_bodies(3)
	defer scenarios.destroy_bodies(a)
	b := scenarios.golden_angle_bodies(3)
	defer scenarios.destroy_bodies(b)

	testing.expect_value(t, len(a), 3)
	testing.expect_value(t, a[0].id, "body_0")
	testing.expect(t, almost_equal(a[0].mass, b[0].mass))
	testing.expect(t, almost_equal(a[1].position.x, b[1].position.x))
	testing.expect(t, almost_equal(a[2].velocity.y, b[2].velocity.y))
}

@(test)
test_result_metrics :: proc(t: ^testing.T) {
	stats := simcore.Solver_Stats {
		direct_interactions = 450,
	}
	result := make_result(10, 5, 2, 1, .brute_force, 0.5, 0.25, stats, "target", "opt", "run")

	testing.expect_value(t, result.schema_version, 3)
	testing.expect_value(t, result.record_type, "benchmark_sample")
	testing.expect_value(t, result.body_count, 10)
	testing.expect_value(t, result.steps, 5)
	testing.expect_value(t, result.sample_index, 2)
	testing.expect_value(t, result.warmups, 1)
	testing.expect_value(t, result.run_id, "run")
	testing.expect_value(t, result.solver, "brute_force")
	testing.expect(t, !result.theta_applicable)
	testing.expect(t, almost_equal(result.theta, 0))
	testing.expect(t, almost_equal(result.average_step_seconds, 0.05))
	testing.expect_value(t, result.interactions, i64(450))
	testing.expect_value(t, result.direct_interactions, i64(450))
	testing.expect_value(t, result.approximated_interactions, i64(0))
	testing.expect(t, almost_equal(result.interactions_per_second, 1800))
	testing.expect_value(t, result.frames_written, 0)
}

@(test)
test_parse_options_failures :: proc(t: ^testing.T) {
	cases := [?][]string {
		[]string{"--counts", "0"},
		[]string{"--steps", "-1"},
		[]string{"--samples", "0"},
		[]string{"--warmups", "-1"},
		[]string{"--solver", "nope"},
		[]string{"--theta", "-0.1"},
		[]string{"--thetas", "0.5,0.5", "--solver", "barnes_hut"},
		[]string{"--theta", "0.5", "--thetas", "0.25,0.5", "--solver", "both"},
		[]string{"--thetas", "0.25,0.5"},
		[]string{"--target-label", ""},
		[]string{"--opt-label", ""},
		[]string{"--summary", ""},
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
	options, _, ok := parse_options(
		[]string {
			"--counts",
			"2,3",
			"--steps",
			"0",
			"--samples",
			"1",
			"--warmups",
			"0",
			"--solver",
			"both",
			"--thetas",
			"0.25,0.7",
			"--target-label",
			"cpu",
			"--opt-label",
			"speed",
			"--run-id",
			"test-run",
			"--summary",
			"/tmp/summary.csv",
		},
	)
	defer if ok {
		destroy_options(&options)
	}

	testing.expect(t, ok)
	testing.expect_value(t, len(options.counts), 2)
	testing.expect_value(t, options.steps, 0)
	testing.expect_value(t, options.samples, 1)
	testing.expect_value(t, options.warmups, 0)
	testing.expect_value(t, options.mode, Benchmark_Mode.both)
	testing.expect_value(t, len(options.thetas), 2)
	testing.expect(t, almost_equal(options.thetas[0], 0.25))
	testing.expect(t, almost_equal(options.thetas[1], 0.7))
	testing.expect_value(t, options.target_label, "cpu")
	testing.expect_value(t, options.opt_label, "speed")
	testing.expect_value(t, options.run_id, "test-run")
	testing.expect_value(t, options.summary_path, "/tmp/summary.csv")
}

@(test)
test_jsonl_result_structure :: proc(t: ^testing.T) {
	path := "/tmp/sanxing-benchmark-test.jsonl"
	os.remove(path)
	defer os.remove(path)

	options, _, ok := parse_options(
		[]string {
			"--counts",
			"2",
			"--steps",
			"1",
			"--samples",
			"1",
			"--warmups",
			"0",
			"--target-label",
			"test-target",
			"--opt-label",
			"test-opt",
		},
	)
	testing.expect(t, ok)
	defer destroy_options(&options)

	testing.expect(t, run(path, options))

	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	text := string(data)
	testing.expect(t, strings.contains(text, `"schema_version":3`))
	testing.expect(t, strings.contains(text, `"record_type":"benchmark_sample"`))
	testing.expect(t, strings.contains(text, `"scenario":"scaling_golden_angle_v1"`))
	testing.expect(t, strings.contains(text, `"solver":"brute_force"`))
	testing.expect(t, strings.contains(text, `"theta_applicable":false`))
	testing.expect(t, strings.contains(text, `"interactions":2`))
	testing.expect(t, strings.contains(text, `"direct_interactions":2`))
	testing.expect(t, strings.contains(text, `"approximated_interactions":0`))
	testing.expect(t, strings.ends_with(text, "\n"))

	value, parse_err := json.parse(data, .JSON)
	testing.expect(t, parse_err == nil)
	json.destroy_value(value)
}

@(test)
test_barnes_hut_result_records_real_work :: proc(t: ^testing.T) {
	path := "/tmp/sanxing-benchmark-barnes-test.jsonl"
	os.remove(path)
	defer os.remove(path)

	options, _, ok := parse_options(
		[]string {
			"--counts",
			"32",
			"--steps",
			"1",
			"--samples",
			"1",
			"--warmups",
			"0",
			"--solver",
			"barnes_hut",
			"--theta",
			"0.7",
		},
	)
	testing.expect(t, ok)
	defer destroy_options(&options)

	testing.expect(t, run(path, options))
	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	text := string(data)
	testing.expect(t, strings.contains(text, `"solver":"barnes_hut"`))
	testing.expect(t, strings.contains(text, `"theta_applicable":true`))
	testing.expect(t, !strings.contains(text, `"interactions":0,`))
	testing.expect(t, !strings.contains(text, `"tree_node_visits":0,`))
	testing.expect(t, !strings.contains(text, `"average_position_divergence":`))
}

@(test)
test_summary_aggregation_math :: proc(t: ^testing.T) {
	stats := simcore.Solver_Stats {
		direct_interactions = 2,
	}
	results := [?]BenchmarkResult {
		make_result(2, 1, 0, 0, .brute_force, 0, 1, stats, "cpu", "speed", "run"),
		make_result(2, 1, 1, 0, .brute_force, 0, 3, stats, "cpu", "speed", "run"),
	}
	summaries := summarize_results(results[:])
	defer delete(summaries)

	testing.expect_value(t, len(summaries), 1)
	testing.expect_value(t, summaries[0].sample_count, 2)
	testing.expect(t, almost_equal(summary_mean_elapsed(summaries[0]), 2))
	testing.expect(t, almost_equal(summary_elapsed_stddev(summaries[0]), 1.4142135623730951))
}

@(test)
test_theta_zero_trajectory_matches_brute_force :: proc(t: ^testing.T) {
	brute_bodies := scenarios.golden_angle_bodies(16)
	defer scenarios.destroy_bodies(brute_bodies)
	tree_bodies := scenarios.golden_angle_bodies(16)
	defer scenarios.destroy_bodies(tree_bodies)
	brute_stats, tree_stats: simcore.Solver_Stats

	testing.expect(t, run_steps(brute_bodies, 4, .brute_force, 0, &brute_stats))
	testing.expect(t, run_steps(tree_bodies, 4, .barnes_hut, 0, &tree_stats))
	for body, i in brute_bodies {
		delta := simcore.vec2_sub(tree_bodies[i].position, body.position)
		testing.expect(t, simcore.vec2_length(delta) < 1e-12)
	}
	testing.expect_value(t, tree_stats.direct_interactions, brute_stats.direct_interactions)
	testing.expect_value(t, tree_stats.approximated_interactions, i64(0))
}

@(test)
test_comparison_matrix_and_csv_summary :: proc(t: ^testing.T) {
	raw_path := "/tmp/sanxing-benchmark-matrix-test.jsonl"
	summary_path := "/tmp/sanxing-benchmark-matrix-test.csv"
	os.remove(raw_path)
	os.remove(summary_path)
	defer os.remove(raw_path)
	defer os.remove(summary_path)

	options, _, ok := parse_options(
		[]string {
			"--counts",
			"2,3",
			"--steps",
			"1",
			"--samples",
			"2",
			"--warmups",
			"0",
			"--solver",
			"both",
			"--thetas",
			"0.25,0.5",
			"--summary",
			summary_path,
			"--target-label",
			"cpu,local",
			"--opt-label",
			"speed",
		},
	)
	testing.expect(t, ok)
	defer destroy_options(&options)

	testing.expect(t, run(raw_path, options))
	raw_data, raw_err := os.read_entire_file(raw_path, context.allocator)
	testing.expect(t, raw_err == nil)
	defer delete(raw_data)
	summary_data, summary_err := os.read_entire_file(summary_path, context.allocator)
	testing.expect(t, summary_err == nil)
	defer delete(summary_data)

	testing.expect_value(t, line_count(string(raw_data)), 12)
	testing.expect_value(t, line_count(string(summary_data)), 7)
	testing.expect(t, strings.contains(string(summary_data), "speedup_vs_brute_force"))
	testing.expect(t, strings.contains(string(summary_data), `"cpu,local"`))
}

@(test)
test_raw_and_summary_paths_must_differ :: proc(t: ^testing.T) {
	path := "/tmp/sanxing-benchmark-same-path-test.jsonl"
	options, _, ok := parse_options(
		[]string {
			"--counts",
			"2",
			"--steps",
			"0",
			"--samples",
			"1",
			"--warmups",
			"0",
			"--summary",
			path,
		},
	)
	testing.expect(t, ok)
	defer destroy_options(&options)
	testing.expect(t, !run(path, options))
}
