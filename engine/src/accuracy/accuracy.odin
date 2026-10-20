package accuracy

import simcore "../core"
import "../scenarios"
import "../solvers"
import csv "core:encoding/csv"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"

SCHEMA_VERSION :: 1
RECORD_TYPE :: "solver_accuracy"
DEFAULT_LABEL :: "unspecified"

Accuracy_Result :: struct {
	schema_version:                  int,
	record_type:                     string,
	run_id:                          string,
	scenario:                        string,
	body_count:                      int,
	theta:                           f64,
	normalized_l2_acceleration_error: f64,
	mean_absolute_acceleration_error: f64,
	max_absolute_acceleration_error:  f64,
	direct_interactions:             i64,
	approximated_interactions:       i64,
	tree_node_visits:                i64,
	target_label:                    string,
	opt_label:                       string,
}

Options :: struct {
	counts:       []int,
	thetas:       []f64,
	run_id:       string,
	target_label: string,
	opt_label:    string,
	summary_path: string,
}

destroy_options :: proc(options: ^Options) {
	delete(options.counts)
	delete(options.thetas)
	delete(options.run_id)
	delete(options.target_label)
	delete(options.opt_label)
	delete(options.summary_path)
	options^ = Options{}
}

parse_int_list :: proc(text: string) -> ([]int, bool) {
	parts := strings.split(text, ",")
	defer delete(parts)
	values: [dynamic]int
	for part in parts {
		value, ok := strconv.parse_int(part, 10)
		if !ok || value <= 0 {
			delete(values)
			return nil, false
		}
		append(&values, value)
	}
	return values[:], len(values) > 0
}

parse_float_list :: proc(text: string) -> ([]f64, bool) {
	parts := strings.split(text, ",")
	defer delete(parts)
	values: [dynamic]f64
	for part in parts {
		value, ok := strconv.parse_f64(part)
		if !ok || value < 0 || math.is_nan(value) || math.is_inf(value) {
			delete(values)
			return nil, false
		}
		for existing in values {
			if existing == value {
				delete(values)
				return nil, false
			}
		}
		append(&values, value)
	}
	return values[:], len(values) > 0
}

parse_options :: proc(args: []string) -> (Options, string, bool) {
	counts := make([]int, 5)
	copy(counts, []int{100, 500, 1000, 5000, 10000})
	thetas := make([]f64, 4)
	copy(thetas, []f64{0, 0.25, 0.5, 1.0})
	options := Options {
		counts = counts,
		thetas = thetas,
		run_id = strings.clone(DEFAULT_LABEL),
		target_label = strings.clone(DEFAULT_LABEL),
		opt_label = strings.clone(DEFAULT_LABEL),
	}
	for i := 0; i < len(args); i += 2 {
		if i + 1 >= len(args) {
			destroy_options(&options)
			return {}, fmt.tprintf("%s requires a value", args[i]), false
		}
		flag, value := args[i], args[i + 1]
		switch flag {
		case "--counts":
			parsed, ok := parse_int_list(value)
			if !ok {
				destroy_options(&options)
				return {}, "--counts must contain positive integers", false
			}
			delete(options.counts)
			options.counts = parsed
		case "--thetas":
			parsed, ok := parse_float_list(value)
			if !ok {
				destroy_options(&options)
				return {}, "--thetas must contain unique nonnegative finite numbers", false
			}
			delete(options.thetas)
			options.thetas = parsed
		case "--run-id":
			if value == "" { destroy_options(&options); return {}, "--run-id must be nonempty", false }
			delete(options.run_id); options.run_id = strings.clone(value)
		case "--target-label":
			if value == "" { destroy_options(&options); return {}, "--target-label must be nonempty", false }
			delete(options.target_label); options.target_label = strings.clone(value)
		case "--opt-label":
			if value == "" { destroy_options(&options); return {}, "--opt-label must be nonempty", false }
			delete(options.opt_label); options.opt_label = strings.clone(value)
		case "--summary":
			if value == "" { destroy_options(&options); return {}, "--summary must be nonempty", false }
			delete(options.summary_path); options.summary_path = strings.clone(value)
		case:
			destroy_options(&options)
			return {}, fmt.tprintf("unknown accuracy flag: %s", flag), false
		}
	}
	return options, "", true
}

