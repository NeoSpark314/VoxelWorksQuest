extends Control


onready var block_item_list := $"Block Selection/ItemList";

func get_selected_voxel_id():
	var s = block_item_list.get_selected_items();
	if (s && s.size() > 0): return s[0];
	return 0;

func _ready():
	
	var block_texture = vdb.voxel_material.albedo_texture;
	
	var tex_size = 16; #TODO: should be computed from the texture resolution
	
	for block_def in vdb.voxel_block_defs:
		
		if (block_def.geometry_type == vdb.GEOMETRY_TYPE.None):
			block_item_list.add_icon_item(null);
			continue;
		
		var at = AtlasTexture.new();
		at.atlas = block_texture;
		
		var x = block_def.cube_tiles_x;
		var y = block_def.cube_tiles_y;
		if ((x is Array)): x = x[0];
		if ((y is Array)): y = y[0];

		at.region = Rect2(x*tex_size, y*tex_size, tex_size, tex_size);
		block_item_list.add_icon_item(at);
		
	# this is a hack around some resize problem that happened only on the quest
	set_size(Vector2(1024, 512))
	$"Block Selection".set_size(Vector2(1016, 457))
	$"Block Selection/ItemList".set_size(Vector2(992, 432))
	# end hack
