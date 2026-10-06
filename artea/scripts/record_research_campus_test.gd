extends "res://scripts/capture_heavenly_quest_video.gd"
## Verification-only recording: isolated save, public inputs, player-height cuts.
const SAVE := "user://record_research_campus_test.json"
const DIR := "res://artifacts/research_campus_quest_video"
var frames_dir := ""
var recording := false
var frame_count := 0
var panel: CanvasLayer
var video_pipe: FileAccess
var encoder: Dictionary

func _record() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): frames_dir=arg.trim_prefix("--frames=")
		if arg.begins_with("--encode="):
			encoder=OS.execute_with_pipe("/opt/homebrew/bin/ffmpeg",PackedStringArray([
				"-hide_banner","-loglevel","error","-f","rawvideo","-pixel_format","rgb24",
				"-video_size","960x540","-framerate","12","-i","pipe:0",
				"-c:v","libx264","-preset","veryfast","-crf","24","-pix_fmt","yuv420p",
				"-movflags","+faststart","-y",arg.trim_prefix("--encode=")]),true)
			video_pipe=encoder.get("stdio")
	assert(video_pipe!=null or not frames_dir.is_empty())
	if FileAccess.file_exists(SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.make_dir_recursive_absolute(DIR)
	root.size=Vector2i(1280,720)
	root.msaa_3d=Viewport.MSAA_2X
	_world=WorldScene.instantiate()
	_world.build_hud=false
	_world.object_state_store_path=SAVE
	_world.get_node("QuestController").enabled=false
	root.add_child(_world)
	_add_lighting()
	_add_caption()
	_caption.get_parent().layer=90
	_player_proxy=Node3D.new()
	_world.add_child(_player_proxy)
	_camera=Camera3D.new()
	_camera.fov=58
	_camera.far=8000
	_world.add_child(_camera)
	_camera.make_current()
	for frame in 12: await process_frame
	_puzzle=_world.get_island_one_puzzle()
	_at("colour_prism")
	RenderingServer.frame_post_draw.connect(_save_video_frame)
	recording=true
	_caption.text="ISLAND ONE • LOCAL AUTOMATED QUEST TEST\nPlayer-height views • cuts between stations • isolated test save"
	await create_timer(2).timeout
	assert(not _puzzle.interact_control("echo_beacon").accepted)
	for operation in [["colour_prism",1],["rhythm_prism",2],["weight_prism",3],["analysis_console",1],["west_regulator",1],["east_regulator",2],["outer_ring",3],["middle_ring",2],["inner_ring",1]]:
		_at(operation[0])
		_caption.text="QUEST 1 • SIGNAL LABORATORY\n"+operation[0].replace("_"," ").capitalize()+" — observe the instrument's response"
		await create_timer(.7).timeout
		for press in operation[1]:
			assert(_puzzle.interact_nearest(_player_proxy).accepted)
			await create_timer(.4).timeout
		if operation[0]=="analysis_console": _shot("01_signal_laboratory")
		await create_timer(.5).timeout
	_at("confirm")
	assert(_puzzle.interact_nearest(_player_proxy).accepted)
	assert(_puzzle.is_signal_observatory_complete() and not _puzzle.is_powered())
	var gate := _world.get_island_one_heavenly_star_gate()
	_camera.global_position=gate.to_global(Vector3(0,7,-28))
	_camera.look_at(gate.to_global(Vector3(0,13,0)))
	_caption.text="SIGNAL PRISM EARNED • GARDEN ENTRANCE OPENS\nThis connects both halves of Island One. Island Two is still locked."
	await create_timer(3).timeout
	assert(_world.is_island_one_star_gate_open() and not _world.is_quest_gate_open(0))
	_shot("02_garden_gate_open")
	_at("echo_collector")
	_caption.text="QUEST 2 • LIVING RESEARCH GARDEN\nInstall the earned Prism to power the three receivers."
	await create_timer(1).timeout
	assert(_puzzle.interact_nearest(_player_proxy).accepted)
	_shot("03_garden_collector")
	await create_timer(1).timeout
	for index in 3:
		var id := "echo_signal_%d"%(index+1)
		_at(id)
		_caption.text="GARDEN RECEIVER %d • LISTEN, TEST AND REVISE"%(index+1)
		await create_timer(1).timeout
		_open(id)
		if index==0:
			await _press("Capture the aligned echo","Try before alignment — the receiver must reject the capture")
			assert(not _puzzle.get_puzzle_state().echo_captured[index])
			_shot("04_wrong_alignment")
		for turn in 8:
			if _puzzle.get_puzzle_state().echo_phases[index]==_puzzle.ECHO_PHASE_TARGETS[index]: break
			await _press("Turn the three-notch","Turn the gear; compare the green hand with the gold source")
		await _press("Capture the aligned echo","Aligned — capture the thought, then examine its evidence")
		assert(_puzzle.get_puzzle_state().echo_captured[index])
		await _press(_puzzle.ECHO_CATEGORIES[index],"Choose "+_puzzle.ECHO_CATEGORIES[index]+" based on what the thought actually says")
		if index==1: _shot("05_thought_classification")
		await _close()
	_at("echo_question")
	_open("echo_question")
	await _press(_puzzle.PROTECTIVE_QUESTIONS[2].capitalize(),"Choose a useful preparation question instead of predicting failure")
	await _close()
	_at("echo_beacon")
	_caption.text="CAUTION BEACON • TEST THE COMPLETE INTERPRETATION\nThree classifications + one helpful question"
	await create_timer(1).timeout
	assert(_puzzle.interact_nearest(_player_proxy).reason=="completed")
	assert(_puzzle.is_echo_garden_complete() and _puzzle.get_puzzle_state().echo_seed_claimed)
	_caption.text="BOTH LOCAL PUZZLES PASSED • ECHO SEED EARNED\nThe remaining campaign checkpoint and relay still govern the Island Two exit."
	await create_timer(3).timeout
	_shot("06_echo_seed_complete")
	recording=false
	if video_pipe!=null: video_pipe.close()
	var report := FileAccess.open(DIR+"/test_record.json",FileAccess.WRITE)
	assert(report!=null)
	report.store_string(JSON.stringify({"result":"PASS","scope":"Local Compatibility renderer; public proximity inputs and UI button signals; camera cuts, not walking or browser","fps":12,"frames":frame_count,"signal_complete":_puzzle.is_signal_observatory_complete(),"echo_complete":_puzzle.is_echo_garden_complete(),"external_gate_locked":not _world.is_quest_gate_open(0),"events":_events},"\t"))
	report.close()
	_world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("RESEARCH_CAMPUS_VIDEO: PASS — Quest 1, garden gate, wrong phase rejection, tuning, classification, Echo Seed; frames=",frame_count)
	quit()

func _at(id: String) -> void:
	var control := _puzzle.get_node("PuzzleControls/PuzzleControl_"+id) as Node3D
	_camera.global_position=control.get_node("InspectionAnchor").global_position
	_camera.look_at(control.to_global(Vector3(0,2,0)))
	_player_proxy.global_position=_camera.global_position
	assert(_puzzle.nearest_control(_player_proxy)==control)

func _open(id: String) -> void:
	panel=load("res://scripts/mind_spark/quest_station_panel.gd").new()
	_world.add_child(panel)
	panel.open(_puzzle,_player_proxy,id)

func _press(prefix: String, description: String) -> void:
	_caption.text="AUTOMATED QUEST TEST\n"+description
	await create_timer(.8).timeout
	var button: Button
	for candidate in panel.find_children("*","Button",true,false):
		if candidate.text.begins_with(prefix): button=candidate; break
	assert(button!=null,"Missing button: "+prefix)
	button.pressed.emit()
	_events.append({"button":prefix,"description":description,"frame":frame_count})
	await create_timer(.7).timeout

func _close() -> void:
	panel.queue_free()
	await process_frame

func _shot(label: String) -> void:
	if root.get_texture().get_image().save_png(DIR+"/"+label+".png")!=OK:
		recording=false
		quit(1)

func _save_video_frame() -> void:
	if not recording: return
	if frame_count>=1500:
		recording=false
		push_error("Recording watchdog exceeded; test did not finish")
		quit(1)
		return
	var picture := root.get_texture().get_image()
	picture.resize(960,540)
	if video_pipe!=null:
		picture.convert(Image.FORMAT_RGB8)
		video_pipe.store_buffer(picture.get_data())
		frame_count+=1
		return
	if picture.save_jpg(frames_dir+"/frame%05d.jpg"%frame_count,.85)!=OK:
		recording=false
		quit(1)
	frame_count+=1
