extends Node

# Increment this immediately after release
const GAME_VERSION_STRING = "0.3.12";
const GAME_NAME = "Voxel Works Quest";

const VOXEL_TEXTURE_ATLAS_SIZE = 32;

#var casual_mode = true;

enum GAME_MODE {
	STANDARD,
	SPORTIVE,
	CREATIVE
}

var game_mode = GAME_MODE.STANDARD;

func get_game_mode_string():
	if (game_mode ==  GAME_MODE.STANDARD): return "standard";
	if (game_mode ==  GAME_MODE.SPORTIVE): return "sportive";
	if (game_mode ==  GAME_MODE.CREATIVE): return "creative";
	return "unknown"
	

#var current_save_file = "game.save"; # this will be the default when not launched via main menu
var current_save_file_infix = "pre0.3.6_sportive";
var world_name = null;
var world_uuid := "invalid-uuid";


var gameplay_settings := {
	stick_locomotion_turn_mode = vr.LocomotionStickTurnType.CLICK, # 0 click turning; 1 smooth turning
	stick_locomotion_click_turn_angle = 60,
	stick_locomotion_smooth_turn_speed = 90,
	stick_locomotion_speed_multiplier = 1.0,
	
	player_height_offset = 0.0,
	
	toolbelt_require_second_button = false, # an optional safety setting to avoid accidentally grabbing items from the toolbelt
	left_handed = false,
	
	enable_mixed_reality_capture = false,
	show_debug_console = false,
	custom_terrain_block_texture_item = 0, # 0 is default
	
	online_username = "VoxelWorksPlayer",
	online_useremail = "",
	online_password = "",
	
	last_remote_host = "192.168.100.58",
}


var startup_settings = {}


func reset_startup_settings():
	startup_settings = {
		host = false, # whether or not to start a server
		remote_host = null, # ip string
		load_game = true,
		save_enabled = true,
		save_file_infix = "noname",
		world_dict = null, # if this is != null the world will be loaded from this dicitonary
		generator_seed = 0,
		generator_name = "V1", 
		world_name = "World Without Name",
		world_uuid = gen_uuid(),
		#casual_mode = false,
		game_mode = GAME_MODE.STANDARD,
		reset_start_position = false,
		reset_crafting_guide = false,
	};


var _gameplay_settings_change_listener = [];

func add_gamplay_settings_change_listener(listener):
	for l in _gameplay_settings_change_listener:
		if l == listener: return;
	_gameplay_settings_change_listener.append(listener);

func remove_gamplay_settings_change_listener(listener):
	_gameplay_settings_change_listener.erase(listener);


func notify_gameplay_settings_changed():
	for l in _gameplay_settings_change_listener:
		l.gameplay_settings_changed_notification();


# NOTE: this needs to be all floats as it is directly stored/loaded
#       from json
var global_statistics := {
	traveled_distance = 0.0,
	steps_taken = 0.0,
	mined_blocks = 0.0,
	build_blocks = 0.0,
	crafted_items = 0.0,
	total_playtime = 0.0,
}

# this dictionary will be acopy of the global statistics
# at session start; it allows to derive the statistics
# for the current sessions
var session_start_statistics := {
}


func get_global_statistics_copy():
	var ret = {};
	for k in global_statistics.keys():
		ret[k] = global_statistics[k];
	return ret;


enum GEOMETRY_TYPE {
	None,
	Cube,
	Plant,
	Custom,
}

const sfx_put_in_inventory = "default_snow_footstep.1";
const sfx_no_space_in_inventory = "default_dig_dig_immediate";
const sfx_cant_mine = "default_place_node_metal.2";


#const sfx_snow_footstep = 
const sfx_dirt_footstep = ["default_dirt_footstep.1", "default_dirt_footstep.2"];
const sfx_grass_footstep = ["default_grass_footstep.1", "default_grass_footstep.2", "default_grass_footstep.3"];
const sfx_sand_footstep = ["default_sand_footstep.1", "default_sand_footstep.2"];
const sfx_wood_footstep = ["default_wood_footstep.1", "default_wood_footstep.2"];
const sfx_hard_footstep = ["default_hard_footstep.1", "default_hard_footstep.2", "default_hard_footstep.3"];
const sfx_snow_footstep = ["default_snow_footstep.1", "default_snow_footstep.2", "default_snow_footstep.3", "default_snow_footstep.4", "default_snow_footstep.5"];
const sfx_metal_footstep = ["default_metal_footstep.1", "default_metal_footstep.2", "default_metal_footstep.3"];
const sfx_gravel_footstep = ["default_gravel_footstep.1", "default_gravel_footstep.2", "default_gravel_footstep.3", "default_gravel_footstep.4"]

const sfx_dig_crumbly = "default_dig_crumbly";

const sfx_craft_steps = sfx_wood_footstep;
const sfx_craft_fail = "default_break_glass.1"
const sfx_craft_success = "default_dig_snappy"
const sfx_break_glass = ["default_break_glass.1", "default_break_glass.2", "default_break_glass.3"];
const sfx_place_node = ["default_place_node.1", "default_place_node.2", "default_place_node.3"];


var _sfx_defaults = {
	standard = {
		dig = sfx_dig_crumbly,
		dug = "default_dirt_footstep.2",
		footstep = sfx_dirt_footstep,
		place = sfx_place_node,
		build = ["default_place_node_hard.1", "default_place_node_hard.2"],
	},
	gravel = {
		dig = sfx_dig_crumbly,
		dug = "default_dirt_footstep.2",
		footstep = sfx_gravel_footstep,
	},
	crumbly = {
		dig = sfx_dig_crumbly,
		dug = "default_dirt_footstep.2",
		footstep = sfx_dirt_footstep,
	},
	grass = {
		dig = sfx_dig_crumbly,
		dug = "default_dirt_footstep.2",
		footstep = sfx_grass_footstep,
	},
	sand = {
		dig = sfx_dig_crumbly,
		dug = "default_dirt_footstep.2",
		footstep = sfx_sand_footstep, 
	},
	choppy = {
		dig = "default_dig_choppy",
		dug = "default_dirt_footstep.2",
		footstep = sfx_wood_footstep, 
	},
	cracky = {
		dig = "default_dig_cracky",
		dug = "default_dirt_footstep.2",
		footstep = sfx_hard_footstep, 
	},
	metal = {
		dig = "default_dig_cracky",  # !!TODO
		dug = "default_dirt_footstep.2",
		footstep = sfx_hard_footstep, 
	},
}


var _sfx_player_pool = [];
var _sfx_player_pool_pos = 0;
var _sfx_rng = RandomNumberGenerator.new();

func _init_sfx():
	# NOTE: if it turns out that 8 are not enough we can make it dynamic
	# by always appending a new player if all others are still playing
	for _i in range(0, 8):
		var player = AudioStreamPlayer3D.new();
		add_child(player);
		_sfx_player_pool.append(player);
		
func _play_sfx(s, position):
	var dir = "res://data/sfx/";
	if (s is Array):
		s = vr.randomArrayElement(_sfx_rng, s);
	
	var filename = dir + s + ".ogg";
	var stream = load(filename);
	if (!stream):
		vr.log_error("Could not play SFX " + filename);
		return null;
	else:
		var player : AudioStreamPlayer3D = _sfx_player_pool[_sfx_player_pool_pos];
		if (!player.playing):
			player.stream = stream;
			player.global_transform.origin = position;
			player.play();
			_sfx_player_pool_pos = (_sfx_player_pool_pos + 1) % _sfx_player_pool.size();
			return player;
		else:
			vr.log_warning("No free SFX player for " + filename);
			return null;
	

func play_sfx_dig(vd, position):
	if (!vd.sounds.has("dig")): return _play_sfx(_sfx_defaults.standard.dig, position);
	return _play_sfx(vd.sounds.dig, position);

func play_sfx_dug(vd, position):
	if (!vd.sounds.has("dug")): return _play_sfx(_sfx_defaults.standard.dig, position);
	return _play_sfx(vd.sounds.dug, position);

func play_sfx_footstep(vd, position):
	if (!vd.sounds.has("footstep")): return _play_sfx(_sfx_defaults.standard.dig, position);
	return _play_sfx(vd.sounds.footstep, position);

func play_sfx_place(vd, position):
	if (!vd.sounds.has("place")): return _play_sfx(_sfx_defaults.standard.dig, position);
	return _play_sfx(vd.sounds.place, position);

func play_sfx_build(vd, position):
	if (!vd.sounds.has("build")): return _play_sfx(_sfx_defaults.standard.build, position);
	return _play_sfx(vd.sounds.build, position);

