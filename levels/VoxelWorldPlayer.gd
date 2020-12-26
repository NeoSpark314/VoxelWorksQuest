extends Node

var _terrain_tool = null;
var terrain = null;
var parent_world = null;

onready var walk_in_place = $OQ_ARVROrigin/Locomotion_WalkInPlace;
onready var locomotion_stick = $OQ_ARVROrigin/Locomotion_Stick;

onready var feature_falling = $OQ_ARVROrigin/Feature_Falling;
onready var featur_climbing = $OQ_ARVROrigin/Feature_Climbing;

onready var _left_ui_raycast = $OQ_ARVROrigin/OQ_LeftController/Feature_UIRayCast;
onready var _right_ui_raycast = $OQ_ARVROrigin/OQ_RightController/Feature_UIRayCast;


var preferences = {
	auto_put_in_inventory = true
}

var _player_inventory = null;
var _player_toolbelt = null;

var parent_container_build_voxel = null;
var parent_container_destroy_voxel = null;
var parent_container_crafting_grids = null;
var parent_container_crates = null;


# special variables for creative
var _creative_is_flying = false;


var _global_dt := 0.0;

var _destroy_voxel_node = preload("res://dynamic_objects/WorldInteraction_DestroyVoxel.tscn");
var _build_voxel_node = preload("res://dynamic_objects/WorldInteraction_BuildVoxel.tscn");
var _player_dummy = preload("res://dynamic_objects/PlayerDummy.tscn");

var _player_foot_position := Vector3(0, 0, 0);
var _player_voxeldef_below_foot = null;
var _player_voxeldef_above_foot = null;


### client code

var user_dummy_by_uuid = {};
var socket_client = null;
var uuid = vdb.gen_uuid();

func connect_to_server(host: String):
	var SocketClient = load("res://networking/SocketClient.gd");
	socket_client = SocketClient.new();

	socket_client.on("connect", self, "_on_connect");
	socket_client.on("disconnect", self, "_on_disconnect");
	socket_client.on("world_data", self, "load_world");
	socket_client.on("add_player", self, "add_player");
	socket_client.on("remove_player", self, "remove_player");
	socket_client.on("position_player", self, "position_player");
	socket_client.on("play_sfx", self, "play_sfx");
	socket_client.on("crafting_status", self, "crafting_status");
	socket_client.on("increment_destroy", self, "increment_destroy");
	socket_client.on("remove_voxel", self, "remove_voxel");
	socket_client.on("increment_build", self, "increment_build");
	socket_client.on("add_voxel", self, "add_voxel");
	socket_client.on("spawn_item", self, "spawn_item");
	socket_client.on("delete_player_held_object", self, "delete_player_held_object");
	socket_client.on("give_player_item", self, "give_player_item");
	socket_client.on("player_grab_item", self, "player_grab_item");
	socket_client.on("player_release_item", self, "player_release_item");
	socket_client.on("take_from_crate", self, "player_take_from_crate");
	socket_client.on("grab_from_inventory", self, "grab_from_inventory");
	socket_client.on("move_to_inventory", self, "move_to_inventory");
	socket_client.on("move_to_tool_slot", self, "player_hand_to_tool");
	socket_client.on("move_tool_to_hand", self, "player_tool_to_hand");
	socket_client.on("set_active_slot", self, "player_set_active_slot");

	socket_client.connect_to_host(host);

### message handlers

func _on_connect():
	pass;

func _on_disconnect():
	_back_to_main_menu();

func load_world(full_save_dictionary, players):
	if full_save_dictionary.desc.game_version != vdb.GAME_VERSION_STRING:
		socket_client.disconnect();
		return;

	parent_world.add_child(self);

	vdb.load_world(full_save_dictionary);
	vdb._set_player_position(vdb.main_world_generator.start_position);

	for data in players:
		var dummy = _player_dummy.instance();
		user_dummy_by_uuid[data.uuid] = dummy;
		parent_world.add_child(dummy);
		dummy.load_player_data(data);
	
	var terrain = parent_world.terrain;

	#only after loading the stream is currently valid
	terrain.stream = vdb.main_world_generator;

	# reattach terrain
	parent_world.get_parent().add_child(terrain);
	
	move_player_into_terrain_after_load(terrain);
	
	socket_client.send_reliable("identify", [ uuid, preferences ]);

func add_player(player_uuid, pid):
	if uuid == player_uuid:
		return;
	
	var dummy = _player_dummy.instance();
	dummy.uuid = player_uuid;
	dummy.pid = pid;
	user_dummy_by_uuid[player_uuid] = dummy;
	parent_world.add_child(dummy);
	dummy.generate_head();

func remove_player(player_uuid):
	if uuid == player_uuid:
		return;
	
	user_dummy_by_uuid[player_uuid].queue_free();
	user_dummy_by_uuid.erase(player_uuid);

func position_player(player_uuid, head_transform, left_hand_transform, right_hand_transform):
	if player_uuid == uuid:
		return;
	
	var player = user_dummy_by_uuid[player_uuid];
	
	if !player:
		return;
	
	player.update_positions(head_transform, left_hand_transform, right_hand_transform);

func play_sfx(s, pos):
	vdb._play_sfx(s, pos);

func crafting_status(player_uuid, voxel_pos, success, is_physical):
	var crafting_grid;

	for cg in parent_container_crafting_grids.get_children():
		if cg.global_transform.origin == voxel_pos:
			crafting_grid = cg;

	if !crafting_grid:
		return;

	crafting_grid.locked = false;

	if success:
		crafting_grid.queue_free();

		vdb._play_sfx(vdb.sfx_craft_success, crafting_grid.transform.origin + Vector3.ONE / 2);

		if uuid == player_uuid && is_physical:
			vdb.global_statistics.crafted_items += 1;


func increment_destroy(voxel_position, hit_position, voxel_id, damage):
	var destroy_node = null;

	# search if we already have a node at the target position
	for n in parent_container_destroy_voxel.get_children():
		if (n.translation == voxel_position):
			destroy_node = n;
			break;
	
	if (destroy_node == null):
		var voxel_def = vdb.voxel_block_defs[voxel_id];
		destroy_node = _destroy_voxel_node.instance();
		destroy_node.initialize(voxel_position, hit_position, voxel_def);
		parent_container_destroy_voxel.add_child(destroy_node);
	
	return destroy_node.increment_destroy(damage);

