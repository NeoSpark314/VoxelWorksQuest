extends Spatial

#onready var area : Area = $Area;

var _stored_def_name = ""
var _item_counter = 0

# this is just for the future to be able to have different types if needed
var _crate_type = "wooden_crate"

onready var label = $OQ_UILabel;



func get_save_dictionary() -> Dictionary:
	var ret = {
		stored_def_name = _stored_def_name,
		item_counter = _item_counter,
		crate_type = _crate_type,
		transform = vdb._transform_to_arr(global_transform),
	};

	return ret;


func apply_save_dictionary(r : Dictionary):
	if ((not "stored_def_name" in r)):
		vr.log_error("Container_Crate.load_save_dictionary has invalid format.");
		return;
		
	_stored_def_name = r.stored_def_name;
	_item_counter = r.item_counter;
	global_transform = vdb._arr_to_transform(r.transform);
		
	update_label_text();

func update_label_text():
	label.set_label_text(str(_item_counter) + " X " + _stored_def_name)

func can_put(obj):
	if (not obj is Spatial):
		vr.log_warning("can_put() object " + str(obj) + "is not Spatial");
		return false;
		
	if (!obj.visible):
		return false; # safety check to avoid readding invisible objects

	if _item_counter == 0:
		return true;

	return _stored_def_name == obj.get_def_name();

func put_item(obj):
	if _item_counter == 0:
		_stored_def_name = obj.get_def_name();
		var geom = obj.get_geometry_node()
		geom.get_parent().remove_child(geom);
		add_child(geom);
		geom.transform.origin = Vector3(0.5, 0.5, 0.5);

	obj.visible = false;
	obj.queue_free();

	_item_counter += 1;
	vdb._play_sfx(vdb.sfx_craft_success, obj.global_transform.origin);
	update_label_text();

func can_grab(controller):
	if (_item_counter > 0): return true;
	return false;

func request_grab(hand_name):
	vdb.voxel_world_player.request_from_crate(hand_name, global_transform.origin);

func get_grab_object():
	if (_item_counter == 0):
		return null;

	var def = vdb.get_def_from_name(_stored_def_name);
	if (def == null):
		vr.log_error("Invalid def in Container_Crate");
		return null;
		
	_item_counter -= 1;
	update_label_text();
	
	var obj = vdb.create_object_from_def(def);
	vdb.voxel_world_player.parent_world.add_child(obj);

	vdb._play_sfx(vdb.sfx_craft_success, global_transform.origin + Vector3.ONE / 2);

	return obj;
	
func _show_label():
	update_label_text();
	var dir = vr.vrCamera.global_transform.basis.z;

	var rot = 0;
	
	label.visible = true;
	

func _process(_dt):
	var dist = label.global_transform.origin.distance_to(vr.vrCamera.global_transform.origin);
	
	if (dist < 1.0 && !label.visible):
		_show_label();
	
	if (dist > 1.5 && label.visible):
		label.visible = false;

func _ready():
	label.visible = false;
