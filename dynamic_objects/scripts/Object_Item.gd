extends Spatial

var uuid = vdb.gen_uuid();
var _item_def = null;

func _has_predefined_geometry():
	return false;

func get_def():
	return _item_def;


func get_def_name():
	return _item_def.name;

func get_item_def():
	return _item_def;
	
func get_save_dictionary() -> Dictionary:
	var ret = {
		def_name = get_def_name(),
		transform = vdb._transform_to_arr(global_transform),
	}
	return ret;
	
func apply_save_dictionary(r : Dictionary):
	global_transform = vdb._arr_to_transform(r.transform);


func get_voxel_def():
	return null;

func can_grab(controller):
	return true;

func request_grab(hand_name):
	vdb.voxel_world_player.request_grab(hand_name, uuid);

func get_grab_object(controller):
	return self;

func get_geometry_node():
	return $Geometry;

func get_hit_point_collection_node():
	return $Geometry/HitPointCollection;


