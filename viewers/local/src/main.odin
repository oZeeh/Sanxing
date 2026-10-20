package main

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "replay"
import rl "vendor:raylib"

TOOLBAR_HEIGHT :: 76.0
STATUS_HEIGHT :: 28.0
INSPECTOR_WIDTH :: 310.0
PATH_CAPACITY :: 512

App_State :: struct {
	replay_data: replay.Replay,
	has_replay: bool,
	playing: bool,
	accumulator: f32,
	playback_speed: f32,
	trail_length: i32,
	show_labels: bool,
	selected_id: string,
	camera: rl.Camera2D,
	camera_ready: bool,
	path_buffer: [PATH_CAPACITY]u8,
	path_editing: bool,
	status: string,
}

set_status :: proc(app: ^App_State, message: string) {
	delete(app.status)
	app.status = strings.clone(message)
}

set_path_buffer :: proc(app: ^App_State, path: string) {
	app.path_buffer = {}
	count := min(len(path), PATH_CAPACITY - 1)
	copy(app.path_buffer[:count], transmute([]u8)path[:count])
}

path_text :: proc(app: ^App_State) -> string { return string(cstring(&app.path_buffer[0])) }

world_viewport :: proc() -> rl.Rectangle {
	return rl.Rectangle{x = 0, y = TOOLBAR_HEIGHT, width = f32(rl.GetScreenWidth()) - INSPECTOR_WIDTH, height = f32(rl.GetScreenHeight()) - TOOLBAR_HEIGHT - STATUS_HEIGHT}
}

fit_camera :: proc(app: ^App_State) {
	if !app.has_replay || len(app.replay_data.frames) == 0 { return }
	minimum_x, maximum_x := 0.0, 0.0
	minimum_y, maximum_y := 0.0, 0.0
	have_body := false
	for frame in app.replay_data.frames {
		for body in frame.bodies {
			if !have_body {
				minimum_x, maximum_x = body.position.x, body.position.x
				minimum_y, maximum_y = body.position.y, body.position.y
				have_body = true
			} else {
				minimum_x = min(minimum_x, body.position.x); maximum_x = max(maximum_x, body.position.x)
				minimum_y = min(minimum_y, body.position.y); maximum_y = max(maximum_y, body.position.y)
			}
		}
	}
	if !have_body { minimum_x, maximum_x, minimum_y, maximum_y = -1, 1, -1, 1 }
	span_x := max(maximum_x - minimum_x, 1e-6)
	span_y := max(maximum_y - minimum_y, 1e-6)
	view := world_viewport()
	app.camera.target = rl.Vector2{f32((minimum_x + maximum_x) * 0.5), f32((minimum_y + maximum_y) * 0.5)}
	app.camera.offset = rl.Vector2{view.x + view.width * 0.5, view.y + view.height * 0.5}
	app.camera.zoom = clamp(min(view.width / f32(span_x), view.height / f32(span_y)) * 0.85, 0.0001, 100000.0)
	app.camera.rotation = 0
	app.camera_ready = true
}

load_path :: proc(app: ^App_State, path: string) {
	loaded, message, ok := replay.load(path)
	defer delete(message)
	if !ok { set_status(app, message); return }
	if app.has_replay { replay.destroy(&app.replay_data) }
	app.replay_data = loaded
	app.has_replay = true
	app.playing = false
	app.accumulator = 0
	app.selected_id = ""
	set_path_buffer(app, path)
	fit_camera(app)
	set_status(app, fmt.tprintf("Loaded %s (%d frames)", path, len(loaded.frames)))
}

body_color :: proc(index: int) -> rl.Color {
	colors := [?]rl.Color{
		{66, 198, 164, 255}, {242, 184, 75, 255}, {125, 183, 255, 255},
		{239, 111, 108, 255}, {185, 216, 122, 255}, {211, 156, 255, 255},
	}
	return colors[index % len(colors)]
}

find_body :: proc(frame: ^replay.Simulation_Frame, id: string) -> (^replay.Body_Frame, int, bool) {
	for &body, index in frame.bodies {
		if body.id == id { return &body, index, true }
	}
	return nil, -1, false
}

current_frame :: proc(app: ^App_State) -> (^replay.Simulation_Frame, bool) {
	if !app.has_replay { return nil, false }
	source := replay.source(&app.replay_data)
	return replay.frame_at(source, app.replay_data.index)
}

update_playback :: proc(app: ^App_State) {
	if !app.playing || !app.has_replay { return }
	app.accumulator += rl.GetFrameTime() * app.playback_speed
	frame_interval: f32 = 0.12
	for app.accumulator >= frame_interval {
		app.accumulator -= frame_interval
		if app.replay_data.index + 1 >= len(app.replay_data.frames) {
			app.playing = false
			break
		}
		replay.set_index(&app.replay_data, app.replay_data.index + 1)
	}
}

