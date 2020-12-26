extends Spatial

func _run_as_dedicated_server():
	print("\n\nRunning Voxel Works as Dedicated Server");
	print("  Server IP: " + str(IP.get_local_addresses()));
	print("\n\n");
	
	vr.switch_scene("res://levels/MainWorld.tscn");
	

func _ready():
	vr.initialize();
	vdb.initialize();
	vdb.load_global_statistics();
	vdb.load_gameplay_settings();
	
	vr.set_foveation_level(0);
	
	vr.scene_switch_root = self;
	
	vdb.reset_startup_settings();
	for a in OS.get_cmdline_args():
		if (a == "--server"):
			vdb.startup_settings.dedicated_server = true;
			vdb.startup_settings.host = true;
	
	if (vdb.startup_settings.dedicated_server):
		_run_as_dedicated_server();
		return;

	# Always advertise Godot a bit in the beggining
	if (vr.inVR): vr.switch_scene("res://levels/GodotSplash.tscn", 0.0, 0.0);
	vr.switch_scene("res://levels/MainMenuRoom.tscn", 0.1, 5.0);