func remove_voxel(player_uuid, pos, is_physical):
	if (uuid == player_uuid && is_physical):
		vdb.global_statistics.mined_blocks += 1;
	
	_terrain_tool.channel = 0; #VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.value = 1;
	_terrain_tool.mode = VoxelTool.MODE_REMOVE;
	_terrain_tool.do_point(pos);
	terrain.stream.persistence_change_voxel(pos, 0);

func spawn_item(position, item_uuid, item_name):
	var def = vdb.get_def_from_name(item_name);
	var item = vdb.create_object_from_def(def);
	item.uuid = item_uuid;
	parent_world.add_child(item);
	item.global_transform.origin = position;

func increment_build(voxel_position, hit_position, voxel_id):
	var build_node = null;

	# search if we already have a node at the target position
	for n in vdb.voxel_world_player.parent_container_build_voxel.get_children():
		if (n.translation == voxel_position):
			build_node = n;
			break;
	
	# spawn a new build node if we did not finde one above
	if (build_node == null):
		if (!core.can_build_at_pos(voxel_position)):
			return false;
		
		var voxel_def = vdb.voxel_block_defs[voxel_id];
		build_node = _build_voxel_node.instance();
		build_node.initialize(voxel_position, hit_position, voxel_def);
		parent_container_build_voxel.add_child(build_node);
	
	return build_node.increment_build()

func add_voxel(player_uuid, pos, voxel_id, is_physical):
	if (uuid == player_uuid && is_physical):
		vdb.global_statistics.build_blocks += 1;
	
	_terrain_tool.channel = 0; #VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.value = voxel_id;
	_terrain_tool.mode = VoxelTool.MODE_ADD;
	_terrain_tool.do_point(pos);
	terrain.stream.persistence_change_voxel(pos, voxel_id)

func delete_player_held_object(player_uuid, hand_name):
	var player = core.get_player(player_uuid);
	player.delete_held_object(hand_name);

func give_player_item(player_uuid, item_name):
	var player = core.get_player(player_uuid);
	
	var item_def = vdb.get_def_from_name(item_name);
	
	var slot = player.get_available_slot(item_def);

	if slot == -1:
		return false;
	
	player.give_item(item_def, slot);
	return true;

func player_grab_item(player_uuid, hand_name, item_uuid):
	var player = core.get_player(player_uuid);

	# todo: use a dictionary to store items by uuid

	for crafting_grid in parent_container_crafting_grids.get_children():
		for node in crafting_grid.grid_node_container.get_children():
			var child = node.get_child(0);

			if child && child.has_method("can_grab") && child.uuid == item_uuid:
				node.remove_child(child);
				parent_world.add_child(child);
				player.grab_with(hand_name, child);
				break;

	for child in parent_world.get_children():
		if child.has_method("can_grab") && child.uuid == item_uuid:
			player.grab_with(hand_name, child);
			break;

func player_release_item(player_uuid, hand_name, final_transform):
	var player = core.get_player(player_uuid);
	
	var item = player.release_with(hand_name);

	if !item:
		return;

	item.global_transform = final_transform;
	var voxel_pos = final_transform.origin.floor();
	
	var crate = core.find_crate_for_voxel_pos(voxel_pos);

	if crate:
		if crate.can_put(item):
			crate.put_item(item);
		else:
			vdb._play_sfx(vdb.sfx_metal_footstep, final_transform.origin);
		return;

	_check_and_start_crafting(item);

func player_take_from_crate(player_uuid, hand_name, voxel_pos, item_uuid):
	var crate = core.find_crate_for_voxel_pos(voxel_pos);

	if !crate:
		return;

	var item = crate.get_grab_object();

	if !item:
		return;

	item.uuid = item_uuid;
	core.get_player(player_uuid).grab_with(hand_name, item);

func grab_from_inventory(player_uuid, hand_name, slot, item_uuid):
	var player = core.get_player(player_uuid);

	var item = player.take_item_from_slot(slot);

	if !item:
		return;

	item.uuid = item_uuid;
	player.grab_with(hand_name, item);

func move_to_inventory(player_uuid, hand_name, slot):
	var player = core.get_player(player_uuid);
	
	var item = player.release_with(hand_name);

	if !item:
		return;

	item.queue_free();

	player.give_item(item.get_def(), slot);

func player_hand_to_tool(player_uuid, hand_name, slot):
	var player = core.get_player(player_uuid);
	player.move_held_item_to_tool_slot(hand_name, slot);

func player_tool_to_hand(player_uuid, slot, hand_name):
	var player = core.get_player(player_uuid);
	player.move_tool_to_hand(slot, hand_name);

func player_set_active_slot(player_uuid, slot):
	var player = core.get_player(player_uuid);
	player.set_active_slot(slot);

### requests

func _attempt_craft(voxel_pos, hand_name, is_physical):
	if socket_client:
		socket_client.send_reliable("attempt_craft", [ voxel_pos, hand_name, is_physical ]);
	else:
		core.player_craft_with(uuid, voxel_pos, hand_name, is_physical);

func _attempt_break(voxel_pos, pos, hand_name, is_physical):
	if socket_client:
		socket_client.send_reliable("attempt_break", [ voxel_pos, pos, hand_name, is_physical ]);
	else:
		core.attempt_break(uuid, preferences, voxel_pos, pos, hand_name, is_physical);

func _attempt_build(voxel_pos, pos, hand_name, is_physical):
	if socket_client:
		socket_client.send_reliable("attempt_build", [ voxel_pos, pos, hand_name, is_physical ]);
	else:
		core.attempt_build(uuid, voxel_pos, pos, hand_name, is_physical);

func _creative_build(voxel_pos, voxel_id):
	if socket_client:
		socket_client.send_reliable("creative_build", [ voxel_pos, voxel_id ]);
	else:
		core.add_voxel(uuid, voxel_pos, voxel_id, false);

func _creative_destroy(voxel_pos):
	if socket_client:
		socket_client.send_reliable("creative_destroy", [ voxel_pos ]);
	else:
		core.remove_voxel(uuid, voxel_pos, false);

func _send_positions():
	if socket_client:
		socket_client.send("position_player", [
			vr.vrCamera.global_transform,
			vr.leftController.get_grab_transform(),
			vr.rightController.get_grab_transform()
		]);
	else:
		core.update_player_positions(
			uuid,
			vr.vrCamera.global_transform,
			vr.leftController.get_grab_transform(),
			vr.rightController.get_grab_transform()
		);

