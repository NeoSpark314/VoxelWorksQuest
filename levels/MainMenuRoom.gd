extends Spatial


onready var info_text_label = $InfoTextLabel;
onready var changelog_text_label = $ChangeLogLabel;
onready var statistics_text_label = $StatisticsTextLabel;

var savegame_item_list : ItemList = null;

const info_text ="""%s %s
Welcome!

In this prototype you can explore an infinite voxel world.
It is an early prototype and all mechanics are just experimental. 
Things will change in future updates.

If you have questions or feedback join the Voxel Works Discord
(link is on the sidequest page or on itch.io).

<-- Gameplay Statistics                                       Start Game -->
""" % [vdb.GAME_NAME, vdb.GAME_VERSION_STRING];

# current changelog is always the first
const changelog_text = [
"""Changelog for %s

 - New Game Mode: Creative
 - Option to load your own texture pack within the game
 - Option to increase stick locomotion speed
 - Small position adjustments now possible in sportive mode
 - smaller toolbelt grab area and option to require button press
   from the toolbelt (to avoid accidentally grabbing something)
 - hide controller when objects are grabbed
 - Added controller rumble when controller is inside a block
 - Transparent blocks (like leaves) are now climbable
 - Fixed orientation of right hand arm menu
 - Crafting tables are now only breakable by hand not by tools

<-- Start Game (look left)""" % [vdb.GAME_VERSION_STRING]
]


func create_some_blocks():
#	var pos = [
#	vdb.voxel_block_names2id.dirt, Vector3(0,0,0),
#	1, Vector3(0,1,0),
#	1, Vector3(1,0,0),
#	1, Vector3(1,0,1),
#	1, Vector3(0,0,1),
#	]
#
#	for i in range(0, pos.size(), 2):
#		var v = vdb.create_voxelblock_object_from_def(vdb.voxel_block_defs[pos[i]]);
#		v.scale = Vector3(8,8,8);
#		add_child(v);
#		v.transform.origin = pos[i+1];

	var size = 2;
	
	for z in range (-size, size+1):
		for y in range(0, 5):
			for x in range(-size, size+1):
				var v = null;
				
				if (x == -size || x == size || z == -size || z == size): #border
					if (y == 0):
						v = vdb.create_voxelblock_object_from_def(vdb.names2blockORitem_def.stone);
					elif (x == z || x == -z):
						v = vdb.create_voxelblock_object_from_def(vdb.names2blockORitem_def.stone);
				elif (y == 0): # ground
					v = vdb.create_voxelblock_object_from_def(vdb.names2blockORitem_def.grass);
				
				if (v):
					v.scale = Vector3(8,8,8);
					add_child(v);
					v.transform.origin = Vector3(x, y-0.5, z);


func _physics_process(delta):
#	if (vr.button_just_released(vr.BUTTON.A) ||
#		vr.button_just_released(vr.BUTTON.B) ||
#		vr.button_just_released(vr.BUTTON.X) ||
#		vr.button_just_released(vr.BUTTON.Y) ||
#		vr.button_just_released(vr.BUTTON.LEFT_INDEX_TRIGGER) ||
#		vr.button_just_released(vr.BUTTON.RIGHT_INDEX_TRIGGER)
#	):
#		_start_game();
	pass;


var _main_menu_checkbox_reset_start_position : CheckBox = null;
var _main_menu_checkbox_reset_crafting_guide : CheckBox = null;

func _setup_main_menu():
	var label_title = $MainMenu.find_node("Label_Title", true, false);
	
	_main_menu_checkbox_reset_start_position = $MainMenu.find_node("CheckBox_ResetStartPosition", true, false);
	_main_menu_checkbox_reset_crafting_guide = $MainMenu.find_node("CheckBox_ResetCraftingGuide", true, false);
	
	label_title.set_text(vdb.GAME_NAME + " - " + vdb.GAME_VERSION_STRING);


func _setup_statistics():
	var km = int(floor(vdb.global_statistics.traveled_distance / 1000));
	var m = int(floor(vdb.global_statistics.traveled_distance - km * 1000));
	
	var hours = int(floor(vdb.global_statistics.total_playtime / 3600));
	var minutes = int(floor(vdb.global_statistics.total_playtime / 60 - hours * 60));
	
	statistics_text_label.set_label_text("""Overall Gameplay Statistics:

	Total Jogged Distance: %3d km %3d m
	Steps taken: %d
	Total Playtime: %3d hours %2d minutes
	
	Mined Blocks (swing): %d
	Build Blocks (swing): %d
	Crafted Items (swing): %d
	
	Game Version: %s""" % [km, m, vdb.global_statistics.steps_taken, hours, minutes,
vdb.global_statistics.mined_blocks, vdb.global_statistics.build_blocks, vdb.global_statistics.crafted_items,
vdb.GAME_VERSION_STRING]);


var savegame_list = null;

func _create_savegame_list():
	savegame_item_list = $MainMenu.find_node("SaveGame_ItemList", true, false);
	
	print(OS.get_user_data_dir());
	
	print(savegame_item_list);

	savegame_list = vdb.persistence_get_all_savegame_files();
	
	for s in savegame_list:
		var entry_text = s.world_name;
		if (entry_text == null): 
			entry_text = s.filename_infix;
		
		#entry_text += " (" + s.save_date + ")";
		

		if (s.has("casual_mode")): # legacy loading before introducing game mode
			if (s.casual_mode):
				entry_text += " [Standard]";
			else:
				entry_text += " [Sportive]";
		else:
			if (s.game_mode == vdb.GAME_MODE.STANDARD):
				entry_text += " [Standard]";
			elif (s.game_mode == vdb.GAME_MODE.SPORTIVE):
					entry_text += " [Sportive]";
			elif (s.game_mode == vdb.GAME_MODE.CREATIVE):
				entry_text += " [Creative]";
			else:
				entry_text += " [UnknownMode]";
		
		savegame_item_list.add_item(entry_text);
		
	if (savegame_list.size() > 0):
		savegame_item_list.select(0);


