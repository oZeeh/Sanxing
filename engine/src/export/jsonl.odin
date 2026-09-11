package sim_export

import "core:encoding/json"
import "core:os"
import simcore "../core"

Frame :: struct {
	step: int,
	time: f64,
	bodies: []simcore.Body,
}

Writer :: struct {
	file: ^os.File,
}

writer_open :: proc(path: string) -> (Writer, bool) {
	file, err := os.create(path)
	if err != nil {
		return Writer{}, false
	}
	return Writer{file = file}, true
}

writer_close :: proc(writer: ^Writer) {
	if writer.file != nil {
		os.close(writer.file)
		writer.file = nil
	}
}

write_frame :: proc(writer: ^Writer, state: simcore.SimulationState) -> bool {
	if writer.file == nil {
		return false
	}

	frame := Frame{
		step = state.step,
		time = state.time,
		bodies = state.bodies,
	}

	data, err := json.marshal(frame, json.Marshal_Options{spec = .JSON})
	if err != nil {
		return false
	}
	defer delete(data)

	_, write_err := os.write(writer.file, data)
	if write_err != nil {
		return false
	}

	_, newline_err := os.write_string(writer.file, "\n")
	return newline_err == nil
}