func send_active_slot(slot):
	if socket_client:
		socket_client.send_reliable("set_active_slot", [ slot ]);
	else:
		core.set_player_active_slot(uuid, slot);

func request_grab(hand_name, item_uuid):
	if socket_client:
		socket_client.send_reliable("grab_item", [ hand_name, item_uuid ]);
	else:
		core.player_grab_item(uuid, hand_name, item_uuid);

func request_from_crate(hand_name, crate_position):
	if socket_client:
		socket_client.send_reliable("grab_from_crate", [ hand_name, crate_position ]);
	else:
		core.player_take_from_crate(uuid, hand_name, crate_position);

func request_from_inventory(hand_name, slot):
	if socket_client:
		socket_client.send_reliable("grab_from_inventory", [ hand_name, slot ]);
	else:
		core.player_grab_from_inventory(uuid, hand_name, slot);

func request_move_to_inventory(hand_name, slot):
	if socket_client:
		socket_client.send_reliable("move_to_inventory", [ hand_name, slot ]);
	else:
		core.move_to_inventory(uuid, hand_name, slot);

func request_move_to_tool_slot(hand_name, slot):
	if socket_client:
		socket_client.send_reliable("move_to_tool_slot", [ hand_name, slot ]);
	else:
		core.move_to_tool_slot(uuid, hand_name, slot);

func request_tool_to_hand(slot, hand_name):
	if socket_client:
		socket_client.send_reliable("move_tool_to_hand", [ slot, hand_name ]);
	else:
		core.move_tool_to_hand(uuid, slot, hand_name);

func request_release(hand_name, final_transform):
	if socket_client:
		socket_client.send_reliable("release_grab", [ hand_name, final_transform ]);
	else:
		core.player_release_item(uuid, hand_name, final_transform);


### core Player interface

func gen_player_data():
	var data = {
		uuid = uuid,
		pid = 0,
		inventory = _player_inventory.get_save_dictionary(),
		toolbelt_left = null,
		toolbelt_right = null,
		hand_left = null,
		hand_right = null
	};

	var toolbelt_left = _player_toolbelt.slots.left.get_slot_object();

	if toolbelt_left:
		data.toolbelt_left = {
			uuid = toolbelt_left.uuid,
			name = toolbelt_left.get_def().name
		};

	var toolbelt_right = _player_toolbelt.slots.right.get_slot_object();

	if toolbelt_right:
		data.toolbelt_right = {
			uuid = toolbelt_right.uuid,
			name = toolbelt_right.get_def().name
		};

	var left_held_object = get_held_object('left');

	if left_held_object:
		data.hand_left = left_held_object.uuid;

	var right_held_object = get_held_object('right');

	if right_held_object:
		data.hand_right = right_held_object.uuid;

	return data;

func grab_with(hand_name, item):
	var controller = _get_controller(hand_name);
	var obj_grabber = controller.find_node("ObjectGrabber"); #!!TOOPT
	obj_grabber.held_object = item.get_grab_object(controller);
	controller.visible = false;

func release_with(hand_name):
	var controller = _get_controller(hand_name);
	var obj_grabber = controller.find_node("ObjectGrabber"); #!!TOOPT
	var item = obj_grabber.held_object;
	obj_grabber.release_grab();
	
	if item:
		item.visible = true;

	return item;

func get_held_object(hand_name):
	var controller = _get_controller(hand_name);
	var obj_grabber = controller.find_node("ObjectGrabber"); #!!TOOPT
	
	if (obj_grabber):
		return obj_grabber.held_object;
	else:
		return null;

func _get_controller(hand_name):
	if hand_name == "left":
		return vr.leftController;
	else:
		return vr.rightController;

func delete_held_object(hand_name):
	var controller = _get_controller(hand_name);
	var obj_grabber = controller.find_node("ObjectGrabber"); #!!TOOPT
	obj_grabber.delete_held_object();

func give_item(item_def, slot):
	_player_inventory.add_item_to_slot(item_def, slot);

func get_available_slot(voxel_or_item_def):
	return _player_inventory.get_available_slot(voxel_or_item_def);

func move_held_item_to_tool_slot(hand_name, slot_name):
	var item = release_with(hand_name);
	
	_player_toolbelt.slots[slot_name].put_item(item);

func move_tool_to_hand(slot_name, hand_name):
	var item = _player_toolbelt.slots[slot_name].get_slot_object();

	item.get_parent().remove_child(item);
	parent_world.add_child(item);

	grab_with(hand_name, item);

func take_item_from_slot(slot):
	return _player_inventory.take_item_from(slot);

func set_active_slot(slot):
	_player_inventory._active_inventory_slot = slot;
	_player_inventory.update_active_item();

###

func _is_a_crafting_voxel(vid):
	if (vid == vdb.voxel_block_names2id.tree): return true;
	if (vid == vdb.voxel_block_names2id.aspen_tree): return true;
	if (vid == vdb.voxel_block_names2id.pine_tree): return true;
	if (vid == vdb.voxel_block_names2id.jungle_tree): return true;
	
	if (vid == vdb.voxel_block_names2id.wood_workbench): return true;
	if (vid == vdb.voxel_block_names2id.stone_workbench): return true;
	if (vid == vdb.voxel_block_names2id.furnace): return true;
	if (vid == vdb.voxel_block_names2id.anvil): return true;
	
	return false;

func _check_and_start_crafting(held_object):
	for cg in parent_container_crafting_grids.get_children():
		if (cg.check_craft_place(held_object)): return; # ok; we found an existing craft place
		
	# next we check if we can start crafting here
	var pos = held_object.global_transform.origin;
	
	var vid = get_voxel_id_from_pos(pos);
	#print(" " + str(pos) + " vid = " + str(vid))
	
	if (vid == 0):
		var vid_below = get_voxel_id_from_pos(pos - Vector3(0, 1, 0));
		#print(" " + str(pos) + " vid below = " + str(vid_below))
		#print(vdb.voxel_block_names2id.tree);
		# We can craft on top of tree trunks for now
		if (_is_a_crafting_voxel(vid_below)):
			var rotation = floor((held_object.rotation_degrees.y + 45) / 90) * 90;

			var cg : Spatial = load("res://dynamic_objects/CraftingGrid.tscn").instance();
			cg.initialize_crafting_grid(vid_below, rotation);
			parent_container_crafting_grids.add_child(cg);
			cg.global_transform.origin = pos.floor();
			cg.check_craft_place(held_object);

