extends Spatial

var slots = {}

func get_save_dictionary() -> Dictionary:
	var ret = {
		slot_items = []
	}
	
	# all nodes attached to the root are checked for objects and then saved
	for slot in $Slots.get_children():
		var obj = slot.get_slot_object();
		
		if (obj == null):
			ret.slot_items.append(null);
		else:
			ret.slot_items.append(obj.get_save_dictionary());

	return ret;
	
func apply_save_dictionary(r : Dictionary):
	print(r);
	
	var count = -1;
	for item in r.slot_items:
		count = count + 1;
		if (item == null): continue;
		
		var def = vdb.get_def_from_name(item.def_name);
		
		if (def == null):
			vr.log_error("Could not load def " + item.def_name);
			continue;
		
		if (not vdb.is_item_definition(def)): continue;
		
		var obj = vdb.create_object_from_def(def);
		
		if (obj):
			obj.apply_save_dictionary(item);
			
			var slot = $Slots.get_child(count);
			if (slot == null):
				vr.log_error("Non-existing item slot for tool in toolbelt");
			else:
				slot.put_item(obj);
			
		else:
			vr.log_error("Could not load object from " + str(item));

func clear():
	for slot in $Slots.get_children():
		for child in slot.slot.get_children():
			child.queue_free();


func _physics_process(_dt):
	global_transform.origin = vr.vrCamera.global_transform.origin;
	global_transform.origin.y -= vr.get_current_player_height() * 0.5;

func _ready():
	for slot in $Slots.get_children():
		slots[slot.name] = slot;
