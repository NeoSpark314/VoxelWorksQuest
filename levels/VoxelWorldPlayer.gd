extends Node

var _terrain_tool = null;
var terrain = null;
var parent_world = null;

onready var walk_in_place = $OQ_ARVROrigin/Locomotion_WalkInPlace;
onready var locomotion_stick = $OQ_ARVROrigin/Locomotion_Stick;

onready var feature_falling = $OQ_ARVROrigin/Feature_Falling;
onready var featur_climbing = $OQ_ARVROrigin/Feature_Climbing;

var auto_put_in_inventory = true;
var _player_inventory = null;
var _player_toolbelt = null;

var parent_container_build_voxel = null;
var parent_container_destroy_voxel = null;
var parent_container_crafting_grids = null;
var parent_container_crates = null;



var _global_dt := 0.0;

var _destroy_voxel_node = preload("res://dynamic_objects/WorldInteraction_DestroyVoxel.tscn");
var _build_voxel_node = preload("res://dynamic_objects/WorldInteraction_BuildVoxel.tscn");

var _player_foot_position := Vector3(0, 0, 0);
var _player_voxeldef_below_foot = null;
var _player_voxeldef_above_foot = null;


func remove_voxel(pos):
	_terrain_tool.channel = 0; #VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.value = 1;
	_terrain_tool.mode = VoxelTool.MODE_REMOVE;
	_terrain_tool.do_point(pos);
	terrain.stream.persistence_change_voxel(pos, 0)

func add_voxel(pos, type):
	_terrain_tool.channel = 0; #VoxelBuffer.CHANNEL_TYPE
	_terrain_tool.value = type;
	_terrain_tool.mode = VoxelTool.MODE_ADD;
	_terrain_tool.do_point(pos);
	terrain.stream.persistence_change_voxel(pos, type)

# check surrounding voxel if sth. can be build there
func can_build_at_pos(voxel_pos):
	for x in range(-1, 2, 2):
		if (_terrain_tool.get_voxel(voxel_pos + Vector3(x, 0, 0)) != 0): return true;
	for y in range(-1, 2, 2):
		if (_terrain_tool.get_voxel(voxel_pos + Vector3(0, y, 0)) != 0): return true;
	for z in range(-1, 2, 2):
		if (_terrain_tool.get_voxel(voxel_pos + Vector3(0, 0, z)) != 0): return true;
	return false;
	
func _add_build_voxel(voxel_id, voxel_position, hit_position, held_obj, controller, is_physical):
	#var voxel_def = vdb.voxel_def[1];
	if (held_obj == null): return false; # can't build out of nothing
	
	var block_def = held_obj.get_voxel_def();
	if (block_def == null): return false;
	
	var build_node = null;
	# search if we already have a node at the target position
	for n in parent_container_build_voxel.get_children():
		if (n.translation == voxel_position):
			build_node = n;
			break;
	
	# spawn a new build node if we did not finde one above
	if (build_node == null):
		if (!can_build_at_pos(voxel_position)): return false;
		build_node = _build_voxel_node.instance();
		build_node.initialize(voxel_position, hit_position, block_def);
		parent_container_build_voxel.add_child(build_node);
	
	# increment until it returns true
	if (build_node.increment_build()):
		var obj_grabber = controller.find_node("ObjectGrabber"); #!!TOOPT
		obj_grabber.delete_held_object();
		add_voxel(hit_position, block_def.id);
		if (is_physical): vdb.global_statistics.build_blocks += 1;
		
	return true;
	
# here I would like to perform additional checks to perform game logic
# that needs to happen when a voxel is removed
func check_and_remove_voxel(voxel_def, voxel_position):
	remove_voxel(voxel_position); 
	
	var above_position = voxel_position + Vector3(0, 1, 0);
	var voxel_def_above = get_voxel_def_from_pos(above_position);
	
	# for now we check via geometry_type; but this
	if (voxel_def_above.geometry_type == vdb.GEOMETRY_TYPE.Plant):
		remove_voxel(above_position); 
	
	
func find_crate_for_pos(pos):
	pos = pos.floor();
	for c in parent_container_crates.get_children():
		if (c.global_transform.origin == pos):
			return c;
	return null;

	
