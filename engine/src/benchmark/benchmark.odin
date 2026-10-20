package benchmark

import simcore "../core"
import "../integration"
import "../scenarios"
import "../solvers"
import csv "core:encoding/csv"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

Benchmark_Mode :: enum {
	brute_force,
	barnes_hut,
	both,
}

BenchmarkResult :: struct {
	schema_version:              int,
	record_type:                 string,
	run_id:                      string,
	scenario:                    string,
	body_count:                  int,
	steps:                       int,
	sample_index:                int,
	warmups:                     int,
	solver:                      string,
	theta:                       f64,
	theta_applicable:            bool,
	elapsed_seconds:             f64,
	average_step_seconds:        f64,
	interactions:                i64,
	direct_interactions:         i64,
	approximated_interactions:   i64,
	tree_node_visits:            i64,
	interactions_per_second:     f64,
	frames_written:              int,
	target_label:                string,
	opt_label:                   string,
}

BenchmarkSummary :: struct {
	body_count:                    int,
	steps:                         int,
	solver:                        string,
	theta:                         f64,
	theta_applicable:              bool,
	sample_count:                  int,
	elapsed_sum:                   f64,
	elapsed_squared_sum:           f64,
	elapsed_min:                   f64,
	elapsed_max:                   f64,
	step_seconds_sum:              f64,
	interactions_sum:              f64,
	direct_interactions_sum:       f64,
	approximated_interactions_sum: f64,
	tree_node_visits_sum:          f64,
	interactions_per_second_sum:   f64,
	run_id:                        string,
	target_label:                  string,
	opt_label:                     string,
}

DEFAULT_COUNTS :: [?]int{100, 500, 1000, 5000, 10000}
DEFAULT_STEPS :: 10
DEFAULT_SAMPLES :: 3
DEFAULT_WARMUPS :: 1
DEFAULT_LABEL :: "unspecified"
DEFAULT_RUN_ID :: "unspecified"
DEFAULT_THETA :: 0.5
SCHEMA_VERSION :: 3
SAMPLE_RECORD_TYPE :: "benchmark_sample"

parse_positive_int :: proc(text: string) -> (int, bool) {
	value, ok := strconv.parse_int(text, 10)
	if !ok || value <= 0 {
		return 0, false
	}
	return value, true
}

parse_nonnegative_int :: proc(text: string) -> (int, bool) {
	value, ok := strconv.parse_int(text, 10)
	if !ok || value < 0 {
		return 0, false
	}
	return value, true
}

parse_nonnegative_f64 :: proc(text: string) -> (f64, bool) {
	value, ok := strconv.parse_f64(text)
	if !ok || value < 0 || math.is_nan(value) || math.is_inf(value) {
		return 0, false
	}
	return value, true
}

solver_name :: proc(solver: simcore.Solver_Type) -> string {
	switch solver {
	case .brute_force:
		return "brute_force"
	case .barnes_hut:
		return "barnes_hut"
	}
	return "barnes_hut"
}

parse_mode :: proc(text: string) -> (Benchmark_Mode, bool) {
	switch text {
	case "brute_force":
		return .brute_force, true
	case "barnes_hut":
		return .barnes_hut, true
	case "both":
		return .both, true
	}
	return .brute_force, false
}

parse_counts :: proc(text: string) -> ([]int, bool) {
	parts := strings.split(text, ",")
	defer delete(parts)
	if len(parts) == 0 {
		return nil, false
	}

	counts: [dynamic]int
	for part in parts {
		if part == "" {
			delete(counts)
			return nil, false
		}
		value, ok := parse_positive_int(part)
		if !ok {
			delete(counts)
			return nil, false
		}
		append(&counts, value)
	}

	return counts[:], true
}

parse_thetas :: proc(text: string) -> ([]f64, bool) {
	parts := strings.split(text, ",")
	defer delete(parts)
	if len(parts) == 0 {
		return nil, false
	}

	thetas: [dynamic]f64
	for part in parts {
		if part == "" {
			delete(thetas)
			return nil, false
		}
		value, ok := parse_nonnegative_f64(part)
		if !ok {
			delete(thetas)
			return nil, false
		}
		for existing in thetas {
			if existing == value {
				delete(thetas)
				return nil, false
			}
		}
		append(&thetas, value)
	}
	return thetas[:], true
}

