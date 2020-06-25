extends Spatial

const grid_size = 3;

onready var area : Area = $Area;

var locked = false;

var _time_until_reset = 2.0;
var _reset_counter = 0.0;

var _num_build_steps = 4.0;
var _build_step = 0.0;

var crafting_grid_voxel_def = null; # this is the voxel def that spawned this table

# a furnace with fuel would be auto-craft
var is_furnace = false;
var furnace_burn_timer = 0.0;
var furnace_max_burn_time = 1.0;

onready var grid_node_container = $GridNodes;
onready var indicator_valid = $CraftIndicator/CraftIndicatorValid;
onready var indicator_invalid = $CraftIndicator/CraftIndicatorInvalid;


const COLOR_valid_recipe = Color(0,0.521569,0,0.392157);
const COLOR_invalid_recipe = Color(0.521569,0,1,0.392157);

func initialize_crafting_grid(vid):
	crafting_grid_voxel_def = vdb.voxel_block_defs[vid];
	
	if (vid == vdb.voxel_block_names2id.furnace):
		is_furnace = true;
		
	
	

# this is a helper function used at the moment for saving all crafting grid objects
# as grids do not save semselves
func get_all_objects_in_grid() -> Array:
	var ret = [];
	for i in grid_node_container.get_children():
		var c= i.get_child(0);
		if (c): ret.append(c);
	return ret;
	
	
func compute_craft_grid_def():
	var grid = [];
	grid.resize(grid_size * grid_size);
	# create the name grid
	for i in range(0, grid.size()):
		var c = grid_node_container.get_child(i).get_child(0);
		if (c): 
			grid[i] = c.get_def(); 
		else: 
			grid[i] = null;
	
	return grid;

func check_pos_in_craft_area(pos):
	var p = global_transform.origin;
	if (p.x > pos.x || p.y > pos.y || p.z > pos.z ||
		(p.x+1) < pos.x || (p.y+1) < pos.y || (p.z+1) < pos.z): return false;
	return true;
	
func can_attempt_craft(global_pos):
	if (locked):
		return false;

	if (is_furnace):
		return false;
	
	if (crafting_grid_voxel_def == null):
		vr.log_error("Invalid voxel_block_defs in CraftingGrid.gd");
		return false;
	
	# manual check here...
	if (!check_pos_in_craft_area(global_pos)):
		return false;
	return true;

func attempt_craft():
	#print("PLING");
	_reset_counter = 0.0;
	_build_step = _build_step + 1;

	var sound_position = global_transform.origin + Vector3.ONE / 2;

	if _build_step >= _num_build_steps:
		if (_is_valid_recipe):
			locked = true;
			return true;
		else:
			#vr.log_info("Unknown crafting recipie");
			vdb._play_sfx(vdb.sfx_craft_fail, sound_position);
			_build_step = 0;
	else:
		if ("sfx_craft_steps" in crafting_grid_voxel_def):
			vdb._play_sfx(crafting_grid_voxel_def.sfx_craft_steps, sound_position);
		else:
			vdb._play_sfx(vdb.sfx_craft_steps, sound_position);
	return false;


func _get_closest_grid_position(obj):
	var min_dist = 1000.0;
	var min_g = null;
	for g in grid_node_container.get_children():
		if (g.get_child_count() > 0): continue; # already occupied
		var dist = (g.global_transform.origin - obj.global_transform.origin).length();
		if (dist < min_dist):
			min_g = g;
			min_dist = dist;
	
	return min_g;
	
func _set_scale_and_position_offset(g, obj):
	obj.transform.basis = Basis();
	obj.global_transform.origin = g.global_transform.origin;
	
	for m in obj.get_children():
		if m is MeshInstance:
			# NOTE: his might be wrong; it should reposition
			#       the object to be nicely centered... might need a rework
			# it is extremly hacky... need to fix this with propper clean code
			#obj.global_transform.basis = Basis();
			#obj.global_transform.origin = Vector3(0,0,0);

			var bb = m.get_transformed_aabb();
			var s = 0.7 / (grid_size * bb.get_longest_axis_size());
			obj.transform.origin = Vector3(0,0,0);
			
			# THIS my dear friend is INCREDIBLY hacky and will fail soon
			if ("_item_def" in obj):
				obj.transform.origin = m.center_offset * 0.5 + Vector3(0, -0.25, 0);
			g.scale = Vector3(s, s, s);
				