var _item_defaults = {
	name = "unnamed_item",
	can_mine_groups = null,
	cached_object_instance = null,
	item_scene = "Object_Item.tscn",
	item_orientation = Vector3(0, 0, 0),
	item_tile_x = 0, item_tile_y = 0,
	hit_pixels = [8, 8], grab_pixel = [8, 8],
	dig_damage = 1, hack_damage = 1, chop_damage = 1,
	physical_damage = 1, stackability = 1,
	tool_groups = [],
}


var item_def = [
	{
		name = "woodaxe",
		can_mine_groups = [CHOPPY],
		item_tile_x = 0, item_tile_y = 0,
		hit_pixels = [8, 1],grab_pixel = [3, 13],
		chop_damage = 2,
		tool_groups = ["tg_axe"],
	},
	{
		name = "woodpick",
		can_mine_groups = [CRACKY],
		item_tile_x = 1, item_tile_y = 0,
		hit_pixels = [3, 1,  14,7], grab_pixel = [2, 13],
		hack_damage = 2,
		tool_groups = ["tg_pick"],
	},
	{
		name = "woodshovel",
		can_mine_groups = [CRUMBLY],
		item_tile_x = 2, item_tile_y = 0,
		hit_pixels = [13, 2], grab_pixel = [2, 13],
		dig_damage = 2,
	},
	{
		name = "woodsword",
		item_tile_x = 3, item_tile_y = 0,
		hit_pixels = [13,2], grab_pixel = [2, 13],
		physical_damage = 2,
	},

	{
		name = "stoneaxe",
		can_mine_groups = [CHOPPY],
		item_tile_x = 4, item_tile_y = 0,
		hit_pixels = [8, 1],grab_pixel = [3, 13],
		chop_damage = 3,
		tool_groups = ["tg_axe"],
	},
	{
		name = "stonepick",
		can_mine_groups = [CRACKY],
		item_tile_x = 5, item_tile_y = 0,
		hit_pixels = [3, 1,  14,7], grab_pixel = [2, 13],
		hack_damage = 3,
		tool_groups = ["tg_pick"],
	},
	{
		name = "stoneshovel",
		can_mine_groups = [CRUMBLY],
		item_tile_x = 6, item_tile_y = 0,
		hit_pixels = [13, 2], grab_pixel = [2, 13],
		dig_damage = 3,
	},
	{
		name = "stonesword",
		item_tile_x = 7, item_tile_y = 0,
		hit_pixels = [13,2], grab_pixel = [2, 13],
		physical_damage = 3,
	},
	{
		name = "woodhammer",
		can_mine_groups = [METALLIC],
		item_tile_x = 7, item_tile_y = 1,
		hit_pixels = [7, 2,  13,8], grab_pixel = [2, 13],
		hack_damage = 4,
		tool_groups = ["tg_hammer"],
	},

	{
		name = "stonehammer",
		can_mine_groups = [METALLIC],
		item_tile_x = 6, item_tile_y = 1,
		hit_pixels = [7, 2,  13,8], grab_pixel = [2, 13],
		hack_damage = 6,
		tool_groups = ["tg_hammer"],
	},
	
	{
		name = "steelhammer",
		can_mine_groups = [METALLIC],
		item_tile_x = 8, item_tile_y = 1,
		hit_pixels = [7, 2,  13,8], grab_pixel = [2, 13],
		hack_damage = 8,
		tool_groups = ["tg_hammer"],
	},
	
	
	{
		name = "bronzeaxe",
		can_mine_groups = [CHOPPY],
		item_tile_x = 8, item_tile_y = 0,
		hit_pixels = [8, 1],grab_pixel = [3, 13],
		chop_damage = 4,
		tool_groups = ["tg_axe"],
	},
	{
		name = "bronzepick",
		can_mine_groups = [CRACKY],
		item_tile_x = 9, item_tile_y = 0,
		hit_pixels = [3, 1,  14,7], grab_pixel = [2, 13],
		hack_damage = 4,
		tool_groups = ["tg_pick"],
	},
	{
		name = "bronzeshovel",
		can_mine_groups = [CRUMBLY],
		item_tile_x = 10, item_tile_y = 0,
		hit_pixels = [13, 2], grab_pixel = [2, 13],
		dig_damage = 4,
	},
	{
		name = "bronzesword",
		item_tile_x = 11, item_tile_y = 0,
		hit_pixels = [13,2], grab_pixel = [2, 13],
		physical_damage = 4,
	},
	
	{
		name = "steelaxe",
		can_mine_groups = [CHOPPY],
		item_tile_x = 12, item_tile_y = 0,
		hit_pixels = [8, 1],grab_pixel = [3, 13],
		chop_damage = 5,
		tool_groups = ["tg_axe"],
	},
	{
		name = "steelpick",
		can_mine_groups = [CRACKY],
		item_tile_x = 13, item_tile_y = 0,
		hit_pixels = [3, 1,  14,7], grab_pixel = [2, 13],
		hack_damage = 5,
		tool_groups = ["tg_pick"],
	},
	{
		name = "steelshovel",
		can_mine_groups = [CRUMBLY],
		item_tile_x = 14, item_tile_y = 0,
		hit_pixels = [13, 2], grab_pixel = [2, 13],
		dig_damage = 5,
	},
	{
		name = "steelsword",
		item_tile_x = 15, item_tile_y = 0,
		hit_pixels = [13,2], grab_pixel = [2, 13],
		physical_damage = 5,
	},

	{
		name = "stick",
		item_tile_x = 24, item_tile_y = 0,
		hit_pixels = [12, 3], grab_pixel = [3, 12],
		stackability = 16,
	},

	{
		name = "iron_lump",
		item_tile_x = 25, item_tile_y = 0,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "tin_lump",
		item_tile_x = 26, item_tile_y = 0,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "clay_lump",
		item_tile_x = 27, item_tile_y = 0,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "coal_lump",
		item_tile_x = 28, item_tile_y = 0,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "gold_lump",
		item_tile_x = 29, item_tile_y = 0,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "copper_lump",
		item_tile_x = 30, item_tile_y = 0,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},


	{
		name = "apple",
		item_tile_x = 31, item_tile_y = 0,
		stackability = 16,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
		grab_pixel = [8, 15],
	},

	{
		name = "paper",
		item_tile_x = 0, item_tile_y = 1,
		stackability = 16,
		item_orientation = Vector3(0, deg2rad(90), 0),
		grab_pixel = [3, 8],
	},
	
	{
		name = "crafting_guide",
		item_tile_x = 0, item_tile_y = 1,
		item_scene = "Item_CraftingGuide.tscn",
		item_orientation = Vector3(deg2rad(45), deg2rad(90), 0),
		grab_pixel = [8, 15],
	},
	
	{
		name = "tin_ingot",
		item_tile_x = 1, item_tile_y = 1,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "steel_ingot",
		item_tile_x = 1, item_tile_y = 1,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "gold_ingot",
		item_tile_x = 1, item_tile_y = 1,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "copper_ingot",
		item_tile_x = 1, item_tile_y = 1,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	{
		name = "bronze_ingot",
		item_tile_x = 1, item_tile_y = 1,
		stackability = 64,
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
	},
	
	{
		name = "toilet_paper",
		item_scene = "Item_ToiletPaper.tscn",
		item_orientation = Vector3(deg2rad(90), deg2rad(90), 0),
		grab_pixel = [8, 15],
		stackability = 16,
	},


]

# this is all a bit ugly; but so far I have no better design idea
func is_item_definition(def):
	return "item_tile_x" in def;

func is_voxel_block_definition(def):
	return "cube_tiles_x" in def;


var _voxel_block_defaults = {
	name = "unnamed_voxel",
	id = -1,
	transparent = false,
	mine_groups = [CRUMBLY],
	breakable_by_tool_groups = null, # make a block only breakable by specific tool_groups
	material_id = 0,
	geometry_type = GEOMETRY_TYPE.Cube,
	geometry_height = 1.0,
	# left, right, bottom, top, back, front
	cube_tiles_x = 0,
	cube_tiles_y = 0,
	
	custom_mesh_path = null,
	
	mine_results = null, # the mine result will define what you get and how; not yet sure how this will look; null means you get the block
	can_mine = true,
	sounds = _sfx_defaults.crumbly,
	
	# how the block behaves when mining
	stability = 3, # like the health of the block
	dig_resistance = 0,
	hack_resistance = 1,
	chop_resistance = 1,
	
	stackability = 64,
	
	cached_object_instance = null,
}

# this is a convenience dictionary that will
# get initialized with the names => id mappings (only voxels)
var voxel_block_names2id = {
	
}

# full list of all defs by name (both voxel and items)
var names2blockORitem_def = {};

func get_def_from_name(_name : String, warn := true):
	if (!names2blockORitem_def.has(_name)):
		if (warn): vr.log_error("vdb.get_def_from_name() does not contain " + _name);
		return null;
	return names2blockORitem_def[_name];

const CRUMBLY = "crumbly";
const CRACKY = "cracky";
const CHOPPY = "choppy";
const SNAPPY = "snappy";
const METALLIC = "metallic";
const BYHAND = "hand";

var voxel_block_defs = [
	{
		name = "air",
		transparent = true,
		geometry_type = GEOMETRY_TYPE.None
	},
	{
		name = "grass",
		mine_groups = [CRUMBLY],
		mine_results = ["dirt"],
		cube_tiles_x = [4, 4, 0, 2, 4, 4],
		cube_tiles_y = [0, 0, 0, 0, 0, 0],
		sounds = _sfx_defaults.grass,
	},
	{
		name = "dirt",
		mine_groups = [CRUMBLY],
	},
	{
		name = "stone",
		mine_groups = [CRACKY],
		craft_groups = ["cg_stone"],
		cube_tiles_x = 1,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "gravel",
		mine_groups = [CRUMBLY],
		cube_tiles_x = 20, cube_tiles_y = 2,
		sounds = _sfx_defaults.gravel,
		hack_resistance = 3, dig_resistance = 1, chop_resistance = 5,
	},
	{
		name = "brick",
		mine_groups = [CRACKY],
		cube_tiles_x = 0, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "stone_brick",
		mine_groups = [CRACKY],
		cube_tiles_x = 1, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "cobble",
		mine_groups = [CRACKY],
		cube_tiles_x = 2, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "sand",
		mine_groups = [CRUMBLY],
		craft_groups = ["cg_sand"],
		sounds = _sfx_defaults.sand,
		cube_tiles_x = 3,
	},
	{
		name = "sandstone",
		mine_groups = [CRACKY],
		craft_groups = ["cg_stone"],
		cube_tiles_x = 3, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "sandstone_brick",
		mine_groups = [CRACKY],
		cube_tiles_x = 4, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "obsidian",
		mine_groups = [CRACKY],
		cube_tiles_x = 5, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 3, dig_resistance = 99, chop_resistance = 99,
	},
	{
		name = "obsidian_brick",
		mine_groups = [CRACKY],
		cube_tiles_x = 6, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 3, dig_resistance = 99, chop_resistance = 99,
	},
	{
		name = "desert_stone",
		mine_groups = [CRACKY],
		craft_groups = ["cg_stone"],
		cube_tiles_x = 7, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "desert_stone_brick",
		mine_groups = [CRACKY],
		cube_tiles_x = 8, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "desert_cobble",
		mine_groups = [CRACKY],
		cube_tiles_x = 9, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "desert_sand",
		mine_groups = [CRUMBLY],
		craft_groups = ["cg_sand"],
		cube_tiles_x = 10, cube_tiles_y = 2,
		sounds = _sfx_defaults.sand,
	},
	{
		name = "tree",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_tree"], 
		stability = 6,
		#mine_results = ["wood", "wood", "wood", "wood"],
		cube_tiles_x = [5, 5, 6, 6, 5, 5],
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 1, chop_resistance = 0,
	},
	{
		name = "leaves",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		cube_tiles_x = 7,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "aspen_tree",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_tree"], 
		stability = 8,
		#mine_results = ["aspen_wood", "aspen_wood", "aspen_wood", "aspen_wood"],
		cube_tiles_x = [14, 14, 15, 15, 14, 14],
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 1, chop_resistance = 0,
	},
	{
		name = "aspen_leaves",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		cube_tiles_x = 16,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "aspen_wood",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_wood"], # behaves as food for crafting
		stability = 2,
		cube_tiles_x = 17,
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 0, chop_resistance = 0,
	},
	{
		name = "pine_tree",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_tree"], 
		stability = 8,
		#mine_results = ["pine_wood", "pine_wood", "pine_wood", "pine_wood"],
		cube_tiles_x = [22, 22, 23, 23, 22, 22],
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 1, chop_resistance = 0,
	},
	{
		name = "pine_needles",
		material_id = 1,
		mine_groups = [SNAPPY],
		transparent = true,
		cube_tiles_x = 24,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "pine_wood",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_wood"], # behaves as food for crafting
		stability = 2,
		cube_tiles_x = 25,
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 0, chop_resistance = 0,
	},
	{
		name = "jungle_tree",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_tree"], 
		stability = 10,
		#mine_results = ["jungle_wood", "jungle_wood", "jungle_wood", "jungle_wood"],
		cube_tiles_x = [26, 26, 27, 27, 26, 26],
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 1, chop_resistance = 0,
	},
	{
		name = "jungle_leaves",
		material_id = 1,
		mine_groups = [SNAPPY],
		transparent = true,
		cube_tiles_x = 28,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "jungle_wood",
		mine_groups = [CHOPPY, BYHAND],
		craft_groups = ["cg_wood"], # behaves as wood for crafting
		stability = 2,
		cube_tiles_x = 29,
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 0, chop_resistance = 0,
	},
	{
		name = "snowdirt",
		mine_groups = [CRUMBLY, BYHAND],
		cube_tiles_x = [9, 9, 0, 8, 9, 9], cube_tiles_y = [0, 0, 0, 0, 0, 0],
		sounds = {
			dig = sfx_dig_crumbly,
			dug = "default_dirt_footstep.2",
			footstep = sfx_snow_footstep, 
		},
	},
	{
		name = "snowstone",
		mine_groups = [CRACKY],
		cube_tiles_x = [10, 10, 1, 8, 10, 10], cube_tiles_y = [0, 0, 0, 0, 0, 0],
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
		sounds = {
			dig = "default_dig_cracky",
			dug = "default_dirt_footstep.2",
			footstep = sfx_snow_footstep, 
		},
	},
	{
		name = "iron_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 11, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 5, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "tin_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 12, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 5, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "steel_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 13, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 7, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "mese_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 14, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 7, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "gold_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 15, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 5, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "diamond_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 16, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 9, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "copper_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 17, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 7, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "coal_block",
		mine_groups = [METALLIC, CRACKY],
		cube_tiles_x = 18, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 4, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "bronze_block",
		mine_groups = [METALLIC],
		cube_tiles_x = 19, cube_tiles_y = 2,
		sounds = _sfx_defaults.metal,
		hack_resistance = 7, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "bedrock",
		mine_groups = [CRACKY],
		cube_tiles_x = 11, cube_tiles_y = 0,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 999, dig_resistance = 999, chop_resistance = 999,
	},
	{
		name = "cloud",
		mine_groups = [],
		cube_tiles_x = 12,
		cube_tiles_y = 0,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 999,
		dig_resistance = 999,
		chop_resistance = 999,
	},
	{
		name = "wood",
		mine_groups = [CHOPPY],
		craft_groups = ["cg_wood"], # behaves as wood for crafting
		stability = 2,
		cube_tiles_x = 13,
		sounds = _sfx_defaults.choppy,
		dig_resistance = 3, hack_resistance = 0, chop_resistance = 0,
	},
	
	{ #!!!TODO: Note this is just a very first test; lots of stuff still missing
		name = "fence_full_NS",
		stability = 2,
		cube_tiles_x = 13,
		transparent = true,
		sounds = _sfx_defaults.choppy,
		#geometry_type = GEOMETRY_TYPE.Custom,
		#custom_mesh_path = "res://data/models3d/Fence_full_N.mesh",
		dig_resistance = 3, hack_resistance = 0, chop_resistance = 0,
	},
	
	{
		name = "stone_with_coal",
		mine_groups = [CRACKY],
		mine_results = [],
		special_mine_items = ["woodpick", "stonepick", "bronzepick", "steelpick",  "mesepick", "diamondpick"],
		special_mine_results = ["coal_lump"],
		cube_tiles_x = 30, cube_tiles_y = 0,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "stone_with_iron",
		mine_groups = [CRACKY],
		mine_results = [],
		special_mine_items = ["stonepick", "bronzepick", "steelpick",  "mesepick", "diamondpick"],
		special_mine_results = ["iron_lump"], #?? does this exist
		cube_tiles_x = 3, cube_tiles_y = 1,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	{
		name = "stone_with_gold",
		mine_groups = [CRACKY],
		mine_results = [],
		special_mine_items = ["bronzepick", "steelpick",  "mesepick", "diamondpick"],
		special_mine_results = ["gold_lump"],
		cube_tiles_x = 2, cube_tiles_y = 1,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 1, dig_resistance = 3, chop_resistance = 3,
	},
	
	
	{
		name = "plant_grass_1",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 6, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_grass_2",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 7, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_grass_3",
		mine_groups = [SNAPPY],
		material_id = 1,
		can_mine = false,
		transparent = true,
		cube_tiles_x = 8, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_grass_4",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 9, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_grass_5",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 10, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	
	{
		name = "wood_workbench",
		mine_groups = [BYHAND],
		cube_tiles_x = [22, 22, 23, 21, 22, 22],
		cube_tiles_y = 2,
		sounds = _sfx_defaults.choppy,
		stability = 8,
		breakable_by_tool_groups = [BYHAND],
	},
	
		{
		name = "stone_workbench",
		sfx_craft_steps = sfx_hard_footstep,
		mine_groups = [BYHAND],
		cube_tiles_x = [22, 22, 24, 26, 22, 22],
		cube_tiles_y = 2,
		sounds = _sfx_defaults.choppy,
		stability = 8,
		breakable_by_tool_groups = [BYHAND],
	},

	{
		name = "furnace",
		mine_groups = [BYHAND],
		cube_tiles_x = [27, 27, 24, 26, 27, 27],
		cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		stability = 8,
		breakable_by_tool_groups = [BYHAND],
	},
	
	{
		name = "glass_block",
		mine_groups = [],
		material_id = 1,
		transparent = true,
		cube_tiles_x = 28, cube_tiles_y = 2,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
		sounds = {
			dig = sfx_break_glass,
			dug = sfx_break_glass,
			footstep = sfx_hard_footstep,
			place = sfx_place_node,
			build = ["default_place_node_hard.1", "default_place_node_hard.2"],
		},
	},

	{
		name = "anvil",
		sfx_craft_steps = sfx_metal_footstep,
		mine_groups = [BYHAND],
		stability = 12,
		cube_tiles_x = 11, cube_tiles_y = 2,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
		sounds = _sfx_defaults.metal,
		transparent = true,
		geometry_type = GEOMETRY_TYPE.Custom,
		custom_mesh_path = "res://data/models3d/anvil.mesh"
	},
	
	{
		name = "plant_flower_dandelion_white",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 22, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	
	{
		name = "plant_flower_dandelion_yellow",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 23, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_flower_dandelion_geranium",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 24, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_flower_mushroom_brown",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 25, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_flower_mushroom_red",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 26, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_flower_rose",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 27, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_flower_tulip",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 28, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	{
		name = "plant_flower_viola",
		mine_groups = [SNAPPY],
		material_id = 1,
		transparent = true,
		can_mine = false,
		cube_tiles_x = 29, cube_tiles_y = 1,
		geometry_type = GEOMETRY_TYPE.Plant,
		geometry_height = 1.0,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
	},
	
	{
		name = "wooden_crate",
		mine_groups = [BYHAND],
		stability = 12,
		cube_tiles_x = 29, cube_tiles_y = 2,
		dig_resistance = 0, chop_resistance = 0, hack_resistance = 0,
		sounds = _sfx_defaults.choppy,
		#transparent = true,
		#geometry_type = GEOMETRY_TYPE.Custom,
		#custom_mesh_path = "res://data/models3d/anvil.mesh"
	},
	
	{
		name = "temp_nonminable_stone_brick",
		mine_groups = [],
		cube_tiles_x = 1, cube_tiles_y = 2,
		sounds = _sfx_defaults.cracky,
		hack_resistance = 999, dig_resistance = 999, chop_resistance = 999,
	},
];

# this is basically a hack to get voxel defs for world objects so they
# can be crafted and put (as blocks)
var _world_object_voxel_def = [
	
	
];


var _crafting_recipies = [
	{
		input = ["tree"],
		output = ["wood", "wood", "wood", "wood"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},
	{
		input = ["aspen_tree"],
		output = ["aspen_wood", "aspen_wood", "aspen_wood", "aspen_wood"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},
	{
		input = ["pine_tree"],
		output = ["pine_wood", "pine_wood", "pine_wood", "pine_wood"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},
	{
		input = ["jungle_tree"],
		output = ["jungle_wood", "jungle_wood", "jungle_wood", "jungle_wood"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "wood_workbench",
		input = ["",       "",       "",
				 "cg_wood",   "cg_wood",   "",
				 "cg_wood",   "cg_wood",   ""],
		output = ["wood_workbench"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "wooden_crate",
		input = ["cg_wood",   "cg_wood",   "cg_wood",
				 "cg_wood",   "",          "cg_wood",
				 "cg_wood",   "cg_wood",   "cg_wood"],
		output = ["wooden_crate"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "stone_workbench",
		input = ["",       "",       "",
				 "cg_stone",  "cg_stone",  "",
				 "cg_wood",   "cg_wood",   ""],
		output = ["stone_workbench"],
		crafttable_requirements = ["wood_workbench"],
		tool_requirements = null,
	},
	{
		recipe_name = "furnace",
		input = ["cg_stone", "cg_stone", "cg_stone",
				 "cg_stone", "",         "cg_stone",
				 "cg_stone", "cg_stone", "cg_stone"],
		output = ["furnace"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "anvil",
		input = ["steel_ingot", "steel_ingot", "steel_ingot",
				 "steel_ingot", "steel_ingot",  "",
				 "steel_ingot", "steel_ingot",   ""],
		output = ["anvil"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},


	{
		recipe_name = "stick",
		input = ["cg_wood"],
		output = ["stick", "stick", "stick", "stick"],
		crafttable_requirements = ["tree", "wood_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "woodpick",
		input = ["cg_wood",   "cg_wood",    "cg_wood",
				 "",       "stick",   "",
				 "",       "stick",   ""],
		output = ["woodpick"],
		crafttable_requirements = ["wood_workbench"],
		tool_requirements = null,
	},
	{
		input = ["cg_wood",   "cg_wood",    "",
				 "cg_wood",   "stick",   "",
				 "",       "stick",   ""],
		output = ["woodaxe"],
		crafttable_requirements = ["wood_workbench"],
		tool_requirements = null,
	},
	{
		input = ["",       "cg_wood", "",
				 "",       "stick",   "",
				 "",       "stick",   ""],
		output = ["woodshovel"],
		crafttable_requirements = ["wood_workbench"],
		tool_requirements = null,
	},
	{
		input = ["",       "cg_wood",    "",
				 "",       "cg_wood",    "",
				 "",       "stick",   ""],
		output = ["woodsword"],
		crafttable_requirements = ["wood_workbench"],
		tool_requirements = null,
	},

	{
		input = ["cg_stone",  "cg_stone",   "cg_stone",
				 "",       "stick",   "",
				 "",       "stick",   ""],
		output = ["stonepick"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	{
		input = ["cg_stone",  "cg_stone",   "",
				 "cg_stone",  "stick",   "",
				 "",       "stick",   ""],
		output = ["stoneaxe"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	{
		input = ["",       "cg_stone",   "",
				 "",       "stick",   "",
				 "",       "stick",   ""],
		output = ["stoneshovel"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	{
		input = ["",       "cg_stone",   "",
				 "",       "cg_stone",   "",
				 "",       "stick",   ""],
		output = ["stonesword"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	{
		input = ["cg_wood",   "cg_wood",   "cg_wood",
				 "cg_wood",   "cg_wood",   "cg_wood",
				 "",          "stick",   ""],
		output = ["woodhammer"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	{
		input = ["cg_stone",  "cg_stone",   "cg_stone",
				 "cg_stone",  "cg_stone",   "cg_stone",
				 "",          "stick",   ""],
		output = ["stonehammer"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	{
		input = ["steel_ingot",  "steel_ingot",   "steel_ingot",
				 "steel_ingot",  "steel_ingot",   "steel_ingot",
				 "",          "stick",   ""],
		output = ["steelhammer"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},
	
	{
		input = ["steel_ingot",  "steel_ingot",   "steel_ingot",
				 "",       "stick",   "",
				 "",       "stick",   ""],
		output = ["steelpick"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},
	{
		input = ["steel_ingot",  "steel_ingot",   "",
				 "steel_ingot",  "stick",   "",
				 "",       "stick",   ""],
		output = ["steelaxe"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},
	{
		input = ["",       "steel_ingot",   "",
				 "",       "stick",   "",
				 "",       "stick",   ""],
		output = ["steelshovel"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},
	{
		input = ["",       "steel_ingot",   "",
				 "",       "steel_ingot",   "",
				 "",       "stick",   ""],
		output = ["steelsword"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},
	
	{
		input = ["",            "",        "",
				 "stone",       "stone",   "",
				 "stone",       "stone",   ""],
		output = ["stone_brick"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	
	{
		input = ["sandstone"],
		output = ["sand", "sand", "sand", "sand"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},

	{
		input = ["",            "",        "",
				 "sand",       "sand",   "",
				 "sand",       "sand",   ""],
		output = ["sandstone"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},


	{
		input = ["",            "",        "",
				 "sandstone",       "sandstone",   "",
				 "sandstone",       "sandstone",   ""],
		output = ["sandstone_brick"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	
	{
		input = ["coal_lump", "coal_lump", "coal_lump",
				 "coal_lump", "coal_lump", "coal_lump",
				 "coal_lump", "coal_lump", "coal_lump"],
		output = ["coal_block"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},
	
	{
		input = ["coal_block"],
		output = ["coal_lump","coal_lump","coal_lump","coal_lump","coal_lump","coal_lump","coal_lump","coal_lump","coal_lump"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},


	{
		input = ["iron_lump"],
		output = ["steel_ingot"],
		crafttable_requirements = ["furnace"],
		furnace_burn_time = 30.0,
		tool_requirements = null,
	},

	{
		input = ["cg_sand"],
		output = ["glass_block"],
		crafttable_requirements = ["furnace"],
		furnace_burn_time = 3.0,
		tool_requirements = null,
	},



	{
		input = ["steel_ingot", "steel_ingot", "steel_ingot",
				 "steel_ingot", "steel_ingot", "steel_ingot",
				 "steel_ingot", "steel_ingot", "steel_ingot"],
		output = ["steel_block"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},

	{
		input = ["steel_block"],
		output = ["steel_ingot","steel_ingot","steel_ingot","steel_ingot","steel_ingot","steel_ingot","steel_ingot","steel_ingot","steel_ingot"],
		crafttable_requirements = ["anvil"],
		tool_requirements = ["tg_hammer"],
	},

	{
		recipe_name = "paper",
		input = ["",          "",           "",
				 "",          "",           "",
				 "cg_wood",   "cg_wood",    "cg_wood"],
		output = ["paper", "paper", "paper"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "toilet_paper",
		input = ["",          "paper",           "",
				 "",          "stick",           "",
				 "",          "paper",           ""],
		output = ["toilet_paper"],
		crafttable_requirements = ["tree", "wood_workbench", "stone_workbench"],
		tool_requirements = null,
	},

	{
		recipe_name = "gold_block",
		input = ["toilet_paper", "toilet_paper", "toilet_paper",
				 "toilet_paper", "toilet_paper", "toilet_paper",
				 "toilet_paper", "toilet_paper", "toilet_paper"],
		output = ["gold_block"],
		crafttable_requirements = ["stone_workbench"],
		tool_requirements = ["tg_hammer"],
	},

]


func _match_craft_group(craft_def, b):
	if (craft_def == null && b == ""): return true;
	if (craft_def == null): return false;
	
	if (craft_def.name == b): return true;
	

	for group_name in craft_def.craft_groups:
		if (group_name == b): return true;
	return false;

# matches a given crafting recipie
func _match_recipie(craft_grid_defs, recipe_input):
	var is_valid = true;
	var is_valid_mirror = true;
	
	# check for single crafting
	if (recipe_input.size() == 1):
		is_valid_mirror = false;
		is_valid = true;
		var count = 0;
		for n in craft_grid_defs:
			if (_match_craft_group(n, recipe_input[0])):
				count += 1; 
			elif (n == null || n.empty()):
				pass;
			else:
				is_valid = false;
		if (count != 1): is_valid = false;
		return is_valid;

	if (recipe_input.size() == 9):
		for y in range(0, 3):
			for x in range(0, 3):
				var i = x + y*3;
				var i_norm = (3-x-1) + (2-y)*3;
				var i_mirror = (x) + (2-y)*3;
			
				if (!_match_craft_group(craft_grid_defs[i], recipe_input[i_norm])): is_valid = false;
				if (!_match_craft_group(craft_grid_defs[i], recipe_input[i_mirror])): is_valid_mirror = false;
			
	return is_valid || is_valid_mirror;


func is_in_array(arr : Array, val):
	for e in arr:
		if (e == val): return true;
	return false;
	
func is_one_of_in_array(a1 : Array, a2 : Array):
	for e in a1:
		if (is_in_array(a2, e)): return true;
	return false;


func check_and_get_crafting_recipe(craft_grid_defs : Array, crafting_bench_voxel_def):
	for recipe in _crafting_recipies:

		if (!is_in_array(recipe.crafttable_requirements, crafting_bench_voxel_def.name)):
			continue;

		if(_match_recipie(craft_grid_defs, recipe.input)):
			return recipe;

	return null;


func perform_crafting(craft_grid_defs : Array, crafting_bench_voxel_def, held_object):
	var recipe = check_and_get_crafting_recipe(craft_grid_defs, crafting_bench_voxel_def);
	
	if (recipe != null):
		
		if (recipe.tool_requirements != null):
			if (held_object == null): return null; # no object in hand so we cannot fulfill the craft requirements
			var item_def = held_object.get_item_def();
			if (item_def == null): 
				return null;
			# now we check if the held object tool troups are fulfilling the tool requirements
			if (!is_one_of_in_array(item_def.tool_groups, recipe.tool_requirements)):
				return null;

	return recipe.output;

onready var voxel_material : SpatialMaterial = preload("res://data/VoxelMaterial.tres");
onready var voxel_material_transparent : SpatialMaterial = preload("res://data/VoxelMaterial_Transparent.tres");
#onready var voxel_default_texture = voxel_material.albedo_texture # save here because loading on android did not work from res://

# this creates a mesh textured as a voxel in the world taken from a voxel_block_defs
func create_voxel_mesh_from_def(voxel_block_defs) -> MeshInstance:
	if (voxel_block_defs.cached_object_instance != null):
		return voxel_block_defs.cached_object_instance.find_node("mesh", false, false).duplicate();
	
	var mesh_instance : MeshInstance = null;
	var du = 1.0 / VOXEL_TEXTURE_ATLAS_SIZE;

	
	if (voxel_block_defs.custom_mesh_path):
		var mesh = load(voxel_block_defs.custom_mesh_path);
		if (mesh == null): vr.log_error("Could not load custem mesh in create_voxel_mesh_from_def(): " + voxel_block_defs.custom_mesh_path + " for voxeldef " + voxel_block_defs.name);
		
		mesh_instance = MeshInstance.new();
		mesh_instance.mesh = mesh; 
		var mat = voxel_material.duplicate();
		
		var ox = voxel_block_defs.cube_tiles_x;
		var oy = voxel_block_defs.cube_tiles_y;
		
		mat.uv1_offset = Vector3(ox*du, oy*du, 0.0);
		mat.uv1_scale = Vector3(du, du, 1.0);
		
		mesh_instance.mesh.surface_set_material(0, mat);
		
		return mesh_instance;
		
	# Standard cube creation
	mesh_instance = load("res://static_objects/VoxelCubeMeshInstance.tscn").instance();
	
	
	var x = voxel_block_defs.cube_tiles_x;
	var y = voxel_block_defs.cube_tiles_y;
	if (!(x is Array)): x = [x, x, x, x, x, x];
	if (!(y is Array)): y = [y, y, y, y, y, y];
	var uv_offsets = [];
	for i in range(0, 6):
		uv_offsets.append(Vector2(x[i], y[i]));
		
	#!!TODO: check for transparency and add a transparent block if needed
	mesh_instance.init_voxel_cube(voxel_material, uv_offsets, Vector2(du, du));
	
	return mesh_instance;
	
	
const _item_mesh_size_scale = 0.5/ 16.0;
func _get_item_grab_pos(item_def):
	return Vector2(item_def.grab_pixel[0], item_def.grab_pixel[1]+1);

func _create_item_mesh_from_def(item_def) -> MeshInstance:
	if (item_def.cached_object_instance != null):
		var mesh = item_def.cached_object_instance.find_node("mesh", false, false);
		if (mesh):
			return mesh.duplicate();
		else:
			vr.log_warning("item_def " + item_def.name + " has cached_object_instance but no mesh!");
	
	
	# this is more or less a hack to check if an object has predefined geometry and the
	# only return this one:
	var _temp_hack_item_object = load("res://dynamic_objects/"+item_def.item_scene).instance();
	if (_temp_hack_item_object._has_predefined_geometry()):
		return _temp_hack_item_object._get_item_mesh().duplicate();

	
	var mesh : MeshInstance = load("res://static_objects/VoxelizedImageMeshInstance.tscn").instance();
	
	#var imgname = "res://data/" + item_def.image_filename;
	var grab_pos = _get_item_grab_pos(item_def);
	
	var sx = 16;
	var sy = 16;
	var px = item_def.item_tile_x * sx;
	var py = item_def.item_tile_y * sy;
	
	# we create the mesh here with the collision shape
	mesh.create_mesh_from_imagedata(_item_image_data, px, py, sx, sy, _item_mesh_size_scale, grab_pos, true);
	
	mesh.rotate_x(deg2rad(45));
	
	mesh.name = "mesh";
	return mesh;


# For now the logic is to get instances form here so we are able to adjust
# the behaviour more easily
func create_voxelblock_object_from_def(voxel_block_defs):
	var voxel_object = null;
	
	if (voxel_block_defs.cached_object_instance != null):
		voxel_object = voxel_block_defs.cached_object_instance.duplicate();
	else:
		# not sure what we will all need here
		voxel_object = load("res://dynamic_objects/Object_VoxelBlock.tscn").instance();
		var mesh : MeshInstance = create_voxel_mesh_from_def(voxel_block_defs);
		
		mesh.scale = Vector3(0.125, 0.125, 0.125);
		mesh.transform.origin = Vector3(-0.062, -0.062, -0.062);
		mesh.name = "mesh";
		
		voxel_object.add_child(mesh);
		voxel_object.name = voxel_block_defs.name;
		
		voxel_block_defs.cached_object_instance = voxel_object.duplicate();
		
	voxel_object._voxel_def = voxel_block_defs;
	
	return voxel_object;
	
func create_object_from_def(def):
	if is_item_definition(def):
		return create_item_object_from_def(def);
	elif is_voxel_block_definition(def):
		return create_voxelblock_object_from_def(def);
	else:
		vr.log_error("vdb.create_object_from_def() got invalid def: " + str(def));
		return null;
	
func create_item_object_from_def(item_def):
	var item_object = null;
	if (item_def.cached_object_instance != null):
		item_object = item_def.cached_object_instance.duplicate();
	else:
		
		item_object = load("res://dynamic_objects/"+item_def.item_scene).instance();
		
		var item_object_geometry = item_object.get_geometry_node();
		
		item_object_geometry.transform.basis =  Basis(item_def.item_orientation);
		
		var mesh = null;
		var grab_pos = _get_item_grab_pos(item_def);
		
		if (!item_object._has_predefined_geometry()):
			mesh = _create_item_mesh_from_def(item_def);
			mesh.name = "mesh";
			item_object_geometry.add_child(mesh);

		
		var hit_point_collection : Spatial = item_object.get_hit_point_collection_node();
		if (hit_point_collection == null): vr.log_error("create_item_object_from_def: no hit_point_collection")
		
		for i in range(0, item_def.hit_pixels.size(), 2):
			var node = Spatial.new();
			hit_point_collection.add_child(node);
			var hit_pix = Vector2(item_def.hit_pixels[i+0], item_def.hit_pixels[i+1]);
			var hit_pos = (-grab_pos + hit_pix) * _item_mesh_size_scale;
			# NOTE: rotated by 90deg to the left by swapping x, y
			node.transform.origin = Vector3(0, hit_pos.x, hit_pos.y);
			
			# This is used to debug the actual hit positions in the items
			#node.add_child(load("res://static_objects/Debug_Axis.tscn").instance());

		if (!item_object._has_predefined_geometry()):
			for c in mesh._collision_shapes:
				item_object_geometry.add_child(c);

		item_def.cached_object_instance = item_object.duplicate();

	item_object._item_def = item_def;
	return item_object;


# sets all not yet set values via the defaults structure
func _init_full_voxelblock_array():
	vr.log_info("Initializing %d voxel definitions" % voxel_block_defs.size());
	for v in voxel_block_defs:
		for k in _voxel_block_defaults.keys():
			if (!v.has(k)):
				v[k] = _voxel_block_defaults[k];
				
		# set craft_groups
		if (!v.has("craft_groups")):
			v["craft_groups"] = [];
				
		if names2blockORitem_def.has(v.name):
			vr.log_error("Duplicated voxel name " + v.name + " found!!");
		else:
			names2blockORitem_def[v.name] = v;

func _init_full_item_array():
	vr.log_info("Initializing %d item definitions" % item_def.size());
	for i in item_def:
		for k in _item_defaults.keys():
			if (!i.has(k)):
				i[k] = _item_defaults[k];

		if (!i.has("craft_groups")):
			i["craft_groups"] = [];

		if names2blockORitem_def.has(i.name):
			vr.log_error("Duplicated item name " + i.name + " found!!");
		else:
			names2blockORitem_def[i.name] = i;

var voxel_library = VoxelLibrary.new();

func _initialize_voxel_library():
	voxel_library.atlas_size = VOXEL_TEXTURE_ATLAS_SIZE;
	
	var id = 0;
	for vd in voxel_block_defs:
		vd.id = id;
		voxel_block_names2id[vd.name] = id;
		if (vd.geometry_type == GEOMETRY_TYPE.None || 
			vd.geometry_type == GEOMETRY_TYPE.Cube ||
			vd.geometry_type == GEOMETRY_TYPE.Plant ||
			vd.geometry_type == GEOMETRY_TYPE.Custom):
			var voxel = voxel_library.create_voxel(id, vd.name);
			voxel.transparent = vd.transparent;
			voxel.material_id = vd.material_id;
			voxel.geometry_type = vd.geometry_type;
			
			if (vd.geometry_type == GEOMETRY_TYPE.Cube):
				var x = vd.cube_tiles_x;
				var y = vd.cube_tiles_y;
				if (!(x is Array)): x = [x, x, x, x, x, x];
				if (!(y is Array)): y = [y, y, y, y, y, y];

				voxel.set("cube_tiles/left", Vector2(x[0], y[0]));
				voxel.set("cube_tiles/right", Vector2(x[1], y[1]));
				voxel.set("cube_tiles/bottom", Vector2(x[2], y[2]));
				voxel.set("cube_tiles/top", Vector2(x[3], y[3]));
				voxel.set("cube_tiles/back", Vector2(x[4], y[4]));
				voxel.set("cube_tiles/front", Vector2(x[5], y[5]));
				
				# create the mesh instance used for display
				# !!NOTE: not sure if this is a good idea here; if this takes too long
				#         we might need to make it delayed instead of creating all on startup
				vd.mesh_instance = create_voxel_mesh_from_def(vd);
			
			if (vd.geometry_type == GEOMETRY_TYPE.Plant):
				voxel.set("plant_tile", Vector2(vd.cube_tiles_x, vd.cube_tiles_y));
				voxel.set("plant_height", vd.geometry_height);
				
			if (vd.geometry_type == GEOMETRY_TYPE.Custom):
				var mesh = load(vd.custom_mesh_path);
				if (mesh == null): vr.log_error("Could not load custem mesh " + vd.custom_mesh_path + " for voxeldef " + vd.name)
				voxel.set("mesh", mesh);
				voxel.set("mesh_tile", Vector2(vd.cube_tiles_x, vd.cube_tiles_y));
		else:
			vr.log_warning("Yet unsupproted voxel geometry type " + str(vd.geometry_type));
			
		id = id + 1;
		
	return voxel_library;

var _item_image_data = null;


var main_world_generator = null; 


const CURRENT_SAVE_STREAM_VERSION = 2;

func _vec3_to_arr(v : Vector3):
	return [v.x, v.y, v.z];
func _arr_to_vec3(a : Array):
	return Vector3(a[0], a[1], a[2]);

func _basis_to_arr(v : Basis):
	return [v.x.x, v.x.y, v.x.z, 
			v.y.x, v.y.y, v.y.z, 
			v.z.x, v.z.y, v.z.z];
func _arr_to_basis(a: Array):
	return Basis(Vector3(a[0], a[1], a[2]),
				 Vector3(a[3], a[4], a[5]),
				 Vector3(a[6], a[7], a[8]))

func _transform_to_arr(t : Transform):
	var v = t.basis;
	var p = t.origin;
	return [v.x.x, v.x.y, v.x.z, 
			v.y.x, v.y.y, v.y.z, 
			v.z.x, v.z.y, v.z.z,
			p.x, p.y, p.z];
func _arr_to_transform(a: Array):
	return Transform(Basis(Vector3(a[0], a[1], a[2]),
				 Vector3(a[3], a[4], a[5]),
				 Vector3(a[6], a[7], a[8])),
				Vector3(a[9], a[10], a[11]));


func _get_save_dictionary(_persisted_nodes_array : Array):
	var d = OS.get_datetime();
	
	var ret = {
		"desc" : {
			"stream_version" : CURRENT_SAVE_STREAM_VERSION,
			"game_version" : GAME_VERSION_STRING,
			"world_name" : world_name,
			"world_uuid" : world_uuid,
			"terrain_generator_version" : main_world_generator.get_version_string(),
			"terrain_generator_seed" : main_world_generator.terrain_generator_seed,
			"save_date" : "%d.%02d.%02d_%02d.%02d.%02d"  % [d.year, d.month, d.day, d.hour, d.minute, d.second],
			"vrOrigin_position" : _vec3_to_arr(vr.vrOrigin.global_transform.origin),
			"vrCamera_position" : _vec3_to_arr(vr.vrCamera.global_transform.origin),
			"vrCamera_orientation" : _basis_to_arr(vr.vrCamera.global_transform.basis),
			#"casual_mode" : casual_mode,
			"game_mode" : game_mode,
		},
		"data" : {
			"block_data" : main_world_generator._persisted_blocks,
			"saved_nodes" : {},
		}
	}
	
	
	for o in _persisted_nodes_array:
		if (!o.has_method("get_save_dictionary")):
			vr.log_error("vdb._get_save_dictionary(): Object " + str(o) + " has no get_save_dictionary() method.");
			continue;
		ret.data.saved_nodes[o.get_path()] = o.get_save_dictionary();
		
	return ret;


func calculate_approximated_calories(distance : float):
	return (distance) * (0.1/1.60934); # 100 cal/mile = 100 / (1000 * 1.60) cal/km


func _set_player_position(pos):
	var delta_origin = (vr.vrOrigin.global_transform.origin - vr.vrCamera.global_transform.origin);
	
	print("_set_player_position " + str(pos));
	print(delta_origin);
	
	# now set the origin in a way that the camera position is exactly the same as saved
	vr.vrOrigin.global_transform.origin = pos + delta_origin;

func load_player_position(full_save_dictionary):
	var desc = full_save_dictionary.desc;

	if (!vr.inVR):
		vr.vrOrigin.global_transform.origin = _arr_to_vec3(desc.vrOrigin_position);
		vr.vrCamera.global_transform.origin = _arr_to_vec3(desc.vrCamera_position);
		vr.vrCamera.global_transform.basis = _arr_to_basis(desc.vrCamera_orientation);
	else:
		_set_player_position(_arr_to_vec3(desc.vrCamera_position));

func load_world(full_save_dictionary):
	load_meta(full_save_dictionary.desc);
	load_saved_nodes(full_save_dictionary);
	load_terrain(full_save_dictionary);

func load_meta(desc):
	if (desc.has("casual_mode")): # legacy loading before introducing game mode
		if (desc.casual_mode): game_mode = GAME_MODE.STANDARD;
		else: game_mode = GAME_MODE.SPORTIVE;
	else:
		game_mode = desc.game_mode;
	world_name = desc.world_name;
	
	if (desc.has("world_uuid")):
		world_uuid = desc.world_uuid;
	else:
		world_uuid = gen_uuid();

func load_terrain(full_save_dictionary):
	# this is the actual saved data from the terrain generator
	var persisted_blocks = full_save_dictionary.data.block_data;
	var generator_seed = full_save_dictionary.desc.terrain_generator_seed;
	main_world_generator = load("scripts/TerrainGenerator_V1.gd").new();
	main_world_generator.initialize(generator_seed, persisted_blocks);

func load_saved_nodes(full_save_dictionary):
	var data = full_save_dictionary.data;

	for k in data.saved_nodes:
		var node = get_node(NodePath(k));
		if (node == null):
			vr.log_error("vdb.load_saved_nodes(): could not find node " + k);
			continue;
		if (!node.has_method("apply_save_dictionary")):
			vr.log_error("vdb.func load_saved_nodes(r):(): Object " + str(node) + " has no apply_save_dictionary() method.");
			continue;
		node.apply_save_dictionary(data.saved_nodes[k]);

func _apply_loaded_dictionary(target, loaded):
	if (!loaded):
		vr.log_error("_apply_loaded_dictionary() got null!");
		return;
	
	for k in loaded.keys():
		if (target.has(k)):
			target[k] = loaded[k];
		else:
			vr.log_warning("_apply_loaded_dictionary(): key " + k + " not in dicitonary");


func save_global_statistics():
	var save = File.new();
	var filename = "statistics.save"
	var err = save.open("user://" + filename, File.WRITE)
	if (err == OK):
		save.store_line(to_json(global_statistics));
		save.close();
	else:
		vr.log_error("Could not save global_statistics to " + OS.get_user_data_dir() + "/" + filename);


func load_global_statistics():
	var save = File.new();
	var filename = "statistics.save"
	var err = save.open("user://" + filename, File.READ)
	if (err == OK):
		var r = JSON.parse(save.get_as_text()).result;
		_apply_loaded_dictionary(global_statistics, r);
		save.close();
	else:
		vr.log_error("Could not load global_statistics from " + OS.get_user_data_dir() + "/" + filename);


func save_gameplay_settings():
	var save = File.new();
	var filename = "gameplay_settings.save"
	var err = save.open("user://" + filename, File.WRITE)
	
	if (err == OK):
		save.store_line(to_json(gameplay_settings));
		save.close();
		
		notify_gameplay_settings_changed();
	else:
		vr.log_error("Could not save settings to " + OS.get_user_data_dir() + "/" + filename);

func load_gameplay_settings():
	var save = File.new();
	var filename = "gameplay_settings.save"
	var err = save.open("user://" + filename, File.READ)
	
	if (err == OK):
		var r = JSON.parse(save.get_as_text()).result;
		_apply_loaded_dictionary(gameplay_settings, r);
		save.close();
	else:
		vr.log_error("Could not load settings from " + OS.get_user_data_dir() + "/" + filename);


func persistence_get_next_free_save_filename_infix():
	var file = File.new();
	var num = 1;
	while(true):
		var filename_infix = "slot_%03d" % num;
		var filename = "savegame_desc_" + filename_infix + ".save";
		if (!file.file_exists("user://" + filename)): 
			vr.log_info("Next free savegame is " + filename_infix);
			return filename_infix;
		num = num + 1;


func persistence_get_all_savegame_files():
	var files = []
	var path = "user://";
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	var read = File.new();
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file.begins_with("savegame_desc_"):
			var err = read.open("user://"+file, File.READ);
			if (err == OK):
				var r = JSON.parse(read.get_as_text()).result;
				
				if (r == null):
					vr.log_error("Unrecoverable error in loading " + file);
					continue;
				
				r["filename_infix"] = file.replace("savegame_desc_","").replace(".save","");
				if(!r.has("world_name")):
					r["world_name"] = file.replace("savegame_desc_","").replace(".save","");
				
				files.append(r);
			
				#files.append(file.replace("savegame_desc_","").replace(".save",""));
	
	dir.list_dir_end();
	return files

# this splits into two save files for faster loading of metadata
func persistence_save_game(_persisted_nodes_array : Array):
	var save_desc = File.new();
	var save_data = File.new();
	var filename_desc = "savegame_desc_"+current_save_file_infix+".save";
	var filename_data = "savegame_data_"+current_save_file_infix+".save";
	var err1 = save_desc.open("user://" + filename_desc, File.WRITE)
	var err2 = save_data.open("user://" + filename_data, File.WRITE)
	if (err1 == OK && err2 == OK):
		var full_save_dictionary = _get_save_dictionary(_persisted_nodes_array);
		save_desc.store_line(to_json(full_save_dictionary.desc));
		save_data.store_line(to_json(full_save_dictionary.data));
		save_desc.close();
		save_data.close();
		vr.log_info("Saved game to " + OS.get_user_data_dir() + "/" + current_save_file_infix);
	else:
		vr.log_error("Could not save game to " + OS.get_user_data_dir() + "/" + current_save_file_infix);



func _loadandplay_game_dict(r):
	game_mode = startup_settings.game_mode;
	world_name = startup_settings.world_name;
	world_uuid = startup_settings.world_uuid;

	if !r:
		main_world_generator = load("scripts/TerrainGenerator_V1.gd").new();
		main_world_generator.initialize(startup_settings.generator_seed, {});
	elif ((r != null) && (r.desc == null || r.data == null)):
		vr.log_error("Could not load game from " + OS.get_user_data_dir() + "/" + current_save_file_infix);
		main_world_generator = load("scripts/TerrainGenerator_V1.gd").new();
		main_world_generator.initialize(0, {});
	elif (r.desc.stream_version != CURRENT_SAVE_STREAM_VERSION):
		vr.log_error("Could not load game from " + OS.get_user_data_dir() + "/" + current_save_file_infix + " Wrong stream version: got %d; expected %d" % [r.desc.stream_version, CURRENT_SAVE_STREAM_VERSION])
		main_world_generator = load("scripts/TerrainGenerator_V1.gd").new();
		main_world_generator.initialize(0, {});
	else:
		load_player_position(r);
		load_world(r);

		vr.log_info("Loaded game from " + OS.get_user_data_dir() + "/" + current_save_file_infix);

	# now we remember the session start statistis; this assumes that we will always
	# call load_game() at the start of a session :
	session_start_statistics = get_global_statistics_copy();
	
		# reset the start position if requested
	if (!startup_settings.load_game || startup_settings.reset_start_position):
		_set_player_position(main_world_generator.start_position);
		


func persistence_load_and_start_game():
	#_persisted_blocks.clear();
	current_save_file_infix = startup_settings.save_file_infix;
	
	var r = null;
	
	if (startup_settings.world_dict != null):
		r = startup_settings.world_dict;
		r.desc.world_uuid = gen_uuid(); # create a new one to avoid overwriting it with multiple shares
	elif (startup_settings.load_game):
		var save_desc = File.new();
		var save_data = File.new();
		var filename_desc = "savegame_desc_"+current_save_file_infix+".save";
		var filename_data = "savegame_data_"+current_save_file_infix+".save";
		var err1 = save_desc.open("user://" + filename_desc, File.READ);
		var err2 = save_data.open("user://" + filename_data, File.READ);
		
		if (save_desc.is_open() && save_data.is_open()):
			# replace is here for the transition of 0.3.6 to 0.4.0 where
			# we changed the location of the player
			# TODO: move to savegame converter
			var data_text = save_data.get_as_text().replace("/GameMain/VoxelGame", "/GameMain/MainWorld/VoxelWorldPlayer");
			r = {
				"desc" : JSON.parse(save_desc.get_as_text()).result,
				"data" : JSON.parse(data_text).result,
			}
			save_desc.close();
			save_data.close();
		else:
			vr.log_error("Could not load game from " + OS.get_user_data_dir() + "/" + current_save_file_infix);

	_loadandplay_game_dict(r);



static func getRandomInt(max_value):
	randomize()
	return randi() % max_value

static func randomBytes(n):
	var r = []
	for index in range(0, n):
		r.append(getRandomInt(256))
	return r

static func uuidbin():
	var b = randomBytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return b

static func gen_uuid():
	var b = uuidbin()
	
	var low = '%02x%02x%02x%02x' % [b[0], b[1], b[2], b[3]]
	var mid = '%02x%02x' % [b[4], b[5]]
	var hi = '%02x%02x' % [b[6], b[7]]
	var clock = '%02x%02x' % [b[8], b[9]]
	var node = '%02x%02x%02x%02x%02x%02x' % [b[10], b[11], b[12], b[13], b[14], b[15]]
	
	return '%s-%s-%s-%s-%s' % [low, mid, hi, clock, node]
#
#func persistence_save_game_v1(_persisted_nodes_array : Array):
#	var save = File.new();
#	var filename = current_save_file;
#	var err = save.open("user://" + filename, File.WRITE)
#	if (err == OK):
#		save.store_line(to_json(_get_save_dictionary(_persisted_nodes_array)));
#		save.close()
#		vr.log_info("Saved game to " + OS.get_user_data_dir() + "/" + filename);
#	else:
#		vr.log_error("Could not save game to " + OS.get_user_data_dir() + "/" + filename);
#
#func persistence_load_game_v1():
#	var save = File.new();
#	var filename = current_save_file;
#	var err = save.open("user://" + filename, File.READ)
#	if (err == OK):
#		var r = JSON.parse(save.get_as_text()).result;
#		save.close();
#
#		if (r.stream_version != CURRENT_SAVE_STREAM_VERSION):
#			vr.log_error("Could not load game from " + OS.get_user_data_dir() + "/" + filename + " Wrong stream version: got %d; expected %d" % [r.stream_version, CURRENT_SAVE_STREAM_VERSION])
#		else:
#			load_player_position(r);
#			load_saved_nodes(r);
#			vr.log_info("Loaded game from " + OS.get_user_data_dir() + "/" + filename);
#	else:
#		vr.log_error("Could not load game from " + OS.get_user_data_dir() + "/" + filename);
#
#	# now we remember the session start statistis; this assumes that we will always
#	# call load_game() at the start of a session :
#	session_start_statistics = get_global_statistics_copy();
	

func _convert_savefile_0_3_5_to_0_3_6(in_name, out_infix):
	vr.log_info("Converting save file " + in_name + " to " + out_infix);
	var file = File.new();
	var err = file.open(in_name, File.READ)
	if (err == OK):
		var desc = JSON.parse(file.get_as_text()).result;
		file.close();
		
		var data = {
			"block_data" : desc.block_data,
			"saved_nodes" : desc.saved_nodes,
		};
		
		desc.erase("block_data");
		desc.erase("saved_nodes");
		desc.stream_version = 2;
		desc["terrain_generator_seed"] = 0;
		desc["world_name"] = out_infix;
		
		# NOTE: here needs to come all aditional information required by stream
		# updates to keep the conversio compatible
		
		var save_desc = File.new();
		var save_data = File.new();
		var filename_desc = "savegame_desc_"+out_infix+".save";
		var filename_data = "savegame_data_"+out_infix+".save";
		var err1 = save_desc.open("user://" + filename_desc, File.WRITE)
		var err2 = save_data.open("user://" + filename_data, File.WRITE)
		if (err1 == OK && err2 == OK):
			save_desc.store_line(to_json(desc));
			save_data.store_line(to_json(data));
			save_desc.close();
			save_data.close();
	else:
		vr.log_error("Error converting save file " + in_name);
	


func _check_and_convert_legacy_savegame():
	var file = File.new();
	
	if (file.file_exists("user://game.save") && !file.file_exists("user://savegame_desc_pre0.3.6_sportive.save")):
		_convert_savefile_0_3_5_to_0_3_6("user://game.save", "pre0.3.6_sportive");
	if (file.file_exists("user://game_casual.save") && !file.file_exists("user://savegame_desc_pre0.3.6_standard.save")):
		_convert_savefile_0_3_5_to_0_3_6("user://game_casual.save", "pre0.3.6_standard");

func load_vox_onlyvoxels(file_path):
	var file = File.new()
	var error = file.open( file_path, File.READ )
	if error != OK:
		if file.is_open(): file.close()
		return error
	
	var voxels_byte_array;
	var magic = PoolByteArray([file.get_8(),file.get_8(),file.get_8(),file.get_8()]).get_string_from_ascii()
	var version = file.get_32()
	 
	var sizex = 0
	var sizey = 0
	var sizez = 0
	
	var has_size = false;
	var has_voxels = false;
	# a MagicaVoxel .vox file starts with a 'magic' 4 character 'VOX ' identifier
	if magic == "VOX ":
		
		while file.get_position() < file.get_len():
			# each chunk has an ID, size and child chunks
			var chunkId = PoolByteArray([file.get_8(),file.get_8(),file.get_8(),file.get_8()]).get_string_from_ascii() #char[] chunkId
			var chunkSize = file.get_32()
			var childChunks = file.get_32()
			var chunkName = chunkId
			# there are only 2 chunks we care about: SIZE and XYZI
			if chunkName == "SIZE":
				sizex = file.get_32()
				sizey = file.get_32()
				sizez = file.get_32()
				file.get_buffer(chunkSize - 4 * 3)
				has_size = true;
			elif chunkName == "XYZI":
				# XYZI contains n voxels
				var numVoxels = file.get_32()
				#voxels_int32.resize(numVoxels);
				voxels_byte_array = file.get_buffer(numVoxels*4)
				#for i in range(0,numVoxels):
				#	voxels_int32[i] = file.get_32();
				has_voxels = true;
			else: file.get_buffer(chunkSize)  # read any excess bytes
			
			if (has_voxels && has_size): break; # we have all we need
	file.close()
	
	return [sizex, sizey, sizez, voxels_byte_array];


var voxel_world_player = null;

func initialize():
	
	vr.log_info("VoxelDatabase.initialize()");
	
	reset_startup_settings();
	
	# create the main player
	voxel_world_player = load("res://levels/VoxelWorldPlayer.tscn").instance();
	voxel_world_player.initialize_voxel_world_player();
	
	
	_check_and_convert_legacy_savegame();
	
	session_start_statistics = get_global_statistics_copy(); # to make sure we have a valid copy even if we don't load
	_item_image_data = load("res://data/items.png").get_data();
	_init_full_voxelblock_array();
	_init_full_item_array();
	_init_sfx();
	_initialize_voxel_library();
