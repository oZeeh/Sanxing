package main

import "accuracy"
import "benchmark"
import "cli"
import simcore "core"
import "core:fmt"
import "core:os"
import jsonl "export"
import sim_input "input"
import "integration"
import "solvers"

run_simulation :: proc(input: sim_input.SimulationInput, output_path: string, diagnostics_path: string = "") -> bool {
	if !simcore.validate_config(input.config) {
		fmt.eprintln("error: invalid simulation config")
		return false
	}

	state := simcore.SimulationState{bodies = input.bodies, step = 0, time = 0}
	writer: jsonl.Writer
	diagnostics_writer: jsonl.Writer
	defer {
		if writer.file != nil { jsonl.writer_close(&writer) }
		if diagnostics_writer.file != nil { jsonl.writer_close(&diagnostics_writer) }
	}
	if diagnostics_path != "" {
		ok: bool
		diagnostics_writer, ok = jsonl.writer_open(diagnostics_path)
		if !ok {
			fmt.eprintfln("error: failed to open diagnostics output: %s", diagnostics_path)
			return false
		}
		if !jsonl.write_diagnostics(&diagnostics_writer, state, input.config) {
			fmt.eprintln("error: failed to write diagnostics for frame 0")
			return false
		}
	}
	if input.config.export_enabled {
		ok: bool
		writer, ok = jsonl.writer_open(output_path)
		if !ok {
			fmt.eprintfln("error: failed to open JSONL output: %s", output_path)
			return false
		}
		if !jsonl.write_frame(&writer, state) {
			fmt.eprintln("error: failed to write frame 0")
			return false
		}
	}

	solver := solvers.get_solver(input.config.solver)
	for _ in 0 ..< input.config.steps {
		status := simcore.step_state(&state, input.config, solver, integration.semi_implicit_euler)
		if status != .ok {
			fmt.eprintfln("error: simulation stopped with status: %v", status)
			return false
		}
		if input.config.export_enabled && !jsonl.write_frame(&writer, state) {
			fmt.eprintfln("error: failed to write frame %d", state.step)
			return false
		}
		if diagnostics_path != "" && !jsonl.write_diagnostics(&diagnostics_writer, state, input.config) {
			fmt.eprintfln("error: failed to write diagnostics for step %d", state.step)
			return false
		}
	}
	return true
}

print_help :: proc(program: string, topic: string = "") {
	if topic == "" {
		fmt.println(cli.root_help(program))
	} else {
		fmt.println(cli.command_help(program, topic))
	}
}

main :: proc() {
	program := "sanxing"
	command, message, ok := cli.parse(os.args[1:])
	if !ok {
		fmt.eprintfln("error: %s", message)
		fmt.eprintfln("Run '%s --help' for usage.", program)
		os.exit(2)
	}
	defer cli.destroy_command(&command)

	switch command.kind {
	case .help:
		print_help(program, command.help_topic)
	case .simulate:
		input, validation, loaded := sim_input.load_input(command.input_path)
		defer sim_input.destroy_validation_result(&validation)
		if !loaded {
			for err in validation.errors { fmt.eprintfln("error: %s", err) }
			os.exit(1)
		}
		defer sim_input.destroy_input(&input)
		fmt.printfln(
			"Simulating %d bodies for %d steps with %v...",
			len(input.bodies),
			input.config.steps,
			input.config.solver,
		)
		if !run_simulation(input, command.output_path, command.diagnostics_path) { os.exit(1) }
		if input.config.export_enabled {
			fmt.printfln("Simulation complete: %d frames written to %s", input.config.steps + 1, command.output_path)
		} else {
			fmt.println("Simulation complete: replay export disabled by configuration")
		}
		if command.diagnostics_path != "" {
			fmt.printfln("Diagnostics: %s", command.diagnostics_path)
		}
	case .benchmark:
		options, parse_message, parsed := benchmark.parse_options(command.options[:])
		if !parsed {
			fmt.eprintfln("error: %s", parse_message)
			fmt.eprintfln("Run '%s help benchmark' for usage.", program)
			os.exit(2)
		}
		defer benchmark.destroy_options(&options)
		fmt.printfln("Running benchmark for %d body counts -> %s", len(options.counts), command.output_path)
		if !benchmark.run(command.output_path, options) {
			fmt.eprintfln("error: benchmark failed writing results: %s", command.output_path)
			os.exit(1)
		}
		fmt.printfln("Benchmark complete: %s", command.output_path)
		if options.summary_path != "" { fmt.printfln("Summary: %s", options.summary_path) }
	case .accuracy:
		options, parse_message, parsed := accuracy.parse_options(command.options[:])
		if !parsed {
			fmt.eprintfln("error: %s", parse_message)
			fmt.eprintfln("Run '%s help accuracy' for usage.", program)
			os.exit(2)
		}
		defer accuracy.destroy_options(&options)
		fmt.printfln("Measuring force accuracy for %d body counts -> %s", len(options.counts), command.output_path)
		if !accuracy.run(command.output_path, options) {
			fmt.eprintfln("error: accuracy run failed writing results: %s", command.output_path)
			os.exit(1)
		}
		fmt.printfln("Accuracy run complete: %s", command.output_path)
		if options.summary_path != "" { fmt.printfln("Summary: %s", options.summary_path) }
	}
}
