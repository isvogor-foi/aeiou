extends SceneTree
## FPS benchmark: N v N battle in the 3D view (N env var, default 200). Prints GPU,
## render and per-section frame costs.
##   N=75 tools/godot --path . -s tests/bench_fps.gd
const GameConfig = preload("res://sim/game_config.gd")
func _initialize():
	_run.call_deferred()
func _run():
	GameConfig.map_seed = 5
	GameConfig.map_size = "large"
	var gv = load("res://view3d/game3d.tscn").instantiate()
	gv.edge_scroll = false
	gv.input_enabled = false
	root.add_child(gv)
	for i in 20: await process_frame
	var w = gv.world
	w.ais.clear()
	var c0 = Vector2(54, 64) * 32
	var c1 = Vector2(74, 64) * 32
	var a = []; var b = []
	var per_side = int(OS.get_environment("N")) if OS.has_environment("N") else 200
	for i in per_side:
		var off = Vector2((i % 15) * 20, (i / 15) * 20)
		a.append(w.spawn_unit(["grenadier","musketeer","kuerassier","jaeger"][i % 4], 0, w.map.tile_center(w.map.nearest_walkable(w.map.to_tile(c0 + off)))).id)
		b.append(w.spawn_unit(["reaver","hexcaster","thrall","bonebow"][i % 4], 1, w.map.tile_center(w.map.nearest_walkable(w.map.to_tile(c1 + off)))).id)
	w.issue({"type":"attack_move","player":0,"ids":a,"pos":c1})
	w.issue({"type":"attack_move","player":1,"ids":b,"pos":c0})
	gv.reveal_all = true
	gv.camera.focus = gv.terrain.to3(Vector2(64, 66) * 32)
	gv.camera.distance = 40.0
	gv.camera.update_transform()
	for i in 60: await process_frame
	gv.frame_profiling = true
	if OS.has_environment("NO_TREES"):
		for mmi in gv.terrain.find_children("*", "MultiMeshInstance3D", true, false):
			mmi.visible = false
	preload("res://sim/prof.gd").enabled = true
	preload("res://sim/prof.gd").data = {}
	print("quality ", preload("res://ui/graphics.gd").effective())
	var vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	if OS.has_environment("NO_ANIM"):
		for ap in gv.entity_views.find_children("*", "AnimationPlayer", true, false):
			ap.active = false
	if OS.has_environment("NO_OVERLAY"):
		gv.overlay.visible = false
		gv.overlay.set_process(false)
	var t0 = Time.get_ticks_usec()
	var frames = 0
	var worst = 0
	var last = t0
	while Time.get_ticks_usec() - t0 < 8000000:
		await process_frame
		var now = Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		frames += 1
	print("process %.1fms  draw calls %d  objects %d  primitives %d  video MB %d" % [
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6])
	print("gpu %.1fms  cpu-render %.1fms" % [RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)])
	var parts = []
	for k in gv.frame_prof:
		parts.append("%s %.1fms" % [k, gv.frame_prof[k] / 1000.0 / frames])
	print("per frame: ", ", ".join(parts))
	var pd = preload("res://sim/prof.gd").data
	var vp = []
	for k in pd:
		if k.begins_with("v_"): vp.append("%s %.1fms" % [k, pd[k] / 1000.0 / frames])
	print("views: ", ", ".join(vp))
	print("fps %.1f  worst frame %.1fms  units alive %d" % [frames / ((Time.get_ticks_usec() - t0) / 1e6), worst / 1000.0, w.entities.values().filter(func(e): return e.kind == 0).size()])
	quit()
