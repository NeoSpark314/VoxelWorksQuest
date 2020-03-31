extends Spatial

const inventory_size = 8;
var _inventory = [];

onready var _label_slot = $ActiveInventorySlot/MeshInstance/Label_Slot;

var _active_inventory_slot := 0;

func get_save_dictionary() -> Dictionary:
	var ret = {
		def_names = [],
		item_count = [],
		active_inventory_slot = _active_inventory_slot,
	};
	for i in range(0, _inventory.size()):
		var def = _inventory[i][0];
		if (def != null):
			ret.def_names.append(def.name);
			ret.item_count.append(_inventory[i][1]);
		else:
			ret.def_names.append("");
			ret.item_count.append(0);
	return ret;
	
	
func has_item_or_block_by_name(_def_name):
	for i in range(0, _inventory.size()):
		var def = _inventory[i][0];
		if (def != null):
			if (def.name == _def_name): return true;
	return false;
	

func apply_save_dictionary(r : Dictionary):
	if ((not "def_names" in r) || (not "item_count" in r)):
		vr.log_error("Inventory.load_save_dictionary has invalid format.");
		return;
	
	if (r.def_names.size() != inventory_size):
		vr.log_error("Inventory.load_save_dictionary has wrong count.");
		return;
	
	_active_inventory_slot = int(r.active_inventory_slot);
	
	for i in range(0, _inventory.size()):
		_inventory[i][0] = vdb.get_def_from_name(r.def_names[i], false);
		_inventory[i][1] = int(r.item_count[i]);
		
	update_active_item();


func can_grab():
	if (!visible): return false;
	if (_inventory[_active_inventory_slot][0] == null): return false; # nothing to grab in the inventory
	if (_inventory[_active_inventory_slot][1] <= 0): return false; # nothing to grab in the inventory
	return true;

func get_grab_object(controller):
	if (!visible): return null;
	
	# construct a new object and spawn it into the world
	if (_inventory[_active_inventory_slot][1] <= 0): return null; # nothing to grab in the inventory

	var def = _inventory[_active_inventory_slot][0];
	_inventory[_active_inventory_slot][1] -= 1;
	
	if (_inventory[_active_inventory_slot][1] == 0):
		_inventory[_active_inventory_slot][0] = null;
	update_active_item();

	var ret = null;
	if (vdb.is_voxel_def(def)):
		var voxel_object = vdb.create_voxelblock_object_from_def(def);
		# the newly spawned voxel object needs to live somewhere
		# maybe not good to always add it to the parent here but let's see
		get_parent().add_child(voxel_object);
		return voxel_object;
	if (vdb.is_item_def(def)):
		var item_object = vdb.create_item_object_from_def(def);
		get_parent().add_child(item_object);
		return item_object;
	else:
		vr.log_error("Inventory: unsupported item_def in inventory?!");
		
	
	return null;


func check_and_put_in_inventory(obj):
	if (!visible): return false; # we can only put things in the inventory when
	if (obj == null):
		vr.log_warning("check_and_put_in_inventory() with null object");
		return false;
	
	if (not obj is Spatial):
		vr.log_warning("check_and_put_in_inventory() object " + str(obj) + "is not Spatial");
		return false;
		
	if (!obj.visible): return false; # safety check to avoid readding invisible objects
	
	for o in obj.get_geometry_node().get_overlapping_areas():
		if o == $Area:
			if ("_voxel_def" in obj): # we are a voxel block
				return add_item_or_block_to_inventory(obj._voxel_def); #if we can put it in we return true;
			elif ("_item_def" in obj):
				return add_item_or_block_to_inventory(obj._item_def);
	
	return false;


func add_item_or_block_to_inventory(voxel_def):
	var empty_space = -1;
	
	var sound_position = vr.vrCamera.global_transform.origin - vr.vrCamera.global_transform.basis.z; # behind the player
	
	for pos_it in range(0, inventory_size):
		var i = (pos_it + _active_inventory_slot) % inventory_size; # start at the displayed slot
		var ii = _inventory[i][0];
		var ii_count = _inventory[i][1];
		# find the first empty space
		if (empty_space < 0 && ii == null):
			empty_space = i; # we remember the first 
		
		# check if the same voxel is already there
		if (ii != null):
			if (ii.name == voxel_def.name && ii_count < ii.stackability):
				_inventory[i][1] = _inventory[i][1] + 1;
				#vr.log_info("Increased stack size of " + voxel_def.name + " to " + str(_inventory[i][1]));
				update_active_item();
				vdb._play_sfx(vdb.sfx_put_in_inventory, sound_position);
				return true;

	if (empty_space < 0):
		vr.log_info("No empty space in inventory.");
		vdb._play_sfx(vdb.sfx_no_space_in_inventory, sound_position);
		return false; # no space in inventory
		
	_inventory[empty_space][0] = voxel_def;
	_inventory[empty_space][1] = 1; # first item in the inventory
	#vr.log_info("Putting " + voxel_def.name + " in the inventory.");
	
	update_active_item();
	vdb._play_sfx(vdb.sfx_put_in_inventory, sound_position);
	return true; # added to inventory

