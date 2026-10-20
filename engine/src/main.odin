package main

import "accuracy"
import "benchmark"
import simcore "core"
import "core:fmt"
import "core:os"
import jsonl "export"
import sim_input "input"
import "integration"
import "solvers"

run_simulation :: proc(input: sim_input.SimulationInput, output_path: string, diagnostics_path: string = "") -> bool {
	if !simcore.validate_config(input.config) {
		fmt.eprintln("invalid simulation config")
		return false
	}

	state := simcore.SimulationState {
		bodies = input.bodies,
		step   = 0,
		time   = 0,
	}

	writer: jsonl.Writer
	diagnostics_writer: jsonl.Writer
	defer {
		if writer.file != nil {
			jsonl.writer_close(&writer)
		}
		if diagnostics_writer.file != nil {
			jsonl.writer_close(&diagnostics_writer)
		}
	}
	if diagnostics_path != "" {
		ok: bool
		diagnostics_writer, ok = jsonl.writer_open(diagnostics_path)
		if !ok {
			fmt.eprintfln("failed to open diagnostics output: %s", diagnostics_path)
			return false
		}
		if !jsonl.write_diagnostics(&diagnostics_writer, state, input.config) {
			fmt.eprintln("failed to write diagnostics for frame 0")
			return false
		}
	}
	if input.config.export_enabled {
		ok: bool
		writer, ok = jsonl.writer_open(output_path)
		if !ok {
			fmt.eprintfln("failed to open JSONL output: %s", output_path)
			return false
		}

		if !jsonl.write_frame(&writer, state) {
			fmt.eprintln("failed to write frame 0")
			return false
		}
	}

	solver := solvers.get_solver(input.config.solver)
	for _ in 0 ..< input.config.steps {
		status := simcore.step_state(&state, input.config, solver, integration.semi_implicit_euler)
		if status != .ok {
			fmt.eprintfln("simulation stopped with status: %v", status)
			return false
		}

		if input.config.export_enabled && !jsonl.write_frame(&writer, state) {
			fmt.eprintfln("failed to write frame %d", state.step)
			return false
		}
		if diagnostics_path != "" && !jsonl.write_diagnostics(&diagnostics_writer, state, input.config) {
			fmt.eprintfln("failed to write diagnostics for step %d", state.step)
			return false
		}
	}

	return true
}

print_usage :: proc(program: string) {
	fmt.eprintfln("usage: %s simulate <input.json> <output.jsonl> [--diagnostics diagnostics.jsonl]", program)
	fmt.eprintfln(
		"       %s benchmark <results.jsonl> [--summary summary.csv] [--counts 100,500] [--steps N] [--samples N] [--warmups N] [--solver brute_force|barnes_hut|both] [--theta N | --thetas N,N] [--run-id TEXT] [--target-label TEXT] [--opt-label TEXT]",
		program,
	)
	fmt.eprintfln("       %s accuracy <results.jsonl> [--summary summary.csv] [--counts 100,500] [--thetas 0,0.5] [--run-id TEXT] [--target-label TEXT] [--opt-label TEXT]", program)
}

main :: proc() {
	args := os.args
	if len(args) < 2 {
		print_usage(args[0])
		os.exit(2)
	}

	switch args[1] {
	case "simulate":
		if len(args) != 4 && len(args) != 6 {
			print_usage(args[0])
			os.exit(2)
		}
		diagnostics_path := ""
		if len(args) == 6 {
			if args[4] != "--diagnostics" || args[5] == "" {
				print_usage(args[0])
				os.exit(2)
			}
			diagnostics_path = args[5]
		}

		input, validation, ok := sim_input.load_input(args[2])
		defer sim_input.destroy_validation_result(&validation)
		if !ok {
			for err in validation.errors {
				fmt.eprintln(err)
			}
			os.exit(1)
		}
		defer sim_input.destroy_input(&input)

		if !run_simulation(input, args[3], diagnostics_path) {
			os.exit(1)
		}
	case "benchmark":
		if len(args) < 3 {
			print_usage(args[0])
			os.exit(2)
		}
		options, message, ok := benchmark.parse_options(args[3:])
		if !ok {
			fmt.eprintln(message)
			print_usage(args[0])
			os.exit(2)
		}
		defer benchmark.destroy_options(&options)

		if !benchmark.run(args[2], options) {
			fmt.eprintfln("benchmark failed writing results: %s", args[2])
			os.exit(1)
		}
	case "accuracy":
		if len(args) < 3 {
			print_usage(args[0])
			os.exit(2)
		}
		options, message, ok := accuracy.parse_options(args[3:])
		if !ok {
			fmt.eprintln(message)
			print_usage(args[0])
			os.exit(2)
		}
		defer accuracy.destroy_options(&options)
		if !accuracy.run(args[2], options) {
			fmt.eprintfln("accuracy run failed writing results: %s", args[2])
			os.exit(1)
		}
	case:
		print_usage(args[0])
		os.exit(2)
	}
}