update_camera :: proc(app: ^App_State) {
	if !app.camera_ready { return }
	view := world_viewport()
	app.camera.offset = rl.Vector2{view.x + view.width * 0.5, view.y + view.height * 0.5}
	mouse := rl.GetMousePosition()
	inside := rl.CheckCollisionPointRec(mouse, view)
	if inside && rl.IsMouseButtonDown(.MIDDLE) {
		delta := rl.GetMouseDelta()
		app.camera.target[0] -= delta[0] / app.camera.zoom
		app.camera.target[1] -= delta[1] / app.camera.zoom
	}
	wheel := rl.GetMouseWheelMove()
	if inside && wheel != 0 {
		before := rl.GetScreenToWorld2D(mouse, app.camera)
		app.camera.zoom = clamp(app.camera.zoom * (1 + wheel * 0.12), 0.0001, 100000.0)
		after := rl.GetScreenToWorld2D(mouse, app.camera)
		app.camera.target[0] += before[0] - after[0]
		app.camera.target[1] += before[1] - after[1]
	}
}

handle_selection :: proc(app: ^App_State) {
	if !rl.IsMouseButtonPressed(.LEFT) { return }
	view := world_viewport()
	mouse := rl.GetMousePosition()
	if !rl.CheckCollisionPointRec(mouse, view) { return }
	frame, ok := current_frame(app)
	if !ok { return }
	app.selected_id = ""
	for body, index in frame.bodies {
		screen := rl.GetWorldToScreen2D(rl.Vector2{f32(body.position.x), f32(body.position.y)}, app.camera)
		if rl.CheckCollisionPointCircle(mouse, screen, 9) {
			app.selected_id = frame.bodies[index].id
			break
		}
	}
}

draw_world :: proc(app: ^App_State) {
	view := world_viewport()
	rl.DrawRectangleRec(view, rl.Color{20, 23, 25, 255})
	if !app.has_replay || !app.camera_ready { return }
	frame, ok := current_frame(app)
	if !ok { return }
	rl.BeginScissorMode(i32(view.x), i32(view.y), i32(view.width), i32(view.height))
	rl.BeginMode2D(app.camera)
	rl.DrawLineV(rl.Vector2{-1e6, 0}, rl.Vector2{1e6, 0}, rl.Color{42, 48, 52, 255})
	rl.DrawLineV(rl.Vector2{0, -1e6}, rl.Vector2{0, 1e6}, rl.Color{42, 48, 52, 255})
	trail_start := max(0, app.replay_data.index - int(app.trail_length))
	if app.trail_length > 0 {
		for body, body_index in frame.bodies {
			previous: rl.Vector2
			have_previous := false
			for frame_index in trail_start ..= app.replay_data.index {
				trail_body, _, found := find_body(&app.replay_data.frames[frame_index], body.id)
				if !found { have_previous = false; continue }
				point := rl.Vector2{f32(trail_body.position.x), f32(trail_body.position.y)}
				if have_previous { rl.DrawLineV(previous, point, rl.ColorAlpha(body_color(body_index), 0.45)) }
				previous, have_previous = point, true
			}
		}
	}
	for body, index in frame.bodies {
		point := rl.Vector2{f32(body.position.x), f32(body.position.y)}
		radius := f32(clamp(4.0 + math.sqrt(max(body.mass, 0.0)), 5.0, 12.0)) / app.camera.zoom
		selected := body.id == app.selected_id
		if selected { rl.DrawCircleV(point, radius * 1.7, rl.RAYWHITE) }
		rl.DrawCircleV(point, radius, body_color(index))
		if app.show_labels {
			label := strings.clone_to_cstring(body.id, context.temp_allocator)
			rl.DrawText(label, i32(point[0] + radius * 1.4), i32(point[1] - radius), i32(max(1, int(14 / app.camera.zoom))), rl.RAYWHITE)
		}
	}
	rl.EndMode2D()
	rl.EndScissorMode()
}

draw_inspector :: proc(app: ^App_State) {
	x := f32(rl.GetScreenWidth()) - INSPECTOR_WIDTH
	rect := rl.Rectangle{x = x, y = TOOLBAR_HEIGHT, width = INSPECTOR_WIDTH, height = f32(rl.GetScreenHeight()) - TOOLBAR_HEIGHT - STATUS_HEIGHT}
	rl.DrawRectangleRec(rect, rl.Color{27, 32, 36, 255})
	rl.DrawText("Body inspection", i32(x + 16), i32(TOOLBAR_HEIGHT + 16), 20, rl.RAYWHITE)
	frame, ok := current_frame(app)
	if !ok || app.selected_id == "" {
		rl.DrawText("Select a body in the viewport.", i32(x + 16), i32(TOOLBAR_HEIGHT + 52), 14, rl.GRAY)
		return
	}
	body, _, found := find_body(frame, app.selected_id)
	if !found { app.selected_id = ""; return }
	lines := [?]cstring{
		fmt.ctprintf("id: %s", body.id), fmt.ctprintf("mass: %.8g", body.mass),
		fmt.ctprintf("position: (%.8g, %.8g)", body.position.x, body.position.y),
		fmt.ctprintf("velocity: (%.8g, %.8g)", body.velocity.x, body.velocity.y),
		fmt.ctprintf("acceleration: (%.8g, %.8g)", body.acceleration.x, body.acceleration.y),
	}
	for line, index in lines { rl.DrawText(line, i32(x + 16), i32(TOOLBAR_HEIGHT + 54 + f32(index * 25)), 14, rl.LIGHTGRAY) }
}

