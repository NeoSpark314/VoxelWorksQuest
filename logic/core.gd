extends Node

var server = null;
var users_by_socket_id = {};

func start_server():
	var Server = load("res://networking/SocketServer.gd");
	server = Server.new();

	server.on("connect", self, "_user_connected");
	server.on("identify", self, "_load_user");
	server.on("position_player", self, "_position_player");
	server.on("disconnect", self, "_user_disconnected");
	server.on("attempt_craft", self, "_user_attempt_craft")
	server.on("attempt_build", self, "_user_attempt_build");
	server.on("attempt_break", self, "_user_attempt_break");
	server.on("creative_build", self, "_creative_build");
	server.on("creative_destroy", self, "_creative_destroy");
	server.on("grab_item", self, "_grab_item");
	server.on("grab_from_crate", self, "_grab_from_crate");
	server.on("grab_from_inventory", self, "_grab_from_inventory");
	server.on("move_to_inventory", self, "_move_to_inventory");
	server.on("set_active_slot", self, "_set_active_slot");
	server.on("move_to_tool_slot", self, "_move_to_tool_slot");
	server.on("move_tool_to_hand", self, "_move_tool_to_hand");
	server.on("release_grab", self, "_release_grab");

	server.start()

func stop_server():
	users_by_socket_id = {};
	server.stop_server();
	server = null;

### world data transfer

func get_save_dictionary():
	var ret = {
		items_in_world = [],
		objects_in_world = [],
		crates_in_world = [],
	}
	
	# all nodes attached to the root are checked for objects and then saved
	for node in vdb.voxel_world_player.parent_world.get_children():
		if "_world_object_type" in node:
			ret.objects_in_world.append(node.get_save_dictionary());
		
		# crude way of detecting that it is an Object_Item or ObjectVoxelBlock
		if ("_item_def" in node) || ("_voxel_def" in node):
			ret.items_in_world.append(node.get_save_dictionary());
			
	# next we store all objects currently in a crafting grid to not loose them
	for craft_grid in vdb.voxel_world_player.parent_container_crafting_grids.get_children():
		for node in craft_grid.get_all_objects_in_grid():
			if ("_item_def" in node) || ("_voxel_def" in node):
				ret.items_in_world.append(node.get_save_dictionary());

	for c in vdb.voxel_world_player.parent_container_crates.get_children():
		ret.crates_in_world.append(c.get_save_dictionary());

	return ret;

func apply_save_dictionary(data : Dictionary):
	for object_data in data.objects_in_world:
		var obj = vdb.create_world_object_from_type(object_data.world_object_type);
		vdb.voxel_world_player.parent_world.add_child(obj)
		obj.apply_save_dictionary(object_data);

	for crate_data in data.crates_in_world:
		var crate = load("res://dynamic_objects/Container_Crate.tscn").instance();
		vdb.voxel_world_player.parent_container_crates.add_child(crate);
		crate.apply_save_dictionary(crate_data);

	for item_data in data.items_in_world:
		var def = vdb.get_def_from_name(item_data.def_name);
		
		if (def == null):
			vr.log_error("Could not load def " + item_data.def_name);
			continue;
		
		var obj = vdb.create_object_from_def(def);
		if (obj):
			vdb.voxel_world_player.parent_world.add_child(obj);
			obj.apply_save_dictionary(item_data);
		else:
			vr.log_error("Could not load object from " + str(item_data));

### event listeners

func _user_connected(id: int):
	# send world data to the player

	var persisted_nodes = [ self ];

	var world_data = vdb._get_save_dictionary(persisted_nodes);
	var player_data = [ vdb.voxel_world_player.gen_player_data() ];
	
	for dummy_player in vdb.voxel_world_player.user_dummy_by_uuid.values():
		dummy_player.gen_player_data();

	server.send_reliable(id, "world_data", [ world_data, player_data ]);

func _load_user(id: int, uuid: String, preferences: Dictionary):
	if vdb.voxel_world_player.user_dummy_by_uuid.has(uuid):
		server.kick(id);
		return;

	users_by_socket_id[id] = {
		socket_id = id,
		uuid = uuid,
		preferences = preferences
	};

	vdb.voxel_world_player.add_player(uuid);

	server.broadcast_reliable("add_player", [ uuid ]);