# for now we assume that all grabbable objects are an area. This might fail in the future
# and then needs some rethinking/factoring
func _on_ObjectGrabber_grab_released_held_object(hand_name, held_object : Spatial):
	if _player_toolbelt.slots.left.can_put(held_object):
		request_move_to_tool_slot(hand_name, "left");
		return;

	if _player_toolbelt.slots.right.can_put(held_object):
		request_move_to_tool_slot(hand_name, "right");
		return;

	if _player_inventory.can_put(held_object):
		var slot = get_available_slot(held_object.get_def());
		request_move_to_inventory(hand_name, slot);
		return;

	request_release(hand_name, held_object.global_transform);


func get_voxel_id_from_pos(pos):
	var voxel_pos = pos.floor();
	var voxel_id = _terrain_tool.get_voxel(voxel_pos);
	return voxel_id;


func get_voxel_def_from_pos(pos):
	var voxel_id = get_voxel_id_from_pos(pos);
	return vdb.voxel_block_defs[voxel_id];


func debug_axis(global_pos):
	var axis = load("res://static_objects/Debug_Axis.tscn").instance();
	parent_world.add_child(axis);
	axis.global_transform.origin = global_pos;

func get_interaction_points(controller, hand_name):
	var obj = get_held_object(hand_name);
	var ret = []; #!!TOOPT: do we need to optimize this??
	if obj:
		var hpc : Spatial = obj.get_hit_point_collection_node();
		if (hpc.get_child_count() == 0): vr.log_warning("No interaction point on item defined");
		else:
			for c in hpc.get_children():
				ret.append(c.global_transform.origin);
	ret.append(controller.get_palm_transform().origin);
	return ret;
	



# this function uses (and resets) hit_start_point
func check_attack_voxel(pos: Vector3, _speed, hand_name, is_physical):
	var held_obj = get_held_object(hand_name);

	var voxel_pos = pos.floor();

	# check if we are hitting a crafting area
	for cg in parent_container_crafting_grids.get_children():
		if (cg.can_attempt_craft(pos)):
			if cg.attempt_craft():
				_attempt_craft(voxel_pos, hand_name, is_physical);
			return true;
	
	if (held_obj && held_obj.get_voxel_def() && core.can_build_at_pos(voxel_pos)):
		_attempt_build(voxel_pos, pos, hand_name, is_physical)
		return true;

	if (core.can_break(voxel_pos, held_obj)):
		_attempt_break(voxel_pos, pos, hand_name, is_physical);
		return true;
	
	return false;
	

const _hit_min_speed_default = 3.0;
const _hit_min_dist_default = 0.3;
var _hit_min_speed = _hit_min_speed_default;
var _hit_min_dist = _hit_min_dist_default;
var _hit_traveld_distance  = [0.0, 0.0, 0.0];

# This looks a the controller speed; if starts to get fast enough it marks it as start position and 
# remembers it via controller_id; it then checks if a hit voxel was hit with fast enough speed to count
# as a hit...
var _time_since_last_attack_voxel = 0.0;
const _min_time_between_attack = 0.5;

func _controller_hit_move_detection(controller : ARVRController, hand_name: String):
	
	if (controller.is_hand):
		_hit_min_speed = 1.0;
		_hit_min_dist = _hit_min_dist_default - 0.07;
	else:
		_hit_min_speed = _hit_min_speed_default;
		_hit_min_dist = _hit_min_dist_default;
		
		var voxel_def = get_voxel_def_from_pos(controller.global_transform.origin);
		
		if (!voxel_def.transparent):
			controller.set_rumble(0.2);
		else:
			controller.set_rumble(0.0);
	
	_time_since_last_attack_voxel += _global_dt;
	if (_time_since_last_attack_voxel < _min_time_between_attack): return;
	
	#var controller_position = get_interaction_point(controller);
	var interaciton_points = get_interaction_points(controller, hand_name);
	
	# This logic tries to detect the start point of a swing by marking the point the controller
	# goes over a specific speed threshold
	var controller_speed_v3 = controller.get_linear_velocity();
	var controller_speed = controller_speed_v3.length();
		
	if (controller_speed < _hit_min_speed):
		_hit_traveld_distance[controller.controller_id] = 0.0;
	else:
		_hit_traveld_distance[controller.controller_id] += controller_speed * _global_dt;

	for point in interaciton_points:
	
		if (!vr.inVR && controller._button_pressed(vr.CONTROLLER_BUTTON.INDEX_TRIGGER)):
			if (check_attack_voxel(point, null, hand_name, false)):
				_time_since_last_attack_voxel = 0.0;
			return;
			
		if (!(vdb.game_mode == vdb.GAME_MODE.SPORTIVE) && controller._button_pressed(vr.CONTROLLER_BUTTON.XA)):
			if (check_attack_voxel(point, null, hand_name, false)):
				_time_since_last_attack_voxel = 0.0;
			return;
		
		if (_hit_traveld_distance[controller.controller_id] > _hit_min_dist):
			if (check_attack_voxel(point, controller_speed, hand_name, true)):
				_hit_traveld_distance[controller.controller_id] = 0.0;
				_time_since_last_attack_voxel = 0.0;



func get_pointed_voxel(controller : ARVRController):
	var origin = controller.get_palm_transform().origin;
	var forward = -controller.get_palm_transform().basis.z.normalized();
	var hit = _terrain_tool.raycast(origin, forward, 64)
	return hit

# since now the player is a child of the main world we
# need to call this function from the main world also for all objects that live
# in the main world; it will be deleted from there
func oq_can_static_grab(grabbed_body, grab_area : Area, grab_controller : ARVRController, overlapping_bodies : Array):
	# we check if only a single body is overlapping; this is a simple workaround to not
	# grab the voxel world when there is a rigid body lying around
	if (overlapping_bodies.size() != 1): return false;
	
	if (grab_area.get_overlapping_areas().size() != 0): return false;
	
	#TODO: check if which voxels are overlapped and if they are actually climbable
	if (grabbed_body == terrain): return true;
	
	return false;


var voxel_box_mover := VoxelBoxMover.new();

const _invalid_player_pos_fade_duration := 0.125;
var _invalid_player_pos_fade_state := 0.0;
var _time_in_invalid_position := 0.0;

