package sim_export

import "core:encoding/json"
import "core:os"
import simcore "../core"
import "../diagnostics"

Frame :: struct {
	step: int,
	time: f64,
	bodies: []simcore.Body,
}

Writer :: struct {
	file: ^os.File,
}

Diagnostics_Frame :: struct {
	schema_version:   int,
	record_type:      string,
	step:             int,
	time:             f64,
	kinetic_energy:   f64,
	potential_energy: f64,
	total_energy:     f64,
	momentum:         simcore.Vec2,
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

write_diagnostics :: proc(writer: ^Writer, state: simcore.SimulationState, config: simcore.SimulationConfig) -> bool {
	if writer.file == nil { return false }
	value := diagnostics.snapshot(state.bodies, config)
	record := Diagnostics_Frame {
		schema_version = 1,
		record_type = "simulation_diagnostics",
		step = state.step,
		time = state.time,
		kinetic_energy = value.kinetic_energy,
		potential_energy = value.potential_energy,
		total_energy = value.total_energy,
		momentum = value.momentum,
	}
	data, err := json.marshal(record, json.Marshal_Options{spec = .JSON})
	if err != nil { return false }
	defer delete(data)
	if _, write_err := os.write(writer.file, data); write_err != nil { return false }
	_, newline_err := os.write_string(writer.file, "\n")
	return newline_err == nil
}
