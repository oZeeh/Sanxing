package sim_export

import "core:encoding/json"
import "core:os"
import "core:strings"
import "core:testing"
import simcore "../core"

@(test)
test_jsonl_frame_structure :: proc(t: ^testing.T) {
	path := "/tmp/sanxing-export-test.jsonl"
	writer, ok := writer_open(path)
	testing.expect(t, ok)
	defer writer_close(&writer)

	bodies := [?]simcore.Body{
		{
			id = "a",
			mass = 1,
			position = simcore.vec2(1, 2),
			velocity = simcore.vec2(3, 4),
			acceleration = simcore.vec2(5, 6),
		},
	}
	state := simcore.SimulationState{bodies = bodies[:], step = 7, time = 0.25}

	testing.expect(t, write_frame(&writer, state))
	writer_close(&writer)

	data, read_err := os.read_entire_file(path, context.allocator)
	testing.expect(t, read_err == nil)
	defer delete(data)

	text := string(data)
	testing.expect(t, strings.contains(text, `"step":7`))
	testing.expect(t, strings.contains(text, `"time":0.25`))
	testing.expect(t, strings.contains(text, `"id":"a"`))
	testing.expect(t, strings.ends_with(text, "\n"))

	value, parse_err := json.parse(data, .JSON)
	testing.expect(t, parse_err == nil)
	json.destroy_value(value)
}