func check_craft_place(obj : Spatial):
	if (!check_pos_in_craft_area(obj.global_transform.origin)): 
		print("not in");
		return false;
	
	print("Searching closes grid");
	var g = _get_closest_grid_position(obj);
	if (g == null): 
		print("Not found");
		return true; # do not add; but we have a valid craft place
	
	print("Closest grid is " + str(g));
	obj.get_parent().remove_child(obj);
	g.scale = Vector3(1,1,1); # reset scale to not mess with child
	g.rotation = Vector3(0,0,0); # reset scale to not mess with child
	g.add_child(obj);
	_set_scale_and_position_offset(g, obj);
	
	
	return true;
	

var _is_valid_recipe = false;


func _check_and_update_valid():
	print("checking if recipe is valid");
	# now we check if it is a valid recipe and set the propper one visible
	# NOTE: all this might at some point be really compute intensive
	var grid = compute_craft_grid_def();
	
	var recipe = vdb.check_and_get_crafting_recipe(grid, crafting_grid_voxel_def);
	
	if (recipe != null):
		_is_valid_recipe = true;
	else:
		_is_valid_recipe = false;
		
		
	indicator_valid.visible = _is_valid_recipe;
	indicator_invalid.visible = !_is_valid_recipe;
	
	if (is_furnace && _is_valid_recipe):
		$Animated_Fire.visible = true;
		furnace_burn_timer = 10.0; # default
		
		if (recipe.has("furnace_burn_time")):
			furnace_burn_timer = recipe.furnace_burn_time;
		else:
			vr.log_warning("Furnace recipe without time: " + recipe.output[0])
		
		furnace_max_burn_time = furnace_burn_timer;
	else:
		$Animated_Fire.visible = false;


# Called when the node enters the scene tree for the first time.
func _ready():
	$GridPoint.visible = false;
	$Animated_Fire.visible = false;
	
	for y in range(0, grid_size):
		for x in range(0, grid_size):
			var g = Spatial.new();
			grid_node_container.add_child(g);
			var px = (x+0.5) / float(grid_size);
			var py = (y+0.5) / float(grid_size);
			var pz = 0.5;
			g.transform.origin = Vector3(px, py, pz);
			
			var marker = $GridPoint.duplicate();
			add_child(marker);
			marker.global_transform = g.global_transform;
			marker.visible = true;

	$CraftIndicator.scale.y = 0.0;
	$CraftIndicator.translation.y = 0.0001;
	_reset_counter = _time_until_reset;
	$CraftIndicator.visible = true;

var time = 0.0;
var _no_object_timer = 0.0;

var _last_num_objects_in_grid = -1;
func _process(_dt):
	time += _dt;
	_no_object_timer += _dt;
	
	var num_objects_in_grid = 0;
	var c = 0;
	for g in grid_node_container.get_children():
		g.rotation.y = time + c;
		c = c + 1;
		
		num_objects_in_grid += g.get_child_count();
		
	if (num_objects_in_grid != _last_num_objects_in_grid):
		_check_and_update_valid();
		_last_num_objects_in_grid = num_objects_in_grid;
		
	# here we remove ourself again when no object is placed
	if (num_objects_in_grid == 0 && _no_object_timer > 2.0):
		queue_free();
	elif (num_objects_in_grid > 0):
		_no_object_timer = 0;
		
		
	if (is_furnace):
		if (_is_valid_recipe):
			$Animated_Fire.scale.y = 1.0 - (furnace_max_burn_time - furnace_burn_timer)/furnace_max_burn_time;
			if (!$Fire_Sound.playing): $Fire_Sound.play();
			furnace_burn_timer -= _dt;
			if (furnace_burn_timer <= 0.0 && !vdb.voxel_world_player.socket_client):
				core.craft_with(null, global_transform.origin, null, false);
		else:
			$Fire_Sound.stop();

	else:
		if (_reset_counter >= _time_until_reset):
			_build_step = 0.0;
			_reset_counter = _time_until_reset;
		else:
			_reset_counter += _dt;
			
	
		$CraftIndicator.scale.y = (1.0 - _reset_counter/_time_until_reset) * _build_step / (_num_build_steps);
		$CraftIndicator.translation.y = -(1.0 - $CraftIndicator.scale.y) * 0.5 + 0.5001
	



