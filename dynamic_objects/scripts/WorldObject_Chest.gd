extends Spatial

# this is a hacky way to save and load objects for now...
# there is for sure a better way to identify and restore the type
# but for now it has to do...
var _world_object_type = "WorldObject_Chest";

func get_save_dictionary() -> Dictionary:
	var ret = {
		world_object_type = _world_object_type,
		transform = vdb._transform_to_arr(global_transform),
	}
	return ret;

func apply_save_dictionary(r : Dictionary):
	if (r.type != _world_object_type):
		vr.log_error("Unexpected object type: got " + r.type + " but expected " + _world_object_type);
	
	global_transform = vdb._arr_to_transform(r.transform);

func _ready():
	pass # Replace with function body.