BenchmarkOptions :: struct {
	counts:       []int,
	steps:        int,
	samples:      int,
	warmups:      int,
	mode:         Benchmark_Mode,
	thetas:       []f64,
	target_label: string,
	opt_label:    string,
	run_id:       string,
	summary_path: string,
}

destroy_options :: proc(options: ^BenchmarkOptions) {
	delete(options.counts)
	delete(options.thetas)
	delete(options.target_label)
	delete(options.opt_label)
	delete(options.run_id)
	delete(options.summary_path)
	options^ = BenchmarkOptions{}
}

default_options :: proc() -> BenchmarkOptions {
	counts := make([]int, len(DEFAULT_COUNTS))
	for value, i in DEFAULT_COUNTS {
		counts[i] = value
	}
	thetas := make([]f64, 1)
	thetas[0] = DEFAULT_THETA
	return BenchmarkOptions {
		counts = counts,
		steps = DEFAULT_STEPS,
		samples = DEFAULT_SAMPLES,
		warmups = DEFAULT_WARMUPS,
		mode = .brute_force,
		thetas = thetas,
		target_label = strings.clone(DEFAULT_LABEL),
		opt_label = strings.clone(DEFAULT_LABEL),
		run_id = strings.clone(DEFAULT_RUN_ID),
	}
}

parse_options :: proc(args: []string) -> (BenchmarkOptions, string, bool) {
	options := default_options()
	used_theta := false
	used_thetas := false
	for i := 0; i < len(args); i += 1 {
		arg := args[i]
		if i + 1 >= len(args) {
			destroy_options(&options)
			return {}, fmt.tprintf("%s requires a value", arg), false
		}
		value := args[i + 1]
		i += 1

		switch arg {
		case "--counts":
			counts, ok := parse_counts(value)
			if !ok {
				destroy_options(&options)
				return {}, "--counts must be a comma-separated list of positive integers", false
			}
			delete(options.counts)
			options.counts = counts
		case "--steps":
			steps, ok := parse_nonnegative_int(value)
			if !ok {
				destroy_options(&options)
				return {}, "--steps must be a nonnegative integer", false
			}
			options.steps = steps
		case "--samples":
			samples, ok := parse_positive_int(value)
			if !ok {
				destroy_options(&options)
				return {}, "--samples must be a positive integer", false
			}
			options.samples = samples
		case "--warmups":
			warmups, ok := parse_nonnegative_int(value)
			if !ok {
				destroy_options(&options)
				return {}, "--warmups must be a nonnegative integer", false
			}
			options.warmups = warmups
		case "--solver":
			mode, ok := parse_mode(value)
			if !ok {
				destroy_options(&options)
				return {}, "--solver must be one of brute_force, barnes_hut, both", false
			}
			options.mode = mode
		case "--theta":
			if used_thetas {
				destroy_options(&options)
				return {}, "--theta and --thetas are mutually exclusive", false
			}
			theta, ok := parse_nonnegative_f64(value)
			if !ok {
				destroy_options(&options)
				return {}, "--theta must be a nonnegative finite number", false
			}
			delete(options.thetas)
			options.thetas = make([]f64, 1)
			options.thetas[0] = theta
			used_theta = true
		case "--thetas":
			if used_theta {
				destroy_options(&options)
				return {}, "--theta and --thetas are mutually exclusive", false
			}
			thetas, ok := parse_thetas(value)
			if !ok {
				destroy_options(&options)
				return {},
					"--thetas must be a comma-separated list of unique nonnegative finite numbers",
					false
			}
			delete(options.thetas)
			options.thetas = thetas
			used_thetas = true
		case "--target-label":
			if value == "" {
				destroy_options(&options)
				return {}, "--target-label must be nonempty", false
			}
			delete(options.target_label)
			options.target_label = strings.clone(value)
		case "--opt-label":
			if value == "" {
				destroy_options(&options)
				return {}, "--opt-label must be nonempty", false
			}
			delete(options.opt_label)
			options.opt_label = strings.clone(value)
		case "--run-id":
			if value == "" {
				destroy_options(&options)
				return {}, "--run-id must be nonempty", false
			}
			delete(options.run_id)
			options.run_id = strings.clone(value)
		case "--summary":
			if value == "" {
				destroy_options(&options)
				return {}, "--summary must be nonempty", false
			}
			delete(options.summary_path)
			options.summary_path = strings.clone(value)
		case:
			destroy_options(&options)
			return {}, fmt.tprintf("unknown benchmark flag: %s", arg), false
		}
	}
	if used_thetas && options.mode == .brute_force {
		destroy_options(&options)
		return {}, "--thetas requires --solver barnes_hut or --solver both", false
	}
	return options, "", true
}