measure_acceleration_error :: proc(candidate, baseline: []simcore.Body) -> (f64, f64, f64) {
	if len(candidate) == 0 || len(candidate) != len(baseline) {
		return 0, 0, 0
	}
	error_sq, baseline_sq, total, maximum := 0.0, 0.0, 0.0, 0.0
	for body, i in candidate {
		delta := simcore.vec2_sub(body.acceleration, baseline[i].acceleration)
		absolute := simcore.vec2_length(delta)
		error_sq += simcore.vec2_length_sq(delta)
		baseline_sq += simcore.vec2_length_sq(baseline[i].acceleration)
		total += absolute
		if absolute > maximum { maximum = absolute }
	}
	normalized := 0.0
	if baseline_sq > 0 { normalized = math.sqrt(error_sq / baseline_sq) }
	return normalized, total / f64(len(candidate)), maximum
}

make_result :: proc(count: int, theta: f64, candidate, baseline: []simcore.Body, stats: simcore.Solver_Stats, options: Options) -> Accuracy_Result {
	normalized, mean_absolute, max_absolute := measure_acceleration_error(candidate, baseline)
	return Accuracy_Result {
		schema_version = SCHEMA_VERSION,
		record_type = RECORD_TYPE,
		run_id = options.run_id,
		scenario = scenarios.FORCE_ACCURACY_SCENARIO,
		body_count = count,
		theta = theta,
		normalized_l2_acceleration_error = normalized,
		mean_absolute_acceleration_error = mean_absolute,
		max_absolute_acceleration_error = max_absolute,
		direct_interactions = stats.direct_interactions,
		approximated_interactions = stats.approximated_interactions,
		tree_node_visits = stats.tree_node_visits,
		target_label = options.target_label,
		opt_label = options.opt_label,
	}
}

write_jsonl :: proc(file: ^os.File, result: Accuracy_Result) -> bool {
	data, err := json.marshal(result, json.Marshal_Options{spec = .JSON})
	if err != nil { return false }
	defer delete(data)
	if _, write_err := os.write(file, data); write_err != nil { return false }
	_, newline_err := os.write_string(file, "\n")
	return newline_err == nil
}

write_summary :: proc(path: string, results: []Accuracy_Result) -> bool {
	file, err := os.open(path, {.Write, .Create, .Trunc}, os.Permissions_Default_File)
	if err != nil { return false }
	defer os.close(file)
	writer: csv.Writer
	csv.writer_init(&writer, os.to_writer(file))
	header := [?]string{"schema_version", "run_id", "scenario", "body_count", "theta", "normalized_l2_acceleration_error", "mean_absolute_acceleration_error", "max_absolute_acceleration_error", "direct_interactions", "approximated_interactions", "tree_node_visits", "target_label", "opt_label"}
	if csv.write(&writer, header[:]) != nil { return false }
	for result in results {
		row := [?]string{
			fmt.tprintf("%d", result.schema_version), result.run_id, result.scenario,
			fmt.tprintf("%d", result.body_count), fmt.tprintf("%.16g", result.theta),
			fmt.tprintf("%.16g", result.normalized_l2_acceleration_error),
			fmt.tprintf("%.16g", result.mean_absolute_acceleration_error),
			fmt.tprintf("%.16g", result.max_absolute_acceleration_error),
			fmt.tprintf("%d", result.direct_interactions), fmt.tprintf("%d", result.approximated_interactions),
			fmt.tprintf("%d", result.tree_node_visits), result.target_label, result.opt_label,
		}
		if csv.write(&writer, row[:]) != nil { return false }
	}
	return csv.writer_flush(&writer) == nil
}

run :: proc(output_path: string, options: Options) -> bool {
	if options.summary_path != "" && options.summary_path == output_path { return false }
	file, err := os.open(output_path, {.Write, .Append, .Create}, os.Permissions_Default_File)
	if err != nil { return false }
	defer os.close(file)
	results: [dynamic]Accuracy_Result
	defer delete(results)
	config := simcore.SimulationConfig{gravitational_constant = 1, delta_time = 0.01, softening = 0.001, theta = 0.5, solver = .brute_force}
	for count in options.counts {
		initial := scenarios.golden_angle_bodies(count)
		defer scenarios.destroy_bodies(initial)
		baseline := scenarios.clone_bodies(initial)
		defer scenarios.destroy_bodies(baseline)
		if solvers.brute_force(baseline, config, nil) != .ok { return false }
		for theta in options.thetas {
			candidate := scenarios.clone_bodies(initial)
			config.theta = theta
			stats: simcore.Solver_Stats
			if solvers.barnes_hut(candidate, config, &stats) != .ok {
				scenarios.destroy_bodies(candidate)
				return false
			}
			result := make_result(count, theta, candidate, baseline, stats, options)
			scenarios.destroy_bodies(candidate)
			if !write_jsonl(file, result) { return false }
			append(&results, result)
		}
	}
	if options.summary_path != "" { return write_summary(options.summary_path, results[:]) }
	return true
}
