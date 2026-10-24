package cli

import "core:strings"
import "core:testing"

@(test)
test_help_forms :: proc(t: ^testing.T) {
	cases := [?][]string {
		[]string{},
		[]string{"--help"},
		[]string{"help"},
		[]string{"help", "simulate"},
		[]string{"benchmark", "-h"},
	}
	for args in cases {
		command, _, ok := parse(args)
		testing.expect(t, ok)
		testing.expect_value(t, command.kind, Command_Kind.help)
		destroy_command(&command)
	}
	text := command_help("sanxing", "simulate")
	testing.expect(t, strings.contains(text, "--input"))
	testing.expect(t, strings.contains(text, "--diagnostics"))
}

@(test)
test_simulate_legacy_named_and_mixed_paths :: proc(t: ^testing.T) {
	cases := [?][]string{
		[]string{"simulate", "input.json", "output.jsonl"},
		[]string{"simulate", "--input", "input.json", "--output", "output.jsonl"},
		[]string{"simulate", "input.json", "-o", "output.jsonl", "--diagnostics", "diagnostics.jsonl"},
		[]string{"simulate", "--input", "input.json", "output.jsonl"},
		[]string{"simulate", "--output", "output.jsonl", "input.json"},
	}
	for args in cases {
		command, message, ok := parse(args)
		testing.expect(t, ok, message)
		testing.expect_value(t, command.input_path, "input.json")
		testing.expect_value(t, command.output_path, "output.jsonl")
		destroy_command(&command)
	}
}

@(test)
test_result_command_preserves_package_options :: proc(t: ^testing.T) {
	command, message, ok := parse([]string{"benchmark", "--counts", "10,20", "-o", "raw.jsonl", "--solver", "both"})
	testing.expect(t, ok, message)
	testing.expect_value(t, command.output_path, "raw.jsonl")
	testing.expect_value(t, len(command.options), 4)
	testing.expect_value(t, command.options[0], "--counts")
	testing.expect_value(t, command.options[3], "both")
	destroy_command(&command)
}

@(test)
test_cli_rejects_missing_duplicate_and_unknown_values :: proc(t: ^testing.T) {
	cases := [?][]string{
		[]string{"simulate", "input.json"},
		[]string{"simulate", "input.json", "output.jsonl", "--output", "other.jsonl"},
		[]string{"simulate", "--unknown", "value"},
		[]string{"benchmark", "--output"},
		[]string{"accuracy"},
		[]string{"help", "unknown"},
		[]string{"unknown"},
	}
	for args in cases {
		command, _, ok := parse(args)
		if ok { destroy_command(&command) }
		testing.expect(t, !ok)
	}
}