make_result :: proc(
	body_count, steps, sample_index, warmups: int,
	solver: simcore.Solver_Type,
	theta, elapsed_seconds: f64,
	stats: simcore.Solver_Stats,
	target_label, opt_label, run_id: string,
) -> BenchmarkResult {
	avg_step_seconds := 0.0
	if steps > 0 {
		avg_step_seconds = elapsed_seconds / f64(steps)
	}
	interactions := stats.direct_interactions + stats.approximated_interactions
	interactions_per_second := 0.0
	if elapsed_seconds > 0 {
		interactions_per_second = f64(interactions) / elapsed_seconds
	}
	theta_applicable := solver == .barnes_hut
	result_theta := theta
	if !theta_applicable {
		result_theta = 0
	}
	return BenchmarkResult {
		schema_version = SCHEMA_VERSION,
		record_type = SAMPLE_RECORD_TYPE,
		run_id = run_id,
		scenario = scenarios.GOLDEN_ANGLE_SCENARIO,
		body_count = body_count,
		steps = steps,
		sample_index = sample_index,
		warmups = warmups,
		solver = solver_name(solver),
		theta = result_theta,
		theta_applicable = theta_applicable,
		elapsed_seconds = elapsed_seconds,
		average_step_seconds = avg_step_seconds,
		interactions = interactions,
		direct_interactions = stats.direct_interactions,
		approximated_interactions = stats.approximated_interactions,
		tree_node_visits = stats.tree_node_visits,
		interactions_per_second = interactions_per_second,
		frames_written = 0,
		target_label = target_label,
		opt_label = opt_label,
	}
}

write_result :: proc(file: ^os.File, result: BenchmarkResult) -> bool {
	data, err := json.marshal(result, json.Marshal_Options{spec = .JSON})
	if err != nil {
		return false
	}
	defer delete(data)
	if _, write_err := os.write(file, data); write_err != nil {
		return false
	}
	if _, newline_err := os.write_string(file, "\n"); newline_err != nil {
		return false
	}
	return true
}

run_steps :: proc(
	bodies: []simcore.Body,
	steps: int,
	solver_kind: simcore.Solver_Type,
	theta: f64,
	stats: ^simcore.Solver_Stats = nil,
) -> bool {
	config := simcore.SimulationConfig {
		gravitational_constant = 1.0,
		delta_time             = 0.01,
		steps                  = steps,
		softening              = 0.001,
		theta                  = theta,
		solver                 = solver_kind,
		export_enabled         = false,
	}
	state := simcore.SimulationState {
		bodies = bodies,
		step   = 0,
		time   = 0,
	}
	solver := solvers.get_solver(solver_kind)

	for _ in 0 ..< steps {
		status := simcore.step_state(
			&state,
			config,
			solver,
			integration.semi_implicit_euler,
			stats,
		)
		if status != .ok {
			return false
		}
	}
	return true
}

run_warmup :: proc(body_count, steps: int, solver_kind: simcore.Solver_Type, theta: f64) -> bool {
	bodies := scenarios.golden_angle_bodies(body_count)
	defer scenarios.destroy_bodies(bodies)
	return run_steps(bodies, steps, solver_kind, theta)
}

run_sample :: proc(
	body_count, steps, sample_index, warmups: int,
	solver_kind: simcore.Solver_Type,
	theta: f64,
	stats: simcore.Solver_Stats,
	target_label, opt_label, run_id: string,
	file: ^os.File,
) -> (
	BenchmarkResult,
	bool,
) {
	bodies := scenarios.golden_angle_bodies(body_count)
	defer scenarios.destroy_bodies(bodies)

	start := time.tick_now()
	if !run_steps(bodies, steps, solver_kind, theta) {
		return {}, false
	}
	elapsed := time.duration_seconds(time.tick_since(start))

	result := make_result(
		body_count,
		steps,
		sample_index,
		warmups,
		solver_kind,
		theta,
		elapsed,
		stats,
		target_label,
		opt_label,
		run_id,
	)
	if !write_result(file, result) {
		return {}, false
	}
	return result, true
}

