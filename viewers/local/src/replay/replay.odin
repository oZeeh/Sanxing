package replay

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"

Vec2 :: struct { x, y: f64 }
Body_Frame :: struct {
	id: string,
	mass: f64,
	position, velocity, acceleration: Vec2,
}
Simulation_Frame :: struct {
	step: int,
	time: f64,
	bodies: [dynamic]Body_Frame,
}
Replay :: struct {
	frames: [dynamic]Simulation_Frame,
	index: int,
}

Frame_Source :: struct {
	ctx: rawptr,
	frame_count_proc: proc(rawptr) -> int,
	frame_at_proc: proc(rawptr, int) -> (^Simulation_Frame, bool),
	finite: bool,
	seekable: bool,
}

destroy_frame :: proc(frame: ^Simulation_Frame) {
	for body in frame.bodies { delete(body.id) }
	delete(frame.bodies)
	frame^ = Simulation_Frame{}
}

destroy :: proc(value: ^Replay) {
	for &frame in value.frames { destroy_frame(&frame) }
	delete(value.frames)
	value^ = Replay{}
}

as_object :: proc(value: json.Value) -> (json.Object, bool) {
	#partial switch item in value { case json.Object: return item, true }
	return nil, false
}
as_array :: proc(value: json.Value) -> (json.Array, bool) {
	#partial switch item in value { case json.Array: return item, true }
	return nil, false
}
as_string :: proc(value: json.Value) -> (string, bool) {
	#partial switch item in value { case json.String: return string(item), true }
	return "", false
}
as_f64 :: proc(value: json.Value) -> (f64, bool) {
	#partial switch item in value {
	case json.Float: return f64(item), true
	case json.Integer: return f64(item), true
	}
	return 0, false
}
as_int :: proc(value: json.Value) -> (int, bool) {
	#partial switch item in value {
	case json.Integer: return int(item), true
	case json.Float:
		number := f64(item)
		if finite(number) && number == math.floor(number) { return int(number), true }
	}
	return 0, false
}
finite :: proc(value: f64) -> bool { return !math.is_nan(value) && !math.is_inf(value) }

read_number :: proc(object: json.Object, key: string) -> (f64, bool) {
	value, found := object[key]
	if !found { return 0, false }
	number, ok := as_f64(value)
	return number, ok && finite(number)
}

read_vec2 :: proc(object: json.Object, key: string) -> (Vec2, bool) {
	value, found := object[key]
	if !found { return {}, false }
	vector, ok := as_object(value)
	if !ok { return {}, false }
	x, x_ok := read_number(vector, "x")
	y, y_ok := read_number(vector, "y")
	return Vec2{x = x, y = y}, x_ok && y_ok
}

parse_frame :: proc(line: []byte, line_number: int) -> (Simulation_Frame, string, bool) {
	value, parse_err := json.parse(line, .JSON)
	if parse_err != nil { return {}, fmt.aprintf("line %d: invalid JSON", line_number), false }
	defer json.destroy_value(value)
	object, ok := as_object(value)
	if !ok { return {}, fmt.aprintf("line %d: frame must be an object", line_number), false }
	step_value, found := object["step"]
	if !found { return {}, fmt.aprintf("line %d: missing step", line_number), false }
	step, step_ok := as_int(step_value)
	time, time_ok := read_number(object, "time")
	bodies_value, bodies_found := object["bodies"]
	if !step_ok || step < 0 || !time_ok || !bodies_found {
		return {}, fmt.aprintf("line %d: invalid step, time, or bodies", line_number), false
	}
	bodies_array, array_ok := as_array(bodies_value)
	if !array_ok { return {}, fmt.aprintf("line %d: bodies must be an array", line_number), false }
	frame := Simulation_Frame{step = step, time = time}
	for value, body_index in bodies_array {
		body_object, body_ok := as_object(value)
		if !body_ok { destroy_frame(&frame); return {}, fmt.aprintf("line %d body %d: must be an object", line_number, body_index), false }
		id_value, id_found := body_object["id"]
		id, id_ok := as_string(id_value)
		mass, mass_ok := read_number(body_object, "mass")
		position, position_ok := read_vec2(body_object, "position")
		velocity, velocity_ok := read_vec2(body_object, "velocity")
		acceleration, acceleration_ok := read_vec2(body_object, "acceleration")
		if !id_found || !id_ok || id == "" || !mass_ok || mass <= 0 || !position_ok || !velocity_ok || !acceleration_ok {
			destroy_frame(&frame)
			return {}, fmt.aprintf("line %d body %d: invalid required field", line_number, body_index), false
		}
		for existing in frame.bodies {
			if existing.id == id { destroy_frame(&frame); return {}, fmt.aprintf("line %d: duplicate body id %s", line_number, id), false }
		}
		append(&frame.bodies, Body_Frame{id = strings.clone(id), mass = mass, position = position, velocity = velocity, acceleration = acceleration})
	}
	return frame, "", true
}

load :: proc(path: string) -> (Replay, string, bool) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil { return {}, fmt.aprintf("failed to read %s", path), false }
	defer delete(data)
	lines := strings.split(string(data), "\n")
	defer delete(lines)
	result: Replay
	previous_step := -1
	previous_time := -1.0
	for raw_line, index in lines {
		line := strings.trim_space(raw_line)
		if line == "" { continue }
		frame, message, ok := parse_frame(transmute([]byte)line, index + 1)
		if !ok { destroy(&result); return {}, message, false }
		if frame.step < previous_step || frame.time < previous_time {
			destroy_frame(&frame); destroy(&result)
			return {}, fmt.aprintf("line %d: step and time must be nondecreasing", index + 1), false
		}
		previous_step, previous_time = frame.step, frame.time
		append(&result.frames, frame)
	}
	if len(result.frames) == 0 { destroy(&result); return {}, strings.clone("file has no frames"), false }
	return result, "", true
}

set_index :: proc(value: ^Replay, index: int) {
	if len(value.frames) == 0 { value.index = 0; return }
	value.index = clamp(index, 0, len(value.frames) - 1)
}

replay_count :: proc(ctx: rawptr) -> int { return len((^Replay)(ctx).frames) }
replay_frame_at :: proc(ctx: rawptr, index: int) -> (^Simulation_Frame, bool) {
	value := (^Replay)(ctx)
	if index < 0 || index >= len(value.frames) { return nil, false }
	return &value.frames[index], true
}
source :: proc(value: ^Replay) -> Frame_Source {
	return Frame_Source{ctx = rawptr(value), frame_count_proc = replay_count, frame_at_proc = replay_frame_at, finite = true, seekable = true}
}

frame_count :: proc(source: Frame_Source) -> int { return source.frame_count_proc(source.ctx) }
frame_at :: proc(source: Frame_Source, index: int) -> (^Simulation_Frame, bool) { return source.frame_at_proc(source.ctx, index) }
