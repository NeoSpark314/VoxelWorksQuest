# DungeonInstance.gd
extends Spatial

onready var terrain = $VoxelTerrain;
var dungeon_generator = null;

var save_enabled = false;

func _ready():
	terrain.voxel_library = vdb.voxel_library;

	vdb.voxel_world_player.set_player_parent_world(self);

	# the main world is where we start and everything gets initialized
	#vdb.startup_settings.load_game = false;
	#vdb.persistence_load_and_start_game();

	#only after loading the stream is currently valid
	
	dungeon_generator = load("res://scripts/DungeonInstanceGenerator_V1.gd").new();
	dungeon_generator.initialize(0);
	terrain.stream = dungeon_generator;
	
	vdb.voxel_world_player.move_player_into_terrain_after_load(terrain);

	vdb._set_player_position(dungeon_generator.start_position);


func _process(_dt):
	#vr.show_dbg_info("camera", str(vr.vrCamera.global_transform.basis.z));
	
	var mb = dungeon_generator.block2_fromVec3(vr.vrCamera.global_transform.origin, dungeon_generator.template_size);
	
	var maze_str = dungeon_generator.get_maze_map_as_string(dungeon_generator._maze, dungeon_generator.maze_res, dungeon_generator.maze_res, mb);
	
	
	var info = "View dir = " + str(-vr.vrCamera.global_transform.basis.z) + "\n";
	info += "WS Pos  = " + str(vr.vrCamera.global_transform.origin) + "\n";
	info += str(mb) + "                                                \n"
	info += maze_str;
	
	vr.show_dbg_info("maze", info);
	
	
