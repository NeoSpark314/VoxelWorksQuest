extends "Object_Item.gd"

func _has_predefined_geometry():
	return true;
	
# this function is needed if _has_predefined_geometry() is true
# in vdb._create_item_mesh_from_def(...) !!
func _get_item_mesh():
	return $mesh

func _ready():
	pass;