func _position_player(id: int, left_hand_transform, right_hand_transform):
	var user = users_by_socket_id[id];
	
	update_player_positions(user.uuid, left_hand_transform, right_hand_transform);

func _user_disconnected(id: int):
	var user = users_by_socket_id[id];
	users_by_socket_id.erase(id);

	vdb.voxel_world_player.remove_player(user.uuid);

	server.broadcast_reliable("remove_player", [ user.uuid ]);

	# drop inventory?

func _user_attempt_craft(id: int, voxel_pos, hand_name, is_physical):
	var user = users_by_socket_id[id];
	player_craft_with(user.uuid, voxel_pos, hand_name, is_physical);

func _user_attempt_build(id: int, voxel_pos, pos, hand_name, is_physical):
	var user = users_by_socket_id[id];
	attempt_build(user.uuid, voxel_pos, pos, hand_name, is_physical);

func _user_attempt_break(id: int, voxel_pos, hit_pos, hand_name, is_physical):
	var user = users_by_socket_id[id];
	attempt_break(user.uuid, user.preferences, voxel_pos, hit_pos, hand_name, is_physical);

func _creative_build(id: int, voxel_pos, voxel_id):
	var user = users_by_socket_id[id];
	add_voxel(user.uuid, voxel_pos, voxel_id, false);

func _creative_destroy(id: int, voxel_pos):
	var user = users_by_socket_id[id];
	remove_voxel(user.uuid, voxel_pos, false);

func _grab_item(id: int, hand_name, item_uuid):
	var user = users_by_socket_id[id];
	
	player_grab_item(user.uuid, hand_name, item_uuid);

func _grab_from_crate(id: int, hand_name, crate_position):
	var user = users_by_socket_id[id];

	player_take_from_crate(user.uuid, hand_name, crate_position);

func _grab_from_inventory(id: int, hand_name, slot):
	var user = users_by_socket_id[id];

	player_grab_from_inventory(user.uuid, hand_name, slot);

func _move_to_inventory(id: int, hand_name, slot):
	var user = users_by_socket_id[id];

	move_to_inventory(user.uuid, hand_name, slot);

func _set_active_slot(id: int, slot):
	var user = users_by_socket_id[id];

	set_player_active_slot(user.uuid, slot);

func _move_to_tool_slot(id: int, hand_name, slot):
	var user = users_by_socket_id[id];

	move_to_tool_slot(user.uuid, hand_name, slot);

func _move_tool_to_hand(id: int, slot, hand_name):
	var user = users_by_socket_id[id];

	move_tool_to_hand(user.uuid, slot, hand_name);

func _release_grab(id: int, hand_name, final_transform):
	var user = users_by_socket_id[id];

	player_release_item(user.uuid, hand_name, final_transform);

### messages

func _play_sfx(sfx, position: Vector3):
	vdb.voxel_world_player.play_sfx(sfx, position);

	if server:
		server.broadcast("play_sfx", [ sfx, position ]);

func update_player_positions(uuid, left_hand_transform, right_hand_transform):
	vdb.voxel_world_player.position_player(uuid, left_hand_transform, right_hand_transform);
	
	if server:
		server.broadcast("position_player", [ uuid, left_hand_transform, right_hand_transform ]);

func _send_crafting_status(uuid, voxel_pos, success, is_physical):
	vdb.voxel_world_player.crafting_status(uuid, voxel_pos, success, is_physical);

	if server:
		server.broadcast_reliable("crafting_status", [ uuid, voxel_pos, success, is_physical ]);

func _increment_build(voxel_position, hit_position, voxel_id):
	var completed = vdb.voxel_world_player.increment_build(voxel_position, hit_position, voxel_id);

	if server:
		server.broadcast_reliable("increment_build", [ voxel_position, hit_position, voxel_id ]);
	
	return completed

func add_voxel(uuid, pos, voxel_id, is_physical):
	vdb.voxel_world_player.add_voxel(uuid, pos, voxel_id, is_physical);

	if server:
		server.broadcast_reliable("add_voxel", [ uuid, pos, voxel_id, is_physical ]);