var load_game_panel : Panel = null;
var new_game_panel : Panel = null;
var settings_panel : Panel = null;

var world_name_text_edit : TextEdit = null;
var world_seed_spin_box : SpinBox = null;
var world_generator_option_button : OptionButton = null;
var game_mode_option_button : OptionButton = null;

func _create_new_game_menu():
	load_game_panel = $MainMenu.find_node("Load Game", true, false);
	new_game_panel = $MainMenu.find_node("New Game", true, false);
	settings_panel = $MainMenu.find_node("Settings", true, false);
	
	
	#load_game_panel.visible = true;
	#new_game_panel.visible = false;

	
	world_name_text_edit = $MainMenu.find_node("TextEdit_WorldName", true, false);
	world_seed_spin_box = $MainMenu.find_node("SpinBox_WorldSeed", true, false);
	world_generator_option_button = $MainMenu.find_node("OptionButton_WorldGenerator", true, false);
	game_mode_option_button = $MainMenu.find_node("OptionButton_GameMode", true, false);

	world_generator_option_button.add_item("TerrainGenerator_V1");

	game_mode_option_button.add_item("Standard");
	game_mode_option_button.add_item("Sportive");
	game_mode_option_button.add_item("Creative");

func _ready():
	vr.leftController.set_rumble(0.0);
	vr.rightController.set_rumble(0.0);
	
	_create_savegame_list();
	
	_create_new_game_menu();
	
	create_some_blocks();
	info_text_label.set_label_text(info_text);
	changelog_text_label.set_label_text(changelog_text[0]);
	
	_setup_main_menu();
	_setup_statistics();
	
	if (_check_required_permissions()):
		_create_TextureSetList();


func _start_game():
	vr.switch_scene("res://levels/MainWorld.tscn", 0.5);


func _on_Button_LoadGame_pressed():
	if (!savegame_item_list.is_anything_selected()): return;
	
	var sg = savegame_list[savegame_item_list.get_selected_items()[0]];
	vdb.startup_settings.save_file_infix = sg.filename_infix;
	vdb.startup_settings.reset_start_position = _main_menu_checkbox_reset_start_position.pressed;
	vdb.startup_settings.reset_crafting_guide = _main_menu_checkbox_reset_crafting_guide.pressed;
	vdb.startup_settings.load_game = true;
	_start_game();


func _on_Button_StartNewGame_pressed():
	vdb.startup_settings.save_file_infix = vdb.persistence_get_next_free_save_filename_infix();
	vdb.startup_settings.reset_start_position = false;
	
	vdb.startup_settings.generator_seed = int(world_seed_spin_box.value);
	vdb.startup_settings.generator_name = world_generator_option_button.get_item_text(world_generator_option_button.get_selected_id());
	vdb.startup_settings.world_name = world_name_text_edit.text;
	vdb.startup_settings.load_game = false;
	
	#vdb.startup_settings.casual_mode = !sportive_mode_check_box.pressed;
	vdb.startup_settings.game_mode = game_mode_option_button.get_selected_id();
	
	_start_game();



var terrain_blocks_file_list = []


func _on_TerrainBlockTextures_ItemList_item_selected(index):
	var path : String = terrain_blocks_file_list[index]
	
	
	var texture = null;
	
	if (path.begins_with("res://")):
		texture = load(path);
	else:
		var image = Image.new();
		var err = image.load(path);
		
		if (err != OK):
			vr.log_error("Could not load file " + path);
			return;
		else:
			vr.log_info("Loading texture from " + path);
		texture = ImageTexture.new()
		texture.create_from_image(image, 0)
	
	vdb.voxel_material.albedo_texture = texture
	vdb.voxel_material_transparent.albedo_texture = texture

func _create_TextureSetList():
	terrain_blocks_file_list = ["res://data/terrain_blocks.png"]
	var terrain_blocks_name_list = ["default"]

	if (!_check_and_request_permission()):
		return;
		
	
	var path = "/sdcard/VoxelWorksQuest";
	
	if (!vr.inVR):
		path = "src_data/test_device_data"

	vr.log_info("Looking for textures in " + path)
	
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	var read = File.new();
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file.begins_with("terrain_blocks_"):
			terrain_blocks_file_list.append(path + "/" + file);
			terrain_blocks_name_list.append(file.replace("terrain_blocks_", "").replace(".png", ""))
#		else:
#			vr.log_info(str(file));

	var terrain_block_textures_item_list : ItemList = $MainMenu.find_node("TerrainBlockTextures_ItemList", true, false);
	terrain_block_textures_item_list.clear()

	for s in terrain_blocks_name_list:
		terrain_block_textures_item_list.add_item(s);
		
	#terrain_block_textures_item_list.select(0);


func _on_Button_Settings_RefrehTexturesets_pressed():
	_create_TextureSetList()


const READ_PERMISSION = "android.permission.READ_EXTERNAL_STORAGE"


func _check_required_permissions():
	if (!vr.inVR): return true; # desktop is always allowed
	
	var permissions = OS.get_granted_permissions()
	var read_storage_permission = vdb.is_in_array(permissions, READ_PERMISSION)
	
	vr.log_info(str(permissions));
	
	if !(read_storage_permission):
		return false;

	return true;

func _check_and_request_permission():
	vr.log_info("Checking permissions")

	if !(_check_required_permissions()):
		vr.log_info("Requesting permissions")
		OS.request_permissions()
		return false;
	else:
		return true;