draw_controls :: proc(app: ^App_State) {
	width := f32(rl.GetScreenWidth())
	rl.DrawRectangle(0, 0, i32(width), i32(TOOLBAR_HEIGHT), rl.Color{27, 32, 36, 255})
	path_rect := rl.Rectangle{x = 12, y = 10, width = min(330, width * 0.30), height = 28}
	if rl.GuiTextBox(path_rect, cstring(&app.path_buffer[0]), PATH_CAPACITY, app.path_editing) { app.path_editing = !app.path_editing }
	x := path_rect.x + path_rect.width + 8
	if rl.GuiButton(rl.Rectangle{x = x, y = 10, width = 58, height = 28}, "Load") { load_path(app, path_text(app)) }
	x += 66
	if rl.GuiButton(rl.Rectangle{x = x, y = 10, width = 48, height = 28}, "Prev") && app.has_replay { app.playing = false; replay.set_index(&app.replay_data, app.replay_data.index - 1) }
	x += 56
	play_label: cstring = "Play"
	if app.playing { play_label = "Pause" }
	if rl.GuiButton(rl.Rectangle{x = x, y = 10, width = 58, height = 28}, play_label) && app.has_replay { app.playing = !app.playing }
	x += 66
	if rl.GuiButton(rl.Rectangle{x = x, y = 10, width = 48, height = 28}, "Next") && app.has_replay { app.playing = false; replay.set_index(&app.replay_data, app.replay_data.index + 1) }
	x += 56
	if rl.GuiButton(rl.Rectangle{x = x, y = 10, width = 58, height = 28}, "Fit") { fit_camera(app) }

	timeline: f32 = 0
	maximum: f32 = 1
	if app.has_replay { timeline = f32(app.replay_data.index); maximum = f32(max(1, len(app.replay_data.frames) - 1)) }
	rl.GuiSliderBar(rl.Rectangle{x = 12, y = 48, width = max(180, width - 650), height = 18}, "", fmt.ctprintf("%d/%d", app.replay_data.index + 1 if app.has_replay else 0, len(app.replay_data.frames)), &timeline, 0, maximum)
	if app.has_replay && int(timeline + 0.5) != app.replay_data.index { app.playing = false; replay.set_index(&app.replay_data, int(timeline + 0.5)) }
	control_x := max(210, width - 620)
	rl.GuiSlider(rl.Rectangle{x = control_x, y = 48, width = 120, height = 18}, "speed", fmt.ctprintf("%.2gx", app.playback_speed), &app.playback_speed, 0.25, 4)
	control_x += 170
	rl.GuiCheckBox(rl.Rectangle{x = control_x, y = 48, width = 18, height = 18}, "labels", &app.show_labels)
	control_x += 100
	rl.GuiSpinner(rl.Rectangle{x = control_x, y = 45, width = 120, height = 24}, "trails", &app.trail_length, 0, 500, false)
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(1280, 800, "Sanxing Native Replay")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)
	app := App_State{playback_speed = 1, trail_length = 100, show_labels = true, status = strings.clone("Load an engine JSONL export.")}
	defer {
		if app.has_replay { replay.destroy(&app.replay_data) }
		delete(app.status)
	}
	if len(os.args) >= 2 { load_path(&app, os.args[1]) }
	for !rl.WindowShouldClose() {
		if rl.IsFileDropped() {
			files := rl.LoadDroppedFiles()
			if files.count > 0 { load_path(&app, string(files.paths[0])) }
			rl.UnloadDroppedFiles(files)
		}
		if rl.IsKeyPressed(.SPACE) && app.has_replay { app.playing = !app.playing }
		if rl.IsKeyPressed(.LEFT) && app.has_replay { app.playing = false; replay.set_index(&app.replay_data, app.replay_data.index - 1) }
		if rl.IsKeyPressed(.RIGHT) && app.has_replay { app.playing = false; replay.set_index(&app.replay_data, app.replay_data.index + 1) }
		update_playback(&app)
		update_camera(&app)
		handle_selection(&app)
		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{17, 19, 21, 255})
		draw_world(&app)
		draw_inspector(&app)
		draw_controls(&app)
		frame, has_frame := current_frame(&app)
		status_text := app.status
		if has_frame { status_text = fmt.tprintf("%s | step %d | time %.6g | %d bodies", app.status, frame.step, frame.time, len(frame.bodies)) }
		rl.GuiStatusBar(rl.Rectangle{x = 0, y = f32(rl.GetScreenHeight()) - STATUS_HEIGHT, width = f32(rl.GetScreenWidth()), height = STATUS_HEIGHT}, strings.clone_to_cstring(status_text, context.temp_allocator))
		rl.EndDrawing()
	}
}
