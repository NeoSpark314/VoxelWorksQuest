extends Control

onready var _game_status_label = $TabContainer/Game/Game_Status_Label;
onready var _game_world_name_line_edit = $TabContainer/Game/Game_WorldName_LineEdit;
onready var _game_info_label = $TabContainer/Game/Game_Info_Label;

#call this to set all things inside the ui; should be called when it's getting
# visible
func _update_from_settings():
	
	$TabContainer/Settings/GameplaySettings._update_from_settings();
	$TabContainer/Online._update_from_settings();
	
	_game_world_name_line_edit.text = vdb.world_name;
	
	$TabContainer/Settings/GameplaySettings/General/ShowDebugConsole_CheckBox.pressed = vdb.gameplay_settings.show_debug_console;
	
	_game_info_label.text = """Game Info:
		Mode: %s
		UUID: %s
""" % [vdb.get_game_mode_string(), vdb.world_uuid]
	

	


func _on_Game_Save_Button_pressed():
	if (vdb.voxel_world_player._save_all()):
		_game_status_label.text = "Game Saved";
	else:
		_game_status_label.text = "Error: save currently not possible";


func _on_Game_ExitToMainMenu_Button_pressed():
	_game_status_label.text = "Saving & leaving game...";
	vdb.voxel_world_player._save_all();
	vdb.voxel_world_player._back_to_main_menu();


func _on_Game_WorldName_LineEdit_text_changed(new_text):
	vdb.world_name = new_text;



func _on_ShowDebugConsole_CheckBox_toggled(button_pressed):
	vdb.gameplay_settings.show_debug_console = button_pressed;