func _increment_destroy(voxel_position, hit_position, voxel_id, damage):
	var completed = vdb.voxel_world_player.increment_destroy(voxel_position, hit_position, voxel_id, damage);

	if server:
		server.broadcast_reliable("increment_destroy", [ voxel_position, hit_position, voxel_id, damage ]);
	
	return completed

func remove_voxel(uuid, pos, is_physical):
	vdb.voxel_world_player.remove_voxel(uuid, pos, is_physical);

	if server:
		server.broadcast_reliable("remove_voxel", [ uuid, pos, is_physical ]);

func _spawn_item(position, item_uuid, item_name):
	vdb.voxel_world_player.spawn_item(position, item_uuid, item_name);

	if server:
		server.broadcast_reliable("spawn_item", [ position, item_uuid, item_name ]);

func _delete_held_object(uuid, hand_name):
	vdb.voxel_world_player.delete_player_held_object(uuid, hand_name);

	if server:
		server.broadcast_reliable("delete_player_held_object", [ uuid, hand_name ]);

func _give_item(uuid, item_name):
	var had_room = vdb.voxel_world_player.give_player_item(uuid, item_name);

	if !had_room:
		return false;
		
	if server:
		server.broadcast_reliable("give_player_item", [ uuid, item_name ]);
	
	return true;

func player_grab_item(uuid, hand_name, item_uuid):
	vdb.voxel_world_player.player_grab_item(uuid, hand_name, item_uuid);

	if server:
		server.broadcast_reliable("player_grab_item", [ uuid, hand_name, item_uuid ]);

func player_take_from_crate(uuid, hand_name, crate_position):
	var item_uuid = vdb.gen_uuid();

	vdb.voxel_world_player.player_take_from_crate(uuid, hand_name, crate_position, item_uuid);

	if server:
		server.broadcast_reliable("take_from_crate", [ uuid, hand_name, crate_position, item_uuid ]);

func player_grab_from_inventory(uuid, hand_name, slot):
	var item_uuid = vdb.gen_uuid();

	vdb.voxel_world_player.grab_from_inventory(uuid, hand_name, slot, item_uuid);

	if server:
		server.broadcast_reliable("grab_from_inventory", [ uuid, hand_name, slot, item_uuid ]);

func move_to_inventory(uuid, hand_name, slot):
	vdb.voxel_world_player.move_to_inventory(uuid, hand_name, slot);
	
	if server:
		server.broadcast_reliable("move_to_inventory", [ uuid, hand_name, slot ]);

func set_player_active_slot(uuid, slot):
	vdb.voxel_world_player.player_set_active_slot(uuid, slot);

	if server:
		server.broadcast_reliable("set_active_slot", [ uuid, slot ]);

func move_to_tool_slot(uuid, hand_name, slot):
	vdb.voxel_world_player.player_hand_to_tool(uuid, hand_name, slot);

	if server:
		server.broadcast_reliable("move_to_tool_slot", [ uuid, hand_name, slot ]);

func move_tool_to_hand(uuid, slot, hand_name):
	vdb.voxel_world_player.player_tool_to_hand(uuid, slot, hand_name);

	if server:
		server.broadcast_reliable("move_tool_to_hand", [ uuid, slot, hand_name ]);

func player_release_item(uuid, hand_name, final_transform):
	vdb.voxel_world_player.player_release_item(uuid, hand_name, final_transform);

	if server:
		server.broadcast_reliable("player_release_item", [ uuid, hand_name, final_transform ]);

### helpers

func get_player(uuid):
	if uuid == vdb.voxel_world_player.uuid:
		return vdb.voxel_world_player;
	else:
		return vdb.voxel_world_player.user_dummy_by_uuid[uuid];

func _get_held_object(uuid, hand_name):
	return get_player(uuid).get_held_object(hand_name);

func _get_item_name_from_held_obj(held_obj):
	if (!held_obj):
		return "hand";

	var item_def = held_obj.get_item_def();

	if (!item_def):
		return "hand";

	return item_def.name;

func _get_toolgroups_from_held_obj(held_obj):
	if (!held_obj):
		return [vdb.BYHAND];
	
	var item_def = held_obj.get_item_def();
	
	if (!item_def):
		return [vdb.BYHAND];

	return item_def.can_mine_groups;