var _last_valid_position := Vector3(0, 0, 0);

func _voxel_id_valid_for_head(id) -> bool:
	if (id == 0): return true;
	if (vdb.game_mode == vdb.GAME_MODE.CREATIVE): return true;
	
	var voxel_block_def = vdb.voxel_block_defs[id];
	if (voxel_block_def.transparent): return true;

	return false;


var _player_in_valid_area := false;

# check if the player head is in a valid area; else: fade to black
func check_player_in_valid_area(dt):
	var valid := true;
	
	var head_pos := vr.vrCamera.global_transform.origin;
	var view_dir := -vr.vrCamera.global_transform.basis.z;
	var leftright_dir := -vr.vrCamera.global_transform.basis.x;

	var eps := 0.1;

	valid = valid && (_voxel_id_valid_for_head(get_voxel_id_from_pos(head_pos + view_dir*eps)));
	valid = valid && (_voxel_id_valid_for_head(get_voxel_id_from_pos(head_pos - view_dir*eps)));
	valid = valid && (_voxel_id_valid_for_head(get_voxel_id_from_pos(head_pos + leftright_dir*eps)));
	valid = valid && (_voxel_id_valid_for_head(get_voxel_id_from_pos(head_pos - leftright_dir*eps)));

	if (!valid):
		_invalid_player_pos_fade_state = min(_invalid_player_pos_fade_state+dt, _invalid_player_pos_fade_duration);
	else:
		_invalid_player_pos_fade_state = max(_invalid_player_pos_fade_state-dt, 0.0);
	var c = (_invalid_player_pos_fade_duration - _invalid_player_pos_fade_state) / _invalid_player_pos_fade_duration;
	vr.set_default_layer_color_scale(Color(c, c, c, c));
	
	if (valid):
		_time_in_invalid_position = 0.0;
		_last_valid_position = vr.vrCamera.global_transform.origin;
	else:
		_time_in_invalid_position += dt;
		
	_player_in_valid_area = valid;
	
	return valid;


func _get_head_collision_aabb():
	var h = vr.get_current_player_height();
	var w = 0.6;
	var center = Vector3(-w*0.5, -h*0.1, -w*0.5);
	var size = Vector3(w, h*0.1, w);
	return AABB(center, size);
	

func oq_locomotion_stick_check_move(velocity, dt):
	if (walk_in_place.is_moving): return Vector3(0.0, 0.0, 0.0); # no stick movement when jogging
	
	#var head_pos = vr.vrCamera.global_transform.origin;
	var move = voxel_box_mover.get_motion(_coll_check_pos, velocity * dt,  _get_head_collision_aabb(), terrain);
	
	if (vdb.game_mode == vdb.GAME_MODE.SPORTIVE):
		move /= 8.0;
	else:
		move *= vdb.gameplay_settings.stick_locomotion_speed_multiplier;
	
	return move / dt;

# this is the cached position to have the collision check work robustly
var _coll_check_pos = Vector3(0,0,0);
func oq_walk_in_place_check_move(move, speed):
	# voxel_box_mover.get_motion(...) is not easy to use here
	# as the player can easily move during running the head a bit inside the voxels
	# and then the check fails because the bounding box is already inside...
	move = voxel_box_mover.get_motion(_coll_check_pos, move, _get_head_collision_aabb(), terrain);
	
	vdb.global_statistics.traveled_distance += speed * _global_dt;
	
	#vr.show_dbg_info("traveled_distance", str(vdb.global_statistics.traveled_distance));
	
	return move;
	
func oq_feature_falling_check_move_up(move):
	var head_pos = vr.vrCamera.global_transform.origin;
	var delta_y = Vector3(0, 0.125, 0.0);
	# already stuck in a wall => not moving up
	
	var head_pos_id = get_voxel_id_from_pos(head_pos);
	
	if (!_voxel_id_valid_for_head(head_pos_id)): return Vector3(0,0,0);

	var head_pos_up_id = get_voxel_id_from_pos(head_pos+move+delta_y);
	# sth. will get in the way...
	if (!_voxel_id_valid_for_head(head_pos_up_id)): return Vector3(0,0,0);
	
	return move;

# we have a "box" move with the player in the world but perfectly collision checked
# to avoid problems with the player moving the head inside objects
func _update_coll_check_pos():
	var head_pos = vr.vrCamera.global_transform.origin;
	var dist = (head_pos - _coll_check_pos);
	if (dist.length_squared() > 0.25):
		#print("_update_coll_check_pos"); # important to know if sth. goes wrong with collision
		_coll_check_pos = head_pos;
	else:
		var move = voxel_box_mover.get_motion(_coll_check_pos, (head_pos - _coll_check_pos), _get_head_collision_aabb(), terrain);
		_coll_check_pos += move;

var _time_since_climbing = 0.0;

var _stick_locomotion_step_sound_timer = 0.0;
const _stick_locomotion_step_sound_threshold = 0.5;


func _reorient_toolbelt():
	var angle_y = vr.vrCamera.global_transform.basis.get_euler().y - PI * 0.5;
	_player_toolbelt.global_transform.basis = Basis(Vector3(0.0, angle_y, 0.0));

const _cm_color_green = Color(0,1,0,0.3);
const _cm_color_red = Color(1,0,0,0.3);
var _cm_ui = null;

func _creative_mode_update_controller_world_interaction(controller, isAdd, show):
	# just a quick solution for now; need to redo cleaner when reworking the creative mode
	
	var id = controller.controller_id;
	var m : MeshInstance = $CreativeModeStuff.find_node("VoxelMarker%d"%id)
	
	if (!show):
		m.visible = false;
		return;
	
	if (isAdd):
		m.mesh.surface_get_material(0).albedo_color =_cm_color_green;
	else:
		m.mesh.surface_get_material(0).albedo_color =_cm_color_red;

	m.visible = true;
	
	var pv = get_pointed_voxel(controller);
	if (pv):
		if (isAdd):
			m.global_transform.origin = pv.previous_position + Vector3(0.5, 0.5, 0.5);
			if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.INDEX_TRIGGER)):
				_creative_build(pv.previous_position, _cm_ui.get_selected_voxel_id());
		else:
			m.global_transform.origin = pv.position + Vector3(0.5, 0.5, 0.5);
			if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.INDEX_TRIGGER)):
				_creative_destroy(pv.position);
	else:
		m.visible = false;



