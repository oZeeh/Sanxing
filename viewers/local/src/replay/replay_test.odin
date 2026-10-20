package replay

import "core:os"
import "core:testing"

@(test)
test_parse_frame_and_source_bounds :: proc(t: ^testing.T) {
	line := `{"step":0,"time":0,"future":true,"bodies":[{"id":"a","mass":1,"position":{"x":0,"y":1},"velocity":{"x":2,"y":3},"acceleration":{"x":4,"y":5}}]}`
	frame, message, ok := parse_frame(transmute([]byte)line, 1)
	defer delete(message)
	testing.expect(t, ok)
	if !ok { return }
	defer destroy_frame(&frame)
	testing.expect_value(t, frame.bodies[0].id, "a")
}

@(test)
test_load_rejects_duplicate_body_ids :: proc(t: ^testing.T) {
	line := `{"step":0,"time":0,"bodies":[{"id":"a","mass":1,"position":{"x":0,"y":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0}},{"id":"a","mass":1,"position":{"x":1,"y":0},"velocity":{"x":0,"y":0},"acceleration":{"x":0,"y":0}}]}`
	frame, message, ok := parse_frame(transmute([]byte)line, 3)
	defer delete(message)
	if ok { destroy_frame(&frame) }
	testing.expect(t, !ok)
}

@(test)
test_load_and_seek_clamps :: proc(t: ^testing.T) {
	path := "/tmp/sanxing-replay-test.jsonl"
	data := "{\"step\":0,\"time\":0,\"bodies\":[]}\n{\"step\":1,\"time\":0.1,\"bodies\":[]}\n"
	write_err := os.write_entire_file_from_string(path, data)
	testing.expect(t, write_err == nil)
	defer os.remove(path)
	value, message, ok := load(path)
	defer delete(message)
	testing.expect(t, ok)
	if !ok { return }
	defer destroy(&value)
	set_index(&value, 10)
	testing.expect_value(t, value.index, 1)
	src := source(&value)
	testing.expect_value(t, frame_count(src), 2)
	_, found := frame_at(src, 2)
	testing.expect(t, !found)
}