func compute_mining_results(voxel_def, held_obj):
	var ret = [];
	
	var can_mine = false;
	
	
	
	# now check if we can actually collect it:
	var tool_groups = [vdb.BYHAND];
	
	var item_name = "hand";
	
	if (held_obj): 
		var item_def = held_obj.get_item_def();
		item_name = item_def.name;
		tool_groups = item_def.can_mine_groups;
		
		if (!tool_groups): return ret;
	
	for mg in voxel_def.mine_groups:
		for tg in tool_groups:
			if (tg == mg): can_mine = true;

	if (can_mine): 
		if voxel_def.mine_results != null:
			for mr in voxel_def.mine_results:
				ret.append(vdb.get_def_from_name(mr));
		else: # we just mine the actual block
			ret.append(voxel_def);
				
		# check if we have special results for special mine items
		if ("special_mine_items" in voxel_def && vdb.is_in_array(voxel_def.special_mine_items, item_name)):
			for mr in voxel_def.special_mine_results:
				ret.append(vdb.get_def_from_name(mr));
		
	
	return ret;

# this is a basic way to add voxel destroyer logic with visualization
func _add_attack_voxel(voxel_id, voxel_position, hit_position, held_obj, controller, is_physical):
	if (!terrain.stream.world_check_can_mine(voxel_id)): return false;
	

	# check that a crate is empty for mining it
	if (voxel_id == vdb.voxel_types.wooden_crate):
		var c = find_crate_for_pos(hit_position);
		if (c != null && c._item_counter > 0): return false;

	var voxel_def = vdb.voxel_def[voxel_id];
	
	if (!voxel_def.can_mine): return false;
	if (voxel_def.mine_groups == null): return false;
	
	

	
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
	
	var damage =   max(dig_damage - voxel_def.dig_resistance, 0) \
				 + max(hack_damage - voxel_def.hack_resistance, 0) \
				 + max(chop_damage - voxel_def.chop_resistance, 0);

	if (damage <= 0): 
		vdb._play_sfx(vdb.sfx_cant_mine, hit_position);
		return true; # we still return true as we attacked it;
		
	if (!is_physical): damage *= 0.5;
	
	var destroy_node = null;
	# search if we already have a node at the target position
	for n in parent_container_destroy_voxel.get_children():
		if (n.translation == voxel_position):
			destroy_node = n;
			break;
	
	
	if (destroy_node == null):
		destroy_node = _destroy_voxel_node.instance();
		destroy_node.initialize(voxel_position, hit_position, voxel_def);
		parent_container_destroy_voxel.add_child(destroy_node);
		
	
	# apply the actual damage now to the node; and check if it returns true
	# which means the targeted voxel should be destroyed
	if (destroy_node.increment_destroy(damage)):
		check_and_remove_voxel(voxel_def, voxel_position);
		if (is_physical): vdb.global_statistics.mined_blocks += 1;
		
		
		
		var mining_results = compute_mining_results(voxel_def, held_obj);
		
		if (mining_results):
			for def in mining_results:
				if (!auto_put_in_inventory || !_player_inventory.add_item_or_block_to_inventory(def)):
					var thing = vdb.create_object_from_def(def);
					parent_world.add_child(thing);
					thing.global_transform.origin = hit_position;
			
	return true;


func _is_a_crafting_voxel(vid):
	if (vid == vdb.voxel_types.tree): return true;
	if (vid == vdb.voxel_types.aspen_tree): return true;
	if (vid == vdb.voxel_types.pine_tree): return true;
	if (vid == vdb.voxel_types.jungle_tree): return true;
	
	if (vid == vdb.voxel_types.wood_workbench): return true;
	if (vid == vdb.voxel_types.stone_workbench): return true;
	if (vid == vdb.voxel_types.furnace): return true;
	if (vid == vdb.voxel_types.anvil): return true;
	
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
		#print(vdb.voxel_types.tree);
		# We can craft on top of tree trunks for now
		if (_is_a_crafting_voxel(vid_below)):
			var cg : Spatial = load("res://dynamic_objects/CraftingGrid.tscn").instance();
			cg.initialize_crafting_grid(vid_below);
			parent_container_crafting_grids.add_child(cg);
			cg.global_transform.origin = pos.floor();
			cg.check_craft_place(held_object);
			
			