func _check_and_show_creative_mode_ui(controller : ARVRController):
	var ui = $CreativeModeStuff/OQ_UI2D_CreativeModeMainUI;
	if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.GRIP_TRIGGER)):
		ui.visible = true;
		ui.global_transform.origin = controller.global_transform.origin;
		ui.global_transform.basis = controller.global_transform.basis;
		ui.global_transform.origin -= controller.get_palm_transform().basis.z * 0.5;


func _update_ui_raycasts_visibility():
	_left_ui_raycast.visible = false;
	_right_ui_raycast.visible = false;

	if (_creative_is_flying):
		_left_ui_raycast.visible = true;
		_right_ui_raycast.visible = true;
		
	if ($HUD/ArmUserInterface.active_controller == vr.leftController):
		_right_ui_raycast.visible = true;
	if ($HUD/ArmUserInterface.active_controller == vr.rightController):
		_left_ui_raycast.visible = true;
		
	if (_ingame_menu.visible):
		_left_ui_raycast.visible = true;
		_right_ui_raycast.visible = true;

	
func _check_and_process_creative_mode(dt):
	if (   (vr.button_pressed(vr.BUTTON.A) && vr.button_just_pressed(vr.BUTTON.B)) 
		|| (vr.button_pressed(vr.BUTTON.B) && vr.button_just_pressed(vr.BUTTON.A))):
			_creative_is_flying = !_creative_is_flying;
			if(_creative_is_flying):
				vr.vrOrigin.global_transform.origin.y += 1.0;
				$CreativeModeStuff.visible = true;
				_cm_ui = $CreativeModeStuff.find_node("CreativeModeMainUI", true, false);
				if (!_cm_ui): vr.log_error("Could not find CreativeModeMainUI");
				var ui = $CreativeModeStuff/OQ_UI2D_CreativeModeMainUI;
				ui.visible = true;
				ui.global_transform.origin = vr.rightController.global_transform.origin;
				ui.global_transform.basis = vr.rightController.global_transform.basis;
				ui.global_transform.origin -= vr.rightController.get_palm_transform().basis.z * 0.5;
			else:
				$CreativeModeStuff.visible = false;


	if (_creative_is_flying):
		feature_falling.active = false;
		feature_falling.force_move_up = false;
		
		_check_and_show_creative_mode_ui(vr.leftController);
		_check_and_show_creative_mode_ui(vr.rightController);

		var _fly_up_down_speed = 2.0;

		if (vr.button_pressed(vr.BUTTON.A)):
			vr.vrOrigin.global_transform.origin.y -= _fly_up_down_speed * dt;
		if (vr.button_pressed(vr.BUTTON.B)):
			vr.vrOrigin.global_transform.origin.y += _fly_up_down_speed * dt;
		
		_creative_mode_update_controller_world_interaction(vr.dominantController, true, !_right_ui_raycast.is_colliding);
		_creative_mode_update_controller_world_interaction(vr.nonDominantController, false, !_left_ui_raycast.is_colliding);


func _back_to_main_menu():
	if socket_client:
		socket_client.disconnect_from_host();
		socket_client = null;

	if core.server:
		core.stop_server();

	user_dummy_by_uuid = {};

	# clear inventory for next world
	_player_inventory.clear();
	_player_toolbelt.clear();

	var parent = get_parent();

	if parent:
		parent.remove_child(self); # we need to remove vdb.voxel_world_player 
	
	terrain = null;

	vr.switch_scene("res://levels/MainMenuRoom.tscn", 0.0, 0.0);
	
onready var _ingame_menu = $HUD/IngameMenu_3DScene;

var _server_save_timer := 0.0;

func _physics_process(dt):
	# don't do anythinG at the moment when launched as dedicated server
	# (there is some out of memory bug when the belo code is executed as server)
	if (vdb.startup_settings.dedicated_server): 
		# a very hacky way to save every minute:
		_server_save_timer += dt;
		if (_server_save_timer >= 60.0):
			_save_all();
			_server_save_timer = 0.0;
		return;
	
	_global_dt = dt;
	if (vr.switch_scene_in_progress || terrain == null): 
		return;
	
	vdb.global_statistics.total_playtime += dt;

	if (vr.button_just_pressed(vr.BUTTON.ENTER)):
		_ingame_menu.toggle_visible();
	
	# foot position with a slight epsilon
	_player_foot_position = vr.vrCamera.global_transform.origin - Vector3(0.0, vr.get_current_player_height(), 0.0);
	
	# this is only valid if the player is positioned correctly above ground
	_player_voxeldef_below_foot = get_voxel_def_from_pos(_player_foot_position - Vector3(0.0, 0.2, 0.0));
	_player_voxeldef_above_foot = get_voxel_def_from_pos(_player_foot_position + Vector3(0.0, 0.2, 0.0));
	
	
	#vr.show_dbg_info("above_foot", _player_voxeldef_above_foot.name)
	#vr.show_dbg_info("below_foot", _player_voxeldef_below_foot.name)

	_update_coll_check_pos();
	check_player_in_valid_area(dt);

	if (!vr.inVR):
		#vr.show_dbg_info("_player_in_valid_area", str(_player_in_valid_area));
		pass;

	# we track the time since climbing
	if (featur_climbing.active_grab != null):
		_time_since_climbing = 0.0;
	else:
		_time_since_climbing += dt;

	# for now deactivate falling and forcing up always when not moving or
	# in an invalid area; maybe could also try again to use bigger radius for falling
	# ...
	feature_falling.active = true;
	feature_falling.force_move_up = true;
	if (not _player_in_valid_area):
		feature_falling.active = false;
	if (not walk_in_place.is_moving && vr.inVR && not locomotion_stick.is_moving): # to not trip up testing with the simulator
		#feature_falling.active = false;
		if (_time_since_climbing > 0.5): # we want to auto-move up after climbing; arbitrary threshold here
			feature_falling.force_move_up = false;


	if (vdb.game_mode == vdb.GAME_MODE.CREATIVE):
		# Note: this function will also disable feature_falling
		_check_and_process_creative_mode(dt);
		
	if (!_creative_is_flying):
		# arm menu for now only not in creative due to UI raycast conflicting
		$HUD/ArmUserInterface._check_and_process_process(dt);


	_controller_hit_move_detection(vr.rightController, "right");
	_controller_hit_move_detection(vr.leftController, "left");
	
	_update_ui_raycasts_visibility();

	
	var play_step_sound = false;
	
	if (walk_in_place.step_low_just_detected):
		vdb.global_statistics.steps_taken += 1;
		play_step_sound = true;
			
	if (locomotion_stick.is_moving):
		_stick_locomotion_step_sound_timer += dt;
		if (_stick_locomotion_step_sound_timer > _stick_locomotion_step_sound_threshold):
			_stick_locomotion_step_sound_timer = 0.0;
			play_step_sound = true;
		
		
	if (play_step_sound && _player_voxeldef_below_foot.geometry_type != vdb.GEOMETRY_TYPE.None):
		vdb.play_sfx_footstep(_player_voxeldef_below_foot, _player_foot_position);
		
		_reorient_toolbelt(); # for now we do this here; maybe there is a better option
		