same_summary_group :: proc(summary: BenchmarkSummary, result: BenchmarkResult) -> bool {
	return(
		summary.body_count == result.body_count &&
		summary.steps == result.steps &&
		summary.solver == result.solver &&
		summary.theta == result.theta &&
		summary.run_id == result.run_id &&
		summary.target_label == result.target_label &&
		summary.opt_label == result.opt_label \
	)
}

summarize_results :: proc(results: []BenchmarkResult) -> [dynamic]BenchmarkSummary {
	summaries: [dynamic]BenchmarkSummary
	for result in results {
		index := -1
		for summary, i in summaries {
			if same_summary_group(summary, result) {
				index = i
				break
			}
		}
		if index == -1 {
			append(
				&summaries,
				BenchmarkSummary {
					body_count = result.body_count,
					steps = result.steps,
					solver = result.solver,
					theta = result.theta,
					theta_applicable = result.theta_applicable,
					elapsed_min = result.elapsed_seconds,
					elapsed_max = result.elapsed_seconds,
					run_id = result.run_id,
					target_label = result.target_label,
					opt_label = result.opt_label,
				},
			)
			index = len(summaries) - 1
		}

		summary := &summaries[index]
		summary.sample_count += 1
		summary.elapsed_sum += result.elapsed_seconds
		summary.elapsed_squared_sum += result.elapsed_seconds * result.elapsed_seconds
		if result.elapsed_seconds < summary.elapsed_min {
			summary.elapsed_min = result.elapsed_seconds
		}
		if result.elapsed_seconds > summary.elapsed_max {
			summary.elapsed_max = result.elapsed_seconds
		}
		summary.step_seconds_sum += result.average_step_seconds
		summary.interactions_sum += f64(result.interactions)
		summary.direct_interactions_sum += f64(result.direct_interactions)
		summary.approximated_interactions_sum += f64(result.approximated_interactions)
		summary.tree_node_visits_sum += f64(result.tree_node_visits)
		summary.interactions_per_second_sum += result.interactions_per_second
	}
	return summaries
}

summary_mean_elapsed :: proc(summary: BenchmarkSummary) -> f64 {
	if summary.sample_count == 0 {
		return 0
	}
	return summary.elapsed_sum / f64(summary.sample_count)
}

summary_elapsed_stddev :: proc(summary: BenchmarkSummary) -> f64 {
	if summary.sample_count <= 1 {
		return 0
	}
	count := f64(summary.sample_count)
	variance :=
		(summary.elapsed_squared_sum - summary.elapsed_sum * summary.elapsed_sum / count) /
		(count - 1)
	if variance < 0 {
		variance = 0
	}
	return math.sqrt(variance)
}

matching_brute_mean :: proc(
	summaries: []BenchmarkSummary,
	candidate: BenchmarkSummary,
) -> (
	f64,
	bool,
) {
	for summary in summaries {
		if summary.solver == "brute_force" &&
		   summary.body_count == candidate.body_count &&
		   summary.steps == candidate.steps &&
		   summary.target_label == candidate.target_label &&
		   summary.opt_label == candidate.opt_label {
			return summary_mean_elapsed(summary), true
		}
	}
	return 0, false
}