func _check_and_put_in_container(held_object):
	var pos = held_object.global_transform.origin.floor();
	var vid = get_voxel_id_from_pos(pos);
	
	if (vid == vdb.voxel_types.wooden_crate):
		var crate = find_crate_for_pos(pos);
		#hmm; slow... we should add a method to get actually world objects

		if (crate == null):
			crate = load("res://dynamic_objects/Container_Crate.tscn").instance();
			crate.global_transform.origin = pos;
			parent_container_crates.add_child(crate);
			
		if (crate.check_and_put_in_crate(held_object)):
			held_object.visible = false;
			held_object.queue_free();
			vr.log_info("Put something in the crate!")
			return true;
		else:
			var dir = vr.vrCamera.global_transform.origin - held_object.global_transform.origin;
			held_object.global_transform.origin += dir * 0.5;
	
	return false;

# for now we assume that all grabbable objects are an area. This might fail in the future
# and then needs some rethinking/factoring
func _on_ObjectGrabber_grab_released_held_object(held_object : Spatial):
	if (held_object == null): return;
	
	if _player_toolbelt.check_and_put_in_toolbelt(held_object):
		return;

	if _player_inventory.check_and_put_in_inventory(held_object):
		held_object.visible = false;
		held_object.queue_free();
		return;
		
	if (_check_and_put_in_container(held_object)):
		return;
		
	_check_and_start_crafting(held_object);


func get_voxel_id_from_pos(pos):
	var voxel_pos = pos.floor();
	var voxel_id = _terrain_tool.get_voxel(voxel_pos);
	return voxel_id;


func get_voxel_def_from_pos(pos):
	var voxel_id = get_voxel_id_from_pos(pos);
	return vdb.voxel_def[voxel_id];


func debug_axis(global_pos):
	var axis = load("res://static_objects/Debug_Axis.tscn").instance();
	parent_world.add_child(axis);
	axis.global_transform.origin = global_pos;


func get_held_object(controller):
	var obj_grabber = controller.find_node("ObjectGrabber"); #!!TOOPT
	if (obj_grabber):
		return obj_grabber.held_object;
	else:
		return null;
	

func get_interaction_points(controller):
	var obj = get_held_object(controller);
	var ret = []; #!!TOOPT: do we need to optimize this??
	if (obj != null):
		var hpc : Spatial = obj.get_hit_point_collection_node();
		if (hpc.get_child_count() == 0): vr.log_warning("No interaction point on item defined");
		else:
			for c in hpc.get_children():
				ret.append(c.global_transform.origin);
	ret.append(controller.get_palm_transform().origin);
	return ret;
	



# this function uses (and resets) hit_start_point
func check_attack_voxel(pos: Vector3, _speed, controller, is_physical):
	var held_obj = get_held_object(controller);

	# check if we are hitting a crafting area
	for cg in parent_container_crafting_grids.get_children():
		if (cg.perform_craft(pos, controller, held_obj, is_physical)): 
			return true;

	var voxel_pos = pos.floor();
	var voxel_id = _terrain_tool.get_voxel(voxel_pos);
	
	#if (voxel_id == 0): # air
	if (_voxel_id_valid_for_head(voxel_id)):
		# TODO: we need to check if we can build here
		if (_add_build_voxel(voxel_id, voxel_pos, pos, held_obj, controller, is_physical)):
			return true;
	
	if (voxel_id != 0): # air
		return _add_attack_voxel(voxel_id, voxel_pos, pos, held_obj, controller, is_physical);
	
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

func _controller_hit_move_detection(controller):
	
	if (controller.is_hand):
		_hit_min_speed = 1.0;
		_hit_min_dist = _hit_min_dist_default - 0.07;
	else:
		_hit_min_speed = _hit_min_speed_default;
		_hit_min_dist = _hit_min_dist_default;
		
	
	_time_since_last_attack_voxel += _global_dt;
	if (_time_since_last_attack_voxel < _min_time_between_attack): return;
	
	#var controller_position = get_interaction_point(controller);
	var interaciton_points = get_interaction_points(controller);
	
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
			if (check_attack_voxel(point, null, controller, false)):
				_time_since_last_attack_voxel = 0.0;
			return;
			
		if (vdb.casual_mode && controller._button_pressed(vr.CONTROLLER_BUTTON.XA)):
			if (check_attack_voxel(point, null, controller, false)):
				_time_since_last_attack_voxel = 0.0;
			return;
		
		if (_hit_traveld_distance[controller.controller_id]  > _hit_min_dist):
			if (check_attack_voxel(point, controller_speed, controller, true)):
				_hit_traveld_distance[controller.controller_id] = 0.0;
				_time_since_last_attack_voxel = 0.0;



