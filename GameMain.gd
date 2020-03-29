extends Spatial

func _ready():
	vr.initialize();
	vdb.initialize();
	vdb.load_global_statistics();
	vdb.load_gameplay_settings();
	
	vr.set_foveation_level(0);
	
	vr.scene_switch_root = self;

	if (!vr.inVR): # for quick testing on desktop
		#vr.switch_scene("res://levels/MainWorld.tscn"); return;
		#vr.switch_scene("res://levels/DungeonInstance.tscn"); return;
		pass;

	# Always advertise Godot a bit in the beggining
	if (vr.inVR): vr.switch_scene("res://levels/GodotSplash.tscn", 0.0, 0.0);
	vr.switch_scene("res://levels/MainMenuRoom.tscn", 0.1, 5.0);