write_summary :: proc(path: string, results: []BenchmarkResult) -> bool {
	file, err := os.open(path, {.Write, .Create, .Trunc}, os.Permissions_Default_File)
	if err != nil {
		return false
	}
	defer os.close(file)

	writer: csv.Writer
	csv.writer_init(&writer, os.to_writer(file))
	header := [?]string {
		"schema_version",
		"scenario",
		"body_count",
		"steps",
		"solver",
		"theta",
		"sample_count",
		"elapsed_mean_seconds",
		"elapsed_stddev_seconds",
		"elapsed_min_seconds",
		"elapsed_max_seconds",
		"average_step_mean_seconds",
		"interactions_mean",
		"direct_interactions_mean",
		"approximated_interactions_mean",
		"tree_node_visits_mean",
		"interactions_per_second_mean",
		"speedup_vs_brute_force",
		"run_id",
		"target_label",
		"opt_label",
	}
	if csv.write(&writer, header[:]) != nil {
		return false
	}

	summaries := summarize_results(results)
	defer delete(summaries)
	for summary in summaries {
		count := f64(summary.sample_count)
		theta_text := ""
		if summary.theta_applicable {
			theta_text = fmt.tprintf("%.16g", summary.theta)
		}
		speedup_text := ""
		if summary.solver == "brute_force" {
			speedup_text = "1"
		} else if brute_mean, ok := matching_brute_mean(summaries[:], summary); ok {
			candidate_mean := summary_mean_elapsed(summary)
			if candidate_mean > 0 {
				speedup_text = fmt.tprintf("%.16g", brute_mean / candidate_mean)
			}
		}
		row := [?]string {
			fmt.tprintf("%d", SCHEMA_VERSION),
			scenarios.GOLDEN_ANGLE_SCENARIO,
			fmt.tprintf("%d", summary.body_count),
			fmt.tprintf("%d", summary.steps),
			summary.solver,
			theta_text,
			fmt.tprintf("%d", summary.sample_count),
			fmt.tprintf("%.16g", summary_mean_elapsed(summary)),
			fmt.tprintf("%.16g", summary_elapsed_stddev(summary)),
			fmt.tprintf("%.16g", summary.elapsed_min),
			fmt.tprintf("%.16g", summary.elapsed_max),
			fmt.tprintf("%.16g", summary.step_seconds_sum / count),
			fmt.tprintf("%.16g", summary.interactions_sum / count),
			fmt.tprintf("%.16g", summary.direct_interactions_sum / count),
			fmt.tprintf("%.16g", summary.approximated_interactions_sum / count),
			fmt.tprintf("%.16g", summary.tree_node_visits_sum / count),
			fmt.tprintf("%.16g", summary.interactions_per_second_sum / count),
			speedup_text,
			summary.run_id,
			summary.target_label,
			summary.opt_label,
		}
		if csv.write(&writer, row[:]) != nil {
			return false
		}
	}
	return csv.writer_flush(&writer) == nil
}

run_configuration :: proc(
	file: ^os.File,
	results: ^[dynamic]BenchmarkResult,
	body_count: int,
	options: BenchmarkOptions,
	solver_kind: simcore.Solver_Type,
	theta: f64,
) -> bool {
	for _ in 0 ..< options.warmups {
		if !run_warmup(body_count, options.steps, solver_kind, theta) {
			return false
		}
	}
	profile_bodies := scenarios.golden_angle_bodies(body_count)
	defer scenarios.destroy_bodies(profile_bodies)
	stats: simcore.Solver_Stats
	if !run_steps(profile_bodies, options.steps, solver_kind, theta, &stats) {
		return false
	}
	for sample in 0 ..< options.samples {
		result, ok := run_sample(
			body_count,
			options.steps,
			sample,
			options.warmups,
			solver_kind,
			theta,
			stats,
			options.target_label,
			options.opt_label,
			options.run_id,
			file,
		)
		if !ok {
			return false
		}
		append(results, result)
	}
	return true
}

run :: proc(output_path: string, options: BenchmarkOptions) -> bool {
	if options.summary_path != "" && options.summary_path == output_path {
		return false
	}
	file, err := os.open(output_path, {.Write, .Append, .Create}, os.Permissions_Default_File)
	if err != nil {
		return false
	}

	results: [dynamic]BenchmarkResult
	defer delete(results)
	all_ok := true
	for count in options.counts {
		if options.mode == .brute_force || options.mode == .both {
			if !run_configuration(file, &results, count, options, .brute_force, 0) {
				all_ok = false
				break
			}
		}
		if options.mode == .barnes_hut || options.mode == .both {
			for theta in options.thetas {
				if !run_configuration(file, &results, count, options, .barnes_hut, theta) {
					all_ok = false
					break
				}
			}
		}
		if !all_ok {
			break
		}
	}
	os.close(file)
	if !all_ok {
		return false
	}
	if options.summary_path != "" {
		return write_summary(options.summary_path, results[:])
	}
	return true
}
