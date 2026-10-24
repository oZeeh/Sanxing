package cli

import "core:fmt"
import "core:strings"

Command_Kind :: enum {
	help,
	simulate,
	benchmark,
	accuracy,
}

Parsed_Command :: struct {
	kind:             Command_Kind,
	help_topic:       string,
	input_path:       string,
	output_path:      string,
	diagnostics_path: string,
	options:          [dynamic]string,
}

destroy_command :: proc(command: ^Parsed_Command) {
	delete(command.options)
	command^ = Parsed_Command{}
}

is_help_flag :: proc(value: string) -> bool {
	return value == "--help" || value == "-h"
}

has_flag_prefix :: proc(value: string) -> bool {
	return strings.has_prefix(value, "-")
}

assign_once :: proc(target: ^string, value, label: string) -> (string, bool) {
	if target^ != "" {
		return fmt.tprintf("%s was provided more than once", label), false
	}
	if value == "" {
		return fmt.tprintf("%s must be nonempty", label), false
	}
	target^ = value
	return "", true
}

parse_simulate :: proc(args: []string) -> (Parsed_Command, string, bool) {
	command := Parsed_Command{kind = .simulate}
	for i := 0; i < len(args); i += 1 {
		arg := args[i]
		if is_help_flag(arg) {
			destroy_command(&command)
			return Parsed_Command{kind = .help, help_topic = "simulate"}, "", true
		}
		if arg == "-i" || arg == "--input" || arg == "-o" || arg == "--output" || arg == "--diagnostics" {
			if i + 1 >= len(args) {
				destroy_command(&command)
				return {}, fmt.tprintf("%s requires a value", arg), false
			}
			value := args[i + 1]
			i += 1
			message, ok := "", false
			switch arg {
			case "-i", "--input":
				message, ok = assign_once(&command.input_path, value, "simulation input")
			case "-o", "--output":
				message, ok = assign_once(&command.output_path, value, "simulation output")
			case "--diagnostics":
				message, ok = assign_once(&command.diagnostics_path, value, "diagnostics output")
			}
			if !ok {
				destroy_command(&command)
				return {}, message, false
			}
			continue
		}
		if has_flag_prefix(arg) {
			destroy_command(&command)
			return {}, fmt.tprintf("unknown simulate flag: %s", arg), false
		}
		message, ok := "", false
		if command.input_path == "" {
			message, ok = assign_once(&command.input_path, arg, "simulation input")
		} else if command.output_path == "" {
			message, ok = assign_once(&command.output_path, arg, "simulation output")
		} else {
			destroy_command(&command)
			return {}, fmt.tprintf("unexpected simulate argument: %s", arg), false
		}
		if !ok {
			destroy_command(&command)
			return {}, message, false
		}
	}
	if command.input_path == "" {
		destroy_command(&command)
		return {}, "simulate requires an input JSON path", false
	}
	if command.output_path == "" {
		destroy_command(&command)
		return {}, "simulate requires an output JSONL path", false
	}
	return command, "", true
}

parse_result_command :: proc(kind: Command_Kind, topic: string, args: []string) -> (Parsed_Command, string, bool) {
	command := Parsed_Command{kind = kind}
	for i := 0; i < len(args); i += 1 {
		arg := args[i]
		if is_help_flag(arg) {
			destroy_command(&command)
			return Parsed_Command{kind = .help, help_topic = topic}, "", true
		}
		if arg == "-o" || arg == "--output" {
			if i + 1 >= len(args) {
				destroy_command(&command)
				return {}, fmt.tprintf("%s requires a value", arg), false
			}
			message, ok := assign_once(&command.output_path, args[i + 1], fmt.tprintf("%s output", topic))
			i += 1
			if !ok {
				destroy_command(&command)
				return {}, message, false
			}
			continue
		}
		if has_flag_prefix(arg) {
			if i + 1 >= len(args) {
				destroy_command(&command)
				return {}, fmt.tprintf("%s requires a value", arg), false
			}
			append(&command.options, arg, args[i + 1])
			i += 1
			continue
		}
		message, ok := assign_once(&command.output_path, arg, fmt.tprintf("%s output", topic))
		if !ok {
			destroy_command(&command)
			return {}, message, false
		}
	}
	if command.output_path == "" {
		destroy_command(&command)
		return {}, fmt.tprintf("%s requires an output path", topic), false
	}
	return command, "", true
}