var selected_item = 0;

onready var _show = $ActiveInventorySlot/ShowItem;

func update_active_item():
	if (!visible): return;
		
	var item = _inventory[_active_inventory_slot][0];
	var item_name = "(Empty)";
	
	if (item != null): item_name = "%2d %s" % [_inventory[_active_inventory_slot][1], item.name];
		
	_label_slot.set_label_text("Slot %d: %s" % [_active_inventory_slot + 1, item_name]);
	
	# !!TOOPT: could be much optimized here
	for c in _show.get_children():
		_show.remove_child(c);
		c.queue_free();

	if (_inventory[_active_inventory_slot][1] <= 0): return;
	
	if (item != null):
		if (vdb.is_voxel_def(item)):
			var mesh = vdb.create_voxel_mesh_from_def(item); #item.mesh_instance.duplicate();
			if (mesh):
				mesh.scale = Vector3(0.6,0.6,0.6);
				mesh.translation = -Vector3(0.3, 0.5, 0.3);
				_show.add_child(mesh);
			else:
				vr.log_warning("Cannot create mesh in Inventory.update_active_item() from " + item.name);
		elif (vdb.is_item_def(item)):
			# Carefull here; I had a item dupe issue when this was a real item
			var mesh = vdb._create_item_mesh_from_def(item); #item.cached_object_instance.duplicate();
			if (mesh):
				mesh.scale = Vector3(2.0,2.0,2.0);
				mesh.translation = Vector3(0.0, -0.5, 0.2);
				_show.add_child(mesh);
			else:
				vr.log_warning("Cannot create mesh in Inventory.update_active_item() from " + item.name);
		else:
			vr.log_error("Unsupported item in Inventory.update_active_item()")
	

func show_inventory():
	if (!visible):
		visible = true;
		$Area.monitorable = true;
		update_active_item();
		
	if (_active_inventory_controller._button_just_pressed(vr.CONTROLLER_BUTTON.XA)):
		_active_inventory_slot = (_active_inventory_slot + inventory_size - 1) % inventory_size;
		update_active_item();
	if (_active_inventory_controller._button_just_pressed(vr.CONTROLLER_BUTTON.YB)):
		_active_inventory_slot = (_active_inventory_slot + 1) % inventory_size;
		update_active_item();
		

func hide_inventory():
	visible = false;
	$Area.monitorable = false;

var _active_inventory_controller = null;

func _check_display_inventory_gesture(controller : ARVRController):
	
	#vr.show_dbg_info("controller %d" %controller.controller_id, "basis.x = %s" % [str(controller.get_palm_orientation().x)]);
	
	# show only the inventory when the grip trigger is not pressed to avoid
	# showing it when there is an item held
	if (!controller.is_button_pressed(vr.CONTROLLER_BUTTON.GRIP_TRIGGER) &&
		controller.get_palm_transform().basis.x.y > 0.92):
		return true;

func _check_hide_inventory_gesture(controller : ARVRController):
	if (controller.get_palm_transform().basis.x.y < 0.3):
		return true;

func _process(_dt):
	
	if (!vr.inVR):
		if Input.is_key_pressed(KEY_I):
			_active_inventory_controller = vr.leftController;
		if Input.is_key_pressed(KEY_O):
			_active_inventory_controller = null;
			hide_inventory();

	
	if (_active_inventory_controller == null):
		if (_check_display_inventory_gesture(vr.leftController)):
			_active_inventory_controller = vr.leftController;
		if (_check_display_inventory_gesture(vr.rightController)):
			_active_inventory_controller = vr.rightController;
	elif (vr.inVR && _check_hide_inventory_gesture(_active_inventory_controller)):
		_active_inventory_controller = null;
		hide_inventory();
	
	if (_active_inventory_controller):
		
		var palm_transform = _active_inventory_controller.get_palm_transform();
		
		global_transform.origin = palm_transform.origin + Vector3(0, 0.07, 0);
		
		# we need to offset here because else with occlusion you get
		# bad tracking of hands
		if (_active_inventory_controller.is_hand):
			var offset = -palm_transform.basis.y
			offset.y = 0.0;
			offset = offset.normalized();
			global_transform.origin += offset * 0.125;
			
		
		var at = vr.vrCamera.global_transform.origin;
		at.y = global_transform.origin.y;
		
		global_transform = global_transform.looking_at(at, Vector3(0,1,0));
		show_inventory();
	
	#vr.show_dbg_info("controller", "Left Controller basis.x" + str(vr.leftController.global_transform.basis.x.y));
	
	pass;

func _ready():
	hide_inventory();
	
	for _i in range(0, inventory_size):
		_inventory.append([null, 0]);
		
	update_active_item();
