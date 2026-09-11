package benchmark

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import simcore "../core"
import "../integration"
import "../solvers"

BenchmarkConfig :: struct {
	body_count: int,
	steps: int,
	solver_name: string,
	samples: int,
	target_label: string,
	opt_label: string,
}

BenchmarkResult :: struct {
	body_count: int,
	steps: int,
	sample_index: int,
	solver: string,
	elapsed_seconds: f64,
	average_step_seconds: f64,
	interactions: i64,
	interactions_per_second: f64,
	frames_written: int,
	target_label: string,
	opt_label: string,
}

DEFAULT_COUNTS :: [?]int{100, 500, 1000, 5000, 10000}
DEFAULT_STEPS :: 10
DEFAULT_SAMPLES :: 3
DEFAULT_LABEL :: "unspecified"
GOLDEN_ANGLE :: 2.39996322972865332

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

BenchmarkOptions :: struct {
	counts: []int,
	steps: int,
	samples: int,
	target_label: string,
	opt_label: string,
}

destroy_options :: proc(options: ^BenchmarkOptions) {
	delete(options.counts)
	delete(options.target_label)
	delete(options.opt_label)
	options^ = BenchmarkOptions{}
}

default_options :: proc() -> BenchmarkOptions {
	counts := make([]int, len(DEFAULT_COUNTS))
	for value, i in DEFAULT_COUNTS {
		counts[i] = value
	}
	return BenchmarkOptions{
		counts = counts,
		steps = DEFAULT_STEPS,
		samples = DEFAULT_SAMPLES,
		target_label = strings.clone(DEFAULT_LABEL),
		opt_label = strings.clone(DEFAULT_LABEL),
	}
}

parse_options :: proc(args: []string) -> (BenchmarkOptions, string, bool) {
	options := default_options()
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
		case:
			destroy_options(&options)
			return {}, fmt.tprintf("unknown benchmark flag: %s", arg), false
		}
	}
	return options, "", true
}

generate_bodies :: proc(count: int, allocator := context.allocator) -> []simcore.Body {
	bodies := make([]simcore.Body, count, allocator)
	for i in 0..<count {
		index := f64(i)
		radius := math.sqrt(index + 1) / math.sqrt(f64(count))
		angle := index * GOLDEN_ANGLE
		x := radius * math.cos(angle)
		y := radius * math.sin(angle)
		tangent_x := -math.sin(angle) * 0.01
		tangent_y := math.cos(angle) * 0.01
		bodies[i] = simcore.Body{
			id = fmt.aprintf("body_%d", i, allocator = allocator),
			mass = 1.0 + f64(i % 17) * 0.001,
			position = simcore.vec2(x, y),
			velocity = simcore.vec2(tangent_x, tangent_y),
			acceleration = simcore.vec2_zero(),
		}
	}
	return bodies
}

destroy_bodies :: proc(bodies: []simcore.Body) {
	for body in bodies {
		delete(body.id)
	}
	delete(bodies)
}

interactions_for :: proc(body_count, steps: int) -> i64 {
	return i64(body_count) * i64(body_count - 1) * i64(steps)
}

make_result :: proc(body_count, steps, sample_index: int, elapsed_seconds: f64, target_label, opt_label: string) -> BenchmarkResult {
	interactions := interactions_for(body_count, steps)
	avg_step_seconds := 0.0
	if steps > 0 {
		avg_step_seconds = elapsed_seconds / f64(steps)
	}
	interactions_per_second := 0.0
	if elapsed_seconds > 0 {
		interactions_per_second = f64(interactions) / elapsed_seconds
	}
	return BenchmarkResult{
		body_count = body_count,
		steps = steps,
		sample_index = sample_index,
		solver = "brute_force",
		elapsed_seconds = elapsed_seconds,
		average_step_seconds = avg_step_seconds,
		interactions = interactions,
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

run_sample :: proc(body_count, steps, sample_index: int, target_label, opt_label: string, file: ^os.File) -> bool {
	bodies := generate_bodies(body_count)
	defer destroy_bodies(bodies)

	config := simcore.SimulationConfig{
		gravitational_constant = 1.0,
		delta_time = 0.01,
		steps = steps,
		softening = 0.001,
		solver = .brute_force,
		export_enabled = false,
	}
	state := simcore.SimulationState{bodies = bodies, step = 0, time = 0}
	solver := solvers.get_solver(.brute_force)

	start := time.tick_now()
	for _ in 0..<steps {
		status := simcore.step_state(&state, config, solver, integration.semi_implicit_euler)
		if status != .ok {
			return false
		}
	}
	elapsed := time.duration_seconds(time.tick_since(start))
	result := make_result(body_count, steps, sample_index, elapsed, target_label, opt_label)
	return write_result(file, result)
}

run :: proc(output_path: string, options: BenchmarkOptions) -> bool {
	file, err := os.open(output_path, {.Write, .Append, .Create}, os.Permissions_Default_File)
	if err != nil {
		return false
	}
	defer os.close(file)

	for count in options.counts {
		for sample in 0..<options.samples {
			if !run_sample(count, options.steps, sample, options.target_label, options.opt_label, file) {
				return false
			}
		}
	}
	return true
}