parse :: proc(args: []string) -> (Parsed_Command, string, bool) {
	if len(args) == 0 {
		return Parsed_Command{kind = .help}, "", true
	}
	if args[0] == "help" || is_help_flag(args[0]) {
		topic := ""
		if args[0] == "help" && len(args) > 1 {
			topic = args[1]
			if topic != "simulate" && topic != "benchmark" && topic != "accuracy" {
				return {}, fmt.tprintf("unknown help topic: %s", topic), false
			}
		}
		if len(args) > 2 || (args[0] != "help" && len(args) > 1) {
			return {}, "help accepts at most one command name", false
		}
		return Parsed_Command{kind = .help, help_topic = topic}, "", true
	}
	switch args[0] {
	case "simulate":
		return parse_simulate(args[1:])
	case "benchmark":
		return parse_result_command(.benchmark, "benchmark", args[1:])
	case "accuracy":
		return parse_result_command(.accuracy, "accuracy", args[1:])
	case:
		return {}, fmt.tprintf("unknown command: %s", args[0]), false
	}
}

root_help :: proc(program: string) -> string {
	return fmt.tprintf(
		"Sanxing — deterministic 2D N-body simulation\n\nUsage:\n  %s <command> [options]\n\nCommands:\n  simulate   Run a JSON-configured simulation and write JSONL replay data\n  benchmark  Compare solver performance across deterministic workloads\n  accuracy   Compare Barnes-Hut acceleration against brute force\n  help       Show general or command-specific help\n\nRun '%s help <command>' for details.",
		program,
		program,
	)
}

command_help :: proc(program, topic: string) -> string {
	switch topic {
	case "simulate":
		return fmt.tprintf("Usage:\n  %s simulate INPUT OUTPUT [--diagnostics PATH]\n  %s simulate --input INPUT --output OUTPUT [--diagnostics PATH]\n\nOptions:\n  -i, --input PATH       Strict simulation JSON input\n  -o, --output PATH      JSONL replay output\n      --diagnostics PATH Diagnostics JSONL output\n  -h, --help             Show this help", program, program)
	case "benchmark":
		return fmt.tprintf("Usage:\n  %s benchmark OUTPUT [options]\n  %s benchmark --output OUTPUT [options]\n\nOptions:\n  -o, --output PATH      Raw benchmark JSONL output\n      --summary PATH     Aggregate CSV output\n      --counts N,N       Positive body counts (default: 100,500,1000,5000,10000)\n      --steps N          Integration steps (default: 10)\n      --samples N        Timed samples (default: 3)\n      --warmups N        Untimed warmups (default: 1)\n      --solver MODE      brute_force, barnes_hut, or both\n      --theta N          One Barnes-Hut theta\n      --thetas N,N       Unique Barnes-Hut theta sweep\n      --run-id TEXT      Run provenance label\n      --target-label TEXT Target provenance label\n      --opt-label TEXT   Optimization provenance label\n  -h, --help             Show this help", program, program)
	case "accuracy":
		return fmt.tprintf("Usage:\n  %s accuracy OUTPUT [options]\n  %s accuracy --output OUTPUT [options]\n\nOptions:\n  -o, --output PATH      Raw accuracy JSONL output\n      --summary PATH     Aggregate CSV output\n      --counts N,N       Positive body counts\n      --thetas N,N       Unique nonnegative theta values\n      --run-id TEXT      Run provenance label\n      --target-label TEXT Target provenance label\n      --opt-label TEXT   Optimization provenance label\n  -h, --help             Show this help", program, program)
	}
	return root_help(program)
}