func get_pointed_voxel(controller : ARVRController):
	var origin = controller.get_palm_transform().origin;
	var forward = -controller.get_palm_transform().basis.z.normalized();
	var hit = _terrain_tool.raycast(origin, forward, 10)
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
	
	var voxel_def = vdb.voxel_def[id];
	if (voxel_def.transparent): return true;

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



func _process(dt):
	_global_dt = dt;
	if (vr.switch_scene_in_progress): return;
	
	vdb.global_statistics.total_playtime += dt;

	if (vr.button_just_pressed(vr.BUTTON.ENTER)):
		_save_all();
		get_parent().remove_child(self); # we need to remove vdb.voxel_world_player 
		vr.switch_scene("res://levels/MainMenuRoom.tscn", 0.0, 0.0);
	
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

#   temp Item creation
#	if (vr.button_just_pressed(vr.BUTTON.A)):
#		var obj = vdb.create_item_object_from_def(vdb.item_def[3]);
#		add_child(obj);
#		obj.global_transform = vr.rightController.global_transform;
			
	_controller_hit_move_detection(vr.rightController);
	_controller_hit_move_detection(vr.leftController);
	
	
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
	if (!parent_world.save_enabled): return;
	
	vdb.persistence_save_game(persisted_nodes_array);
	vdb.save_global_statistics();
	vdb.save_gameplay_settings();


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
		print(n.def_name)
		var def = vdb.get_def_from_name(n.def_name);
		
		if (def == null):
			vr.log_error("Could not load def " + n.def_name);
			continue;
		
		#: filter out _voxel_def objects; this was a change in 0.3.2 to not store
		#  floating blocks!!!
		if (not vdb.is_item_def(def)): continue;
		
		var obj = vdb.create_object_from_def(def);
		if (obj):
			print("Created: " + obj.name)
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
		#if !(_player_inventory.add_item_or_block_to_inventory(vdb.name_to_def.crafting_guide)):
		var thing = vdb.create_object_from_def(vdb.name_to_def.crafting_guide);
		parent_world.add_child(thing);
		the_guide_in_world = thing;
	
	# the the guide position close to the player
	if (the_guide_in_world):
		the_guide_in_world.global_transform.origin = vr.vrCamera.global_transform.origin;
		the_guide_in_world.global_transform.origin.y -= 0.5;
		the_guide_in_world.global_transform.origin.z -= 1.0;


func _apply_gameplay_settings():
	locomotion_stick.turn_type = vdb.gameplay_settings.stick_locomotion_turn_mode;
	locomotion_stick.click_turn_angle = vdb.gameplay_settings.stick_locomotion_click_turn_angle;
	locomotion_stick.smooth_turn_speed = vdb.gameplay_settings.stick_locomotion_smooth_turn_speed;


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
	parent_world.add_child(vdb.voxel_world_player);

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
	

func move_player_into_terrain_after_load(_terrain):
	terrain = _terrain;
	
	_apply_gameplay_settings();
	
	# this registers all the objects that will be saved in the save file
	
	if (vdb.casual_mode):
		$OQ_ARVROrigin/Locomotion_Stick.active = true;
	else:
		$OQ_ARVROrigin/Locomotion_Stick.active = false;
	
	terrain.viewer_path = $OQ_ARVROrigin/OQ_ARVRCamera.get_path();
	_terrain_tool = terrain.get_voxel_tool();
	
	# even more hacky now; but we only want a crafting guide in the main
	# world
	if (parent_world.save_enabled): hack_check_and_give_craft_guide();
	
	
	#_player_inventory.add_item_or_block_to_inventory(vdb.name_to_def.wooden_crate);
	#_player_inventory.add_item_or_block_to_inventory(vdb.name_to_def.wooden_crate);
	#_player_inventory.add_item_or_block_to_inventory(vdb.name_to_def.stonepick);
	#_player_inventory.add_item_or_block_to_inventory(vdb.name_to_def.gold_lump);
	

	$OQ_ARVROrigin/Locomotion_WalkInPlace.move_checker = self;
	$OQ_ARVROrigin/Feature_Falling.move_checker = self;
	if ($OQ_ARVROrigin/Locomotion_Stick):
		$OQ_ARVROrigin/Locomotion_Stick.move_checker = self;