func get_voxel_id_from_pos(pos):
	var voxel_pos = pos.floor();
	var voxel_id = vdb.voxel_world_player._terrain_tool.get_voxel(voxel_pos);
	return voxel_id;

func get_voxel_def_from_pos(pos):
	var voxel_id = get_voxel_id_from_pos(pos);
	return vdb.voxel_block_defs[voxel_id];

func can_break(voxel_pos, held_obj):
	var voxel_id = vdb.voxel_world_player._terrain_tool.get_voxel(voxel_pos)
	var voxel_block_def = vdb.voxel_block_defs[voxel_id];

	if voxel_id == 0:
		return false;
	
	# make sure the world allows you to break this
	if (!vdb.voxel_world_player.terrain.stream.world_check_can_mine(voxel_id)):
		return false;

	# check that a crate is empty for mining it
	if (voxel_id == vdb.voxel_block_names2id.wooden_crate):
		var c = find_crate_for_voxel_pos(voxel_pos);
		if (c != null && c._item_counter > 0): return false;

	if (!voxel_block_def.can_mine): return false;
	if (voxel_block_def.mine_groups == null): return false;

	var tool_groups = _get_toolgroups_from_held_obj(held_obj);
	
	if !voxel_block_def.breakable_by_tool_groups:
		return true;
	
	for mg in voxel_block_def.breakable_by_tool_groups:
		for tg in tool_groups:
			if (tg == mg):
				return true;
	return false

func can_mine(voxel_block_def, held_obj):
	var tool_groups = _get_toolgroups_from_held_obj(held_obj);

	if (!tool_groups):
		return false;
	
	for mg in voxel_block_def.mine_groups:
		for tg in tool_groups:
			if (tg == mg):
				return true;
	return false;

# check surrounding voxel if sth. can be build there
func can_build_at_pos(voxel_pos):

	var voxel_at_pos = vdb.voxel_world_player._terrain_tool.get_voxel(voxel_pos);
	if !_voxel_replacable(voxel_at_pos):
		# cant place a voxel here
		return false;

	var testOffsets = [
		Vector3(-1,  0,  0),
		Vector3( 1,  0,  0),
		Vector3( 0, -1,  0),
		Vector3( 0,  1,  0),
		Vector3( 0,  0, -1),
		Vector3( 0,  0,  1)
	];

	# search for a non air block to place against
	for offset in testOffsets:
		if vdb.voxel_world_player._terrain_tool.get_voxel(voxel_pos + offset) != 0:
			return true;
	
	return false;

func _voxel_replacable(voxel_id):
	var voxel_block_def = vdb.voxel_block_defs[voxel_id];
	if (voxel_block_def.transparent):
		return true;
	return false;

#hmm; slow... we should add a method to get actually world objects
func find_crate_for_voxel_pos(voxel_pos):
	var vid = get_voxel_id_from_pos(voxel_pos);

	if (vid != vdb.voxel_block_names2id.wooden_crate):
		return null;

	var crate;
	
	for c in vdb.voxel_world_player.parent_container_crates.get_children():
		if (c.global_transform.origin == voxel_pos):
			crate = c;

	if (crate == null):
		crate = load("res://dynamic_objects/Container_Crate.tscn").instance();
		crate.global_transform.origin = voxel_pos;
		vdb.voxel_world_player.parent_container_crates.add_child(crate);

	return crate;
	
### main logic

func player_craft_with(uuid, voxel_pos, hand_name, is_physical):
	var held_object = get_player(uuid).get_held_object(hand_name);

	craft_with(uuid, voxel_pos, held_object, is_physical);

func craft_with(uuid, voxel_pos, held_object, is_physical):
	var crafting_grid;

	for cg in vdb.voxel_world_player.parent_container_crafting_grids.get_children():
		if cg.global_transform.origin == voxel_pos:
			crafting_grid = cg;

	if !crafting_grid:
		return;
	
	var grid = crafting_grid.compute_craft_grid_def();	
	var item_names = vdb.perform_crafting(grid, crafting_grid.crafting_grid_voxel_def, held_object);
		
	if !item_names:
		_send_crafting_status(uuid, voxel_pos, false, is_physical);
		return;

	_send_crafting_status(uuid, voxel_pos, true, is_physical);

	# spawn the crafted objects along the grid
	var count = 0;
	for item_name in item_names:
		var grid_node = crafting_grid.grid_node_container.get_child(count);
		_spawn_item(grid_node.global_transform.origin, vdb.gen_uuid(), item_name);
		count = count + 1;

