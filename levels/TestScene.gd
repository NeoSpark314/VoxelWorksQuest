extends Spatial

var _terrain_tool = null
onready var terrain = $VoxelTerrain; #VoxelTerrain.new();

func test_terrain():
	vdb.main_world_generator.initialize();
	terrain.voxel_library = vdb.create_voxel_library();
	terrain.stream = vdb.main_world_generator;
	_terrain_tool = terrain.get_voxel_tool();


func _ready():
	vdb.initialize();
	
	test_terrain();
	
	var pos = [
		4, Vector3(0,0,0),
		1, Vector3(0,1,0),
		
		1, Vector3(1,0,0),
		1, Vector3(1,0,1),
		1, Vector3(0,0,1),
	]
	
	for i in range(0, pos.size(), 2):
		var v = vdb.create_voxelblock_object_from_def(vdb.voxel_block_defs[pos[i]]);
		$Icon.add_child(v);
		v.transform.origin = pos[i+1]*0.125;