func _save_all():
	if (!parent_world.save_enabled):
		return false;
		
	vr.log_info("Saving game");
	
	vdb.persistence_save_game(persisted_nodes_array);
	vdb.save_global_statistics();
	vdb.save_gameplay_settings();
	
	return true;




func _notification(what):
	if (what == NOTIFICATION_WM_QUIT_REQUEST ||
		what == NOTIFICATION_APP_PAUSED): # do we really want to save always on pause?
			_save_all();

	if (what == NOTIFICATION_APP_RESUMED):
		pass;


var persisted_nodes_array = [];

func get_save_dictionary() -> Dictionary:
	var ret = {
		items_in_world = [],
		objects_in_world = [],
		crates_in_world = [],
	}
	
	# all nodes attached to the root are checked for objects and then saved
	for node in parent_world.get_children():
		
		if (("_world_object_type" in node)):
			ret.objects_in_world.append(node.get_save_dictionary());
		
		# crude way of detecting that it is an Object_Item or ObjectVoxelBlock
		#if (("_item_def" in node) || ("_voxel_def" in node)):
		if (("_item_def" in node)):
			ret.items_in_world.append(node.get_save_dictionary());
			
	# next we store all objects currently in a crafting grid to not loose them
	for craft_grid in parent_container_crafting_grids.get_children():
		for node in craft_grid.get_all_objects_in_grid():
			if (("_item_def" in node) || ("_voxel_def" in node)):
				ret.items_in_world.append(node.get_save_dictionary());

	for c in parent_container_crates.get_children():
		ret.crates_in_world.append(c.get_save_dictionary());

	return ret;
	
func apply_save_dictionary(r : Dictionary):
	if (r.has("objects_in_world")):
		for o in r.objects_in_world:
			var obj = vdb.create_world_object_from_type(o.world_object_type);
			parent_world.add_child(obj)
			obj.apply_save_dictionary(o);
			
	if (r.has("crates_in_world")):
		for c in r.crates_in_world:
			print("Crate: ")
			print(c);
			var crate = load("res://dynamic_objects/Container_Crate.tscn").instance();
			parent_container_crates.add_child(crate);
			crate.apply_save_dictionary(c);
		
	
	for n in r.items_in_world:
		#print(n.def_name)
		var def = vdb.get_def_from_name(n.def_name);
		
		if (def == null):
			vr.log_error("Could not load def " + n.def_name);
			continue;
		
		#: filter out _voxel_def objects; this was a change in 0.3.2 to not store
		#  floating blocks!!!
		if (not vdb.is_item_definition(def)): continue;
		
		var obj = vdb.create_object_from_def(def);
		if (obj):
			#print("Created: " + obj.name)
			parent_world.add_child(obj);
			obj.apply_save_dictionary(n);
		else:
			vr.log_error("Could not load object from " + str(n));


	#!!TODO: this is a hacky way to always provide a crafting guide... should be improved/removed
func hack_check_and_give_craft_guide():
	var has_guide = false;
	var the_guide_in_world = null;
	
	for node in parent_world.get_children():
		print(node.name)
		if (("_item_def" in node)):
			if (node._item_def.name == "crafting_guide"): 
				has_guide = true;
				
				#remember the found guide to reset it if requested
				if (vdb.startup_settings.reset_crafting_guide):
					the_guide_in_world = node;
					
	print("has guide: " + str(has_guide))
			
	if (_player_inventory.has_item_or_block_by_name("crafting_guide")): has_guide = true;
	
	if (_player_toolbelt.find_node("Item_CraftingGuide", true, false)): has_guide = true;
	
	if (!has_guide):
		vr.log_info("Creating new crafting guide");
		#if !(_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.crafting_guide)):
		var thing = vdb.create_object_from_def(vdb.names2blockORitem_def.crafting_guide);
		parent_world.add_child(thing);
		the_guide_in_world = thing;
	
	# the the guide position close to the player
	if (the_guide_in_world):
		the_guide_in_world.global_transform.origin = vr.vrCamera.global_transform.origin;
		the_guide_in_world.global_transform.origin.y -= 0.5;
		the_guide_in_world.global_transform.origin.z -= 0.9;


func _apply_gameplay_settings():
	vr.log_info("_apply_gameplay_settings() called");
	if (locomotion_stick):
		locomotion_stick.turn_type = vdb.gameplay_settings.stick_locomotion_turn_mode;
		locomotion_stick.click_turn_angle = vdb.gameplay_settings.stick_locomotion_click_turn_angle;
		locomotion_stick.smooth_turn_speed = vdb.gameplay_settings.stick_locomotion_smooth_turn_speed;
	else:
		vr.log_warning("in _apply_gameplay_settings(): no locomotion_stick")
	
	# check if the height offset changed and then trigger also force_move up
	if (feature_falling && feature_falling.height_offset != vdb.gameplay_settings.player_height_offset):
		feature_falling.height_offset = vdb.gameplay_settings.player_height_offset;
		_time_since_climbing = 0.0; # this forces to trigger force_move_up when the gameplay settings changed (which is required for the height adjustment)
	
	vr.set_dominant_controller_left(vdb.gameplay_settings.left_handed);

	# Here we check if MRC should be enabled and add/remove the node
	var mrc_node = $OQ_ARVROrigin.find_node("Feature_MixedRealityCapture", false, false);
	
	if (vdb.gameplay_settings.enable_mixed_reality_capture):
		if (mrc_node == null):
			$OQ_ARVROrigin.add_child(load("res://OQ_Toolkit/OQ_ARVROrigin/Feature_MixedRealityCapture.tscn").instance())
			vr.log_info("Added Mixed Reality Capture Node")
	else:
		if (mrc_node != null):
			mrc_node.get_parent().remove_child(mrc_node);
			mrc_node.queue_free();
			vr.log_info("Removed Mixed Reality Capture Node")