# this is a basic way to add voxel destroyer logic with visualization
func attempt_break(uuid, preferences, voxel_position, hit_position, hand_name, is_physical):
	var held_obj = _get_held_object(uuid, hand_name);
	
	# here we check if the voxel_block has a specific definition of what tools
	# can break it; if it is not breakable by the currently held tool we just
	# return
	if (!can_break(voxel_position, held_obj)):
		return false;

	var voxel_id = vdb.voxel_world_player._terrain_tool.get_voxel(voxel_position);
	var voxel_block_def = vdb.voxel_block_defs[voxel_id];
	
	# here we will need to compute the damage based on the tool used
	var dig_damage = 1;
	var hack_damage = 0;
	var chop_damage = 1;
	
	var item_def = null;
	if (held_obj != null): item_def = held_obj.get_item_def(); # returns null if it is not an item
	
	if (item_def != null):
		dig_damage = item_def.dig_damage;
		hack_damage = item_def.hack_damage;
		chop_damage = item_def.chop_damage;
	
	var damage =   max(dig_damage - voxel_block_def.dig_resistance, 0) \
				 + max(hack_damage - voxel_block_def.hack_resistance, 0) \
				 + max(chop_damage - voxel_block_def.chop_resistance, 0);
	
	if (damage <= 0): 
		_play_sfx(vdb.sfx_cant_mine, hit_position);
		return true; # we still return true as we attacked it;
	
	if (!is_physical): damage *= 0.5;
	
	# apply the actual damage now to the node; and check if it returns true
	# which means the targeted voxel should be destroyed
	if (_increment_destroy(voxel_position, hit_position, voxel_id, damage)):
		_check_and_remove_voxel(uuid, voxel_position, is_physical);
		
		var mining_results = _compute_mining_results(voxel_block_def, held_obj);
		
		for def in mining_results:
			if (!preferences.auto_put_in_inventory || !_give_item(uuid, def.name)):
				_spawn_item(hit_position, vdb.gen_uuid(), def.name);
	
	return true;

func _compute_mining_results(voxel_block_def, held_obj):
	var ret = [];
	
	# now check if we can actually collect it:
	if !can_mine(voxel_block_def, held_obj):
		return ret;
	
	var item_name = _get_item_name_from_held_obj(held_obj);

	if voxel_block_def.mine_results != null:
		for mr in voxel_block_def.mine_results:
			ret.append(vdb.get_def_from_name(mr));
	else: # we just mine the actual block
		ret.append(voxel_block_def);
			
	# check if we have special results for special mine items
	if ("special_mine_items" in voxel_block_def && vdb.is_in_array(voxel_block_def.special_mine_items, item_name)):
		for mr in voxel_block_def.special_mine_results:
			ret.append(vdb.get_def_from_name(mr));
	
	return ret;

# here I would like to perform additional checks to perform game logic
# that needs to happen when a voxel is removed
func _check_and_remove_voxel(uuid, voxel_position, is_physical):
	remove_voxel(uuid, voxel_position, is_physical);
	
	var above_position = voxel_position + Vector3(0, 1, 0);
	var voxel_def_above = get_voxel_def_from_pos(above_position);
	
	# for now we check via geometry_type; but this
	if (voxel_def_above.geometry_type == vdb.GEOMETRY_TYPE.Plant):
		remove_voxel(uuid, above_position, false);


func attempt_build(uuid, voxel_position, hit_position, hand_name, is_physical):
	var held_obj = _get_held_object(uuid, hand_name);

	#var voxel_block_def = vdb.voxel_block_defs[1];
	if (held_obj == null): return false; # can't build out of nothing
	
	var voxel_def = held_obj.get_voxel_def();
	if (voxel_def == null): return false;

	var voxel_id = voxel_def.id;

	# increment until it returns true
	if (_increment_build(voxel_position, hit_position, voxel_id)):
		_delete_held_object(uuid, hand_name);
		add_voxel(uuid, hit_position, voxel_id, is_physical);
	
	return true;
