extends Spatial


onready var info_text_label = $InfoTextLabel;
onready var changelog_text_label = $ChangeLogLabel;
onready var statistics_text_label = $StatisticsTextLabel;

var savegame_item_list : ItemList = null;

const info_text ="""%s %s

In this prototype you can explore an infinite voxel world.
It is an early prototype and all mechanics are just experimental. 
Things will change in future updates.

How to play:
   - inventory: rotate your palm up (button/pinch to change slot)
   - craft: on top of tree trunks for now
   - grab things or climbing: use the grab button or a fist

In Standard Mode:
   - Stick to move/rotate
   - Button press to mine/craft/build

In Sportive Mode:
   - move forward: jog in place
   - mine/craft/build: large swing with your hand

<-- Gameplay Statistics                                       Start Game -->
""" % [vdb.GAME_NAME, vdb.GAME_VERSION_STRING];

# current changelog is always the first
const changelog_text = [
"""Changelog for %s
 - Crate block to store items
 - Fixed issue that re-applied old changes to new worlds
 

more details at https://neospark314.itch.io/voxel-works-quest

<-- Start Game (look left)""" % [vdb.GAME_VERSION_STRING],
"""Changelog for 0.3.6
 - Multiple savegames with different seeds are now possible
 - Added wood hammer and steel hammer
 - Added reset crafting guide option
 - Added 2 basic flowers
 - Fixed mined blocks spawn wrong block if inventory is full
 - Fixed mining of coal_block and steel_block (requires hammer)

Contributors (Thanks!):
  @BrudaSven (steel and wood hammer)
  @SaltyBoi (anvil 3d model)

more details at https://neospark314.itch.io/voxel-works-quest
""",
"""Changelog for 0.3.5
 - Fixed one issue for crashes
 - Fixed mining of leaves
 - Fixed getting stuck in leaves
 - Arm Menu with first game settings and coordinates
 - Toolbelt with 2 slots
 - Glass blocks (made from sand on furnace)
 - Stonehammer as new tool (required for anvil recipes)
 - Added Anvil as crafting area for metals
 - Steeltool recipes (pick, shovel, axe)

more details at https://neospark314.itch.io/voxel-works-quest

<-- Start Game (look left)""",
"""Changelog for 0.3.4
 - added wood workbench and stone workbench
 - wooden tools need a wood workbench stone tools a 
	  stone workbench
 - mining stone_with_coal now gives coal lumps (when using a pick)
 - added recipes for stone_bricks, sandstone and sandstone_bricks
 - added recipe for coal_block
 - reduced height of collision box; auto jump should now also 
	  trigger for smaller people
 - footstep sound is now also played with stick locomotion
 - first version of furnace; no fuel yet; only recipe is steel_ingot
 - can build over plants now

more details at https://neospark314.itch.io/voxel-works-quest

<-- Start Game (look left)""" ,
"""Changelog for 0.3.3
   - Fixed crash with stick locomotion + jog in place

Changelog for 0.3.2
   - Optional stanard mode for stick locomotion and button mining
   - Added crafting guide v0.1.0
   - Default stack size increased to 64 blocks
   - ...
There are many more changes: for the full pelase check the
change-log at https://neospark314.itch.io/voxel-works-quest


<-- Start Game (look left)""",
"""Changelog for 0.3.1

   - Doubled the in game Jogging speed 
   - Increased step detection sensitivity
   - Autojump now only triggers when jogging. 
   - Added a reset start position option in main menu
   - Fixed: falling when head was inside voxel
   - Fixed: item duplication bug with closed inventory

<-- Start Game (look left)"""
]


func create_some_blocks():
#	var pos = [
#	vdb.voxel_types.dirt, Vector3(0,0,0),
#	1, Vector3(0,1,0),
#	1, Vector3(1,0,0),
#	1, Vector3(1,0,1),
#	1, Vector3(0,0,1),
#	]
#
#	for i in range(0, pos.size(), 2):
#		var v = vdb.create_voxelblock_object_from_def(vdb.voxel_def[pos[i]]);
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
						v = vdb.create_voxelblock_object_from_def(vdb.name_to_def.stone);
					elif (x == z || x == -z):
						v = vdb.create_voxelblock_object_from_def(vdb.name_to_def.stone);
				elif (y == 0): # ground
					v = vdb.create_voxelblock_object_from_def(vdb.name_to_def.grass);
				
				if (v):
					v.scale = Vector3(8,8,8);
					add_child(v);
					v.transform.origin = Vector3(x, y-0.5, z);


func _process(delta):
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
		
		if (s.casual_mode):
			entry_text += " [Standard]";
		else:
			entry_text += " [Sportive]";
		
		savegame_item_list.add_item(entry_text);
		
	if (savegame_list.size() > 0):
		savegame_item_list.select(0);


var load_game_panel : Panel = null;
var new_game_panel : Panel = null;

var world_name_text_edit : TextEdit = null;
var world_seed_spin_box : SpinBox = null;
var world_generator_option_button : OptionButton = null;
var sportive_mode_check_box : CheckBox = null;

func _create_new_game_menu():
	load_game_panel =  $MainMenu.find_node("LoadGamePanel", true, false);
	new_game_panel =  $MainMenu.find_node("NewGamePanel", true, false);
	
	
	load_game_panel.visible = true;
	new_game_panel.visible = false;

	
	world_name_text_edit = $MainMenu.find_node("TextEdit_WorldName", true, false);
	world_seed_spin_box = $MainMenu.find_node("SpinBox_WorldSeed", true, false);
	world_generator_option_button = $MainMenu.find_node("OptionButton_WorldGenerator", true, false);
	sportive_mode_check_box = $MainMenu.find_node("CheckBox_SportiveMode", true, false);

	world_generator_option_button.add_item("TerrainGenerator_V1");


func _ready():
	_create_savegame_list();
	
	_create_new_game_menu();
	
	create_some_blocks();
	info_text_label.set_label_text(info_text);
	changelog_text_label.set_label_text(changelog_text[0]);
	
	_setup_main_menu();
	_setup_statistics();


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


func _on_Button_NewGame_pressed():
	load_game_panel.visible = false;
	new_game_panel.visible = true;


func _on_Button_BackFromNewGame_pressed():
	load_game_panel.visible = true;
	new_game_panel.visible = false;


func _on_Button_StartNewGame_pressed():
	vdb.startup_settings.save_file_infix = vdb.persistence_get_next_free_save_filename_infix();
	vdb.startup_settings.reset_start_position = false;
	
	vdb.startup_settings.generator_seed = int(world_seed_spin_box.value);
	vdb.startup_settings.generator_name = world_generator_option_button.get_item_text(world_generator_option_button.get_selected_id());
	vdb.startup_settings.world_name = world_name_text_edit.text;
	vdb.startup_settings.load_game = false;
	vdb.startup_settings.casual_mode = !sportive_mode_check_box.pressed;
	_start_game();
