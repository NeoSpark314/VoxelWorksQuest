extends Spatial

onready var terrain = $VoxelTerrain;

var save_enabled = true;

func _ready():
	terrain.voxel_library = vdb.voxel_library;

	vdb.voxel_world_player.set_player_parent_world(self);

	# the main world is where we start and everything gets initialized
	#vdb.startup_settings.load_game = false;
	vdb.persistence_load_and_start_game();

	#only after loading the stream is currently valid
	terrain.stream = vdb.main_world_generator;
	
	vdb.voxel_world_player.move_player_into_terrain_after_load(terrain);


