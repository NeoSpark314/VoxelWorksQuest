extends Control

var savegame_item_list : ItemList = null;


var _main_menu_checkbox_reset_start_position : CheckBox = null;
var _main_menu_checkbox_reset_crafting_guide : CheckBox = null;

var _load_game_host_checkbox : CheckBox = null;
var _new_game_host_checkbox : CheckBox = null;

onready var _join_server_ip_address_textedit : TextEdit = $"TabContainer/Online/TabContainer/Join Server/IPAddress_TextEdit";

func _setup_main_menu():
	var label_title = find_node("Label_Title", true, false);
	
	_main_menu_checkbox_reset_start_position = find_node("CheckBox_ResetStartPosition", true, false);
	_main_menu_checkbox_reset_crafting_guide = find_node("CheckBox_ResetCraftingGuide", true, false);
	
	_load_game_host_checkbox = find_node("LoadGame_Host_Checkbox", true, false);
	_new_game_host_checkbox = find_node("NewGame_Host_Checkbox", true, false);

	label_title.set_text(vdb.GAME_NAME + " - " + vdb.GAME_VERSION_STRING);
	
	_join_server_ip_address_textedit.text = vdb.gameplay_settings.last_remote_host;

func _ready():
	_create_savegame_list();
	_create_new_game_menu();
	
	_setup_main_menu();

var savegame_list = null;

func _create_savegame_list():
	savegame_item_list = find_node("SaveGame_ItemList", true, false);
	
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
	load_game_panel = find_node("Load Game", true, false);
	new_game_panel = find_node("New Game", true, false);
	settings_panel = find_node("Settings", true, false);
	
	#load_game_panel.visible = true;
	#new_game_panel.visible = false;
	
	world_name_text_edit = find_node("TextEdit_WorldName", true, false);
	world_seed_spin_box = find_node("SpinBox_WorldSeed", true, false);
	world_generator_option_button = find_node("OptionButton_WorldGenerator", true, false);
	game_mode_option_button = find_node("OptionButton_GameMode", true, false);

	world_generator_option_button.add_item("TerrainGenerator_V1");

	game_mode_option_button.add_item("Standard");
	game_mode_option_button.add_item("Sportive");
	game_mode_option_button.add_item("Creative");
	
func _start_game():
	vr.switch_scene("res://levels/MainWorld.tscn", 0.5);


func _on_Button_LoadGame_pressed():
	if (!savegame_item_list.is_anything_selected()): return;
	
	vdb.reset_startup_settings();

	var sg = savegame_list[savegame_item_list.get_selected_items()[0]];
	vdb.startup_settings.save_file_infix = sg.filename_infix;
	vdb.startup_settings.reset_start_position = _main_menu_checkbox_reset_start_position.pressed;
	vdb.startup_settings.reset_crafting_guide = _main_menu_checkbox_reset_crafting_guide.pressed;
	vdb.startup_settings.load_game = true;
	vdb.startup_settings.host = _load_game_host_checkbox.pressed;
	_start_game();


func _on_Button_StartNewGame_pressed():
	vdb.reset_startup_settings();

	vdb.startup_settings.save_file_infix = vdb.persistence_get_next_free_save_filename_infix();
	vdb.startup_settings.reset_start_position = false;
	
	vdb.startup_settings.generator_seed = int(world_seed_spin_box.value);
	vdb.startup_settings.generator_name = world_generator_option_button.get_item_text(world_generator_option_button.get_selected_id());
	vdb.startup_settings.world_name = world_name_text_edit.text;
	vdb.startup_settings.load_game = false;
	vdb.startup_settings.host = _new_game_host_checkbox.pressed;
	
	#vdb.startup_settings.casual_mode = !sportive_mode_check_box.pressed;
	vdb.startup_settings.game_mode = game_mode_option_button.get_selected_id();
	
	_start_game();



func _on_JoinServer_Join_Button_pressed():
	vdb.reset_startup_settings();
	
	# save the last entered ip for next start
	vdb.gameplay_settings.last_remote_host = _join_server_ip_address_textedit.text;
	
	vdb.startup_settings.remote_host = _join_server_ip_address_textedit.text;

	_start_game();
