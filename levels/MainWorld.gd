extends Spatial

onready var terrain = $VoxelTerrain;

var save_enabled = false;

# we need to have this function here because many grabbable objects are actually
# a child of MainWorld now not from the player; but we just delegate the call
# here to the player for now
func oq_can_static_grab(grabbed_body, grab_area : Area, grab_controller : ARVRController, overlapping_bodies : Array):
	return vdb.voxel_world_player.oq_can_static_grab(grabbed_body, grab_area, grab_controller, overlapping_bodies)

func _ready():
	terrain.voxel_library = vdb.voxel_library;

	vdb.voxel_world_player.set_player_parent_world(self);
	
	if vdb.startup_settings.remote_host:
		save_enabled = false;
		# detach terrain as it has no generator and will crash
		terrain.get_parent().remove_child(terrain);

		vdb.voxel_world_player.connect_to_server(vdb.startup_settings.remote_host);
	else:
		save_enabled = true;
		
		add_child(vdb.voxel_world_player);
		
		# the main world is where we start and everything gets initialized
		#vdb.startup_settings.load_game = false;
		vdb.persistence_load_and_start_game();

		#only after loading the stream is currently valid
		terrain.stream = vdb.main_world_generator;
		
		vdb.voxel_world_player.move_player_into_terrain_after_load(terrain);
		
		if vdb.startup_settings.host:
			core.start_server();

	
	#$model/AnimationPlayer.get_animation("test animation").set_loop(true)
	#$model/AnimationPlayer.play("test animation")
	
#	var bunny = load("res://actors/Bunny.tscn").instance();
#	add_child(bunny);
#	bunny.global_transform.origin= Vector3(9, 3, 0);
#
#	var testhuman = load("res://actors/TestHuman.tscn").instance();
#	add_child(testhuman);
#	testhuman.global_transform.origin= Vector3(15, 1, 5);

func _process(delta):
	if vdb.voxel_world_player.socket_client:
		vdb.voxel_world_player.socket_client.update();
	elif core.server:
		core.server.update();