func gameplay_settings_changed_notification():
	vr.log_info("VoxelGame: gameplay_settings_changed_notification()");
	
	_apply_gameplay_settings();
	
	
#func spawn_npc():
#	var npc = load("res://actors/Ghost.tscn").instance();
#
#	$NPCs.add_child(npc);
#
#	npc.global_transform.origin = vr.vrCamera.global_transform.origin + Vector3(2, 1, 2);
#


# not needed? as we are now a global static object as a player
#func _exit_tree():
#	vdb.remove_gamplay_settings_change_listener(self);


# This function needs to be called when the player starts the game
# it is responsible to setup everything; If the player changes the savegame
# the whole VoxelGame needs to be deleted and restarted
func initialize_voxel_world_player():
	vr.log_info("VoxelWorldPlayer.initialize_voxel_world_player()");
	
	_player_inventory = $Inventory;
	_player_toolbelt = $Toolbelt;

	persisted_nodes_array.append(self);
	persisted_nodes_array.append(_player_inventory);
	persisted_nodes_array.append(_player_toolbelt);

	vdb.add_gamplay_settings_change_listener(self);


func set_player_parent_world(_parent):
	if (vdb.voxel_world_player != self):
		vr.log_error("vdb.voxel_world_player is not active player! this is BAD!");
		return;
		
	if (get_parent() != null): get_parent().remove_child(self);
	
	parent_world = _parent;

	parent_container_build_voxel = _parent.find_node("Container_BuildVoxel");
	parent_container_destroy_voxel = _parent.find_node("Container_DestroyVoxel");
	parent_container_crafting_grids = _parent.find_node("Container_CraftingGrids");
	parent_container_crates = _parent.find_node("Container_Crates");
	
	if (parent_container_build_voxel == null):
		vr.log_error("VoxelWorldPlayer: no parent_container_build_voxel!");
	if (parent_container_destroy_voxel == null):
		vr.log_error("VoxelWorldPlayer: no parent_container_destroy_voxel!");
	if (parent_container_crafting_grids == null):
		vr.log_error("VoxelWorldPlayer: no parent_container_crafting_grids!");
	if (parent_container_crates == null):
		vr.log_error("VoxelWorldPlayer: no parent_container_crates!");
	
# this function is called by the Feature_StaticGrab on grab
# it was introduced to allow climbing on transparent objects that do not have
# a collision box created
func oq_additional_static_grab_check(grab_area, controller):
	var id = get_voxel_id_from_pos(controller.global_transform.origin);
	
	# for now every non-air voxel is grabbable
	if (id > 0): return terrain;

	return null;


const _standard_text = """
This is an early prototype. Things are unfinished and things 
will change in future updates. If you have questions or 
feedback join the  Voxel Works Discord (link is on the 
SideQuest page).

- Crafting works on tree trunks (and later crafting tables)
- There is a crafting guide nearby
- Only specific tools can mine some blocks
- To open your inventory rotate your palm up
- There is a settings menu on your arm
- The game saves automatically when you quit
""";

var _tutorial_standard = """
Welcome to %s %s standard mode %s

Controls:
	- move: left stick (or jog in place)
	- rotoate: right stick
	- mine: press A/X button when touching a block (or swing)
	- build: grab a block and press A/X on an empty place (or swing)
	- climb: grab button on blocks
""" % [vdb.GAME_NAME, vdb.GAME_VERSION_STRING, _standard_text]

var _tutorial_sportive = """
Welcome to %s %s sportive mode %s

Controls:
	- move: jog in place (lift you knees while jogging)
	- mine: swing your hand at a block
	- build: grab a block and swing on an empty place
	- climb: grab button on blocks
""" % [vdb.GAME_NAME, vdb.GAME_VERSION_STRING, _standard_text]

var _tutorial_creative = """
Welcome to %s %s creative mode %s

Controls:
  - A+B: Activate Edit/Fly Mode
  - A/B: Fly Up/Down
  - Grab Button: block selection menu
  - Right Index Trigger: build block
  - Left Index Trigger:  delete block
""" % [vdb.GAME_NAME, vdb.GAME_VERSION_STRING, _standard_text]

func show_startup_tutorial():
	var text = "";
	var title = "";
	
	if (vdb.game_mode == vdb.GAME_MODE.STANDARD):
		title = "Standard Mode";
		text = _tutorial_standard;
	if (vdb.game_mode == vdb.GAME_MODE.SPORTIVE):
		title = "Sportive Mode";
		text = _tutorial_sportive;
	if (vdb.game_mode == vdb.GAME_MODE.CREATIVE):
		title = "Creative Mode";
		text = _tutorial_creative;

	vr.show_notification(title, text)


func move_player_into_terrain_after_load(_terrain):
	terrain = _terrain;
	
	_apply_gameplay_settings();
	
	_creative_is_flying = false;
	$CreativeModeStuff.visible = false;
	
	_ingame_menu.visible = false;
	
	$OQ_ARVROrigin/OQ_LeftController/Feature_StaticGrab._additional_grab_checker = self
	$OQ_ARVROrigin/OQ_RightController/Feature_StaticGrab._additional_grab_checker = self
	
	terrain.viewer_path = $OQ_ARVROrigin/OQ_ARVRCamera.get_path();
	_terrain_tool = terrain.get_voxel_tool();
	
	# even more hacky now; but we only want a crafting guide in the main
	# world
	if (parent_world.save_enabled): hack_check_and_give_craft_guide();
	
	show_startup_tutorial();
	
#	for i in range(0, 32):
#		_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.toilet_paper);

#	_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.wood);
	#_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.stick);
	#_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.stonepick);
	#_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.stonehammer);
#	_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.stone_workbench);
	#_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.wooden_crate);
	#_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.stonepick);
	#_player_inventory.add_item_or_block_to_inventory(vdb.names2blockORitem_def.gold_lump);
	

	$OQ_ARVROrigin/Locomotion_WalkInPlace.move_checker = self;
	$OQ_ARVROrigin/Feature_Falling.move_checker = self;
	if ($OQ_ARVROrigin/Locomotion_Stick):
		$OQ_ARVROrigin/Locomotion_Stick.move_checker = self;
