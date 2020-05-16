extends TabContainer

onready var ob_turn_mode : OptionButton = $"Standard/OptionButton_TurnMode";
onready var label_turn_value : Label = $"Standard/TurnSettings/Label_TurnValue";
onready var label_stick_speedmultiplier_value : Label = $"Standard/SpeedSettings/Label_SpeedValue";

func _ready():
	if (_check_required_permissions()):
		_create_TextureSetList();

	
	ob_turn_mode.add_item("Click");
	ob_turn_mode.add_item("Smooth");
	
	_update_from_settings();
	
	
	
func _update_from_settings():
	var s = vdb.gameplay_settings;
	
	set_tab_disabled(1, (vdb.game_mode == vdb.GAME_MODE.SPORTIVE));
	
	ob_turn_mode.select(s.stick_locomotion_turn_mode);
	
	# Settings for turn angle / turn speed depending on selected mode
	$"Standard/TurnSettings/Label_ClickTurnAngle".visible = false;
	$"Standard/TurnSettings/Label_SmoothTurnSpeed".visible = false;
	if (s.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.CLICK):
		$"Standard/TurnSettings/Label_ClickTurnAngle".visible = true;
		label_turn_value.set_text(str(s.stick_locomotion_click_turn_angle));
	elif (s.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.SMOOTH):
		$"Standard/TurnSettings/Label_SmoothTurnSpeed".visible = true;
		label_turn_value.set_text(str(s.stick_locomotion_smooth_turn_speed));
		
	label_stick_speedmultiplier_value.set_text("%1.1f" % s.stick_locomotion_speed_multiplier);
		
	$General/Button_ToolbeltRequireButton.pressed = s.toolbelt_require_second_button;
	$General/Button_LeftHanded.pressed = s.left_handed;
	
	$General/HeightOffsetSetting/Label_HeightOffsetValue.set_text(str(s.player_height_offset)+"m");
	
	$General/CheckBox_EnableMixedRealityCapture.pressed = vdb.gameplay_settings.enable_mixed_reality_capture


func _notify_and_update():
	vdb.notify_gameplay_settings_changed();
	_update_from_settings();
	


func _on_OptionButton_TurnMode_item_selected(id):
	vdb.gameplay_settings.stick_locomotion_turn_mode = id;
	_notify_and_update();

func _on_Button_TurnPlus_pressed():
	if (vdb.gameplay_settings.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.CLICK):
		vdb.gameplay_settings.stick_locomotion_click_turn_angle += 10;
		if (vdb.gameplay_settings.stick_locomotion_click_turn_angle > 180):
			vdb.gameplay_settings.stick_locomotion_click_turn_angle = 180;
	
	if (vdb.gameplay_settings.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.SMOOTH):
		vdb.gameplay_settings.stick_locomotion_smooth_turn_speed += 30;
		if (vdb.gameplay_settings.stick_locomotion_smooth_turn_speed > 360):
			vdb.gameplay_settings.stick_locomotion_smooth_turn_speed = 360;
	_notify_and_update();


func _on_Button_TurnMinus_pressed():
	if (vdb.gameplay_settings.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.CLICK):
		vdb.gameplay_settings.stick_locomotion_click_turn_angle -= 10;
		if (vdb.gameplay_settings.stick_locomotion_click_turn_angle < 10):
			vdb.gameplay_settings.stick_locomotion_click_turn_angle = 10;
	
	if (vdb.gameplay_settings.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.SMOOTH):
		vdb.gameplay_settings.stick_locomotion_smooth_turn_speed -= 30;
		if (vdb.gameplay_settings.stick_locomotion_smooth_turn_speed < 30):
			vdb.gameplay_settings.stick_locomotion_smooth_turn_speed = 30;
	_notify_and_update();
	
func _on_Button_SpeedMinus_pressed():
	vdb.gameplay_settings.stick_locomotion_speed_multiplier -= 0.125;
	
	if (vdb.gameplay_settings.stick_locomotion_speed_multiplier < 1.0):
		vdb.gameplay_settings.stick_locomotion_speed_multiplier = 1.0;
		
	_notify_and_update();

func _on_Button_SpeedPlus_pressed():
	vdb.gameplay_settings.stick_locomotion_speed_multiplier += 0.125;

	if (vdb.gameplay_settings.stick_locomotion_speed_multiplier > 2.0):
		vdb.gameplay_settings.stick_locomotion_speed_multiplier = 2.0;
	_notify_and_update();



func _on_Button_ToolbeltRequireButton_toggled(button_pressed):
	var s = vdb.gameplay_settings;
	s.toolbelt_require_second_button = $General/Button_ToolbeltRequireButton.pressed;
	_notify_and_update();


func _on_Button_LeftHanded_toggled(button_pressed):
	var s = vdb.gameplay_settings;
	s.left_handed = $General/Button_LeftHanded.pressed;
	_notify_and_update();


func _on_Button_HeightOffsetVPlus_pressed():
	var s = vdb.gameplay_settings;
	s.player_height_offset += 0.1;
	if (s.player_height_offset > 0.5): s.player_height_offset = 0.5;
	_notify_and_update();


func _on_Button_HeightOffsetVMinus_pressed():
	var s = vdb.gameplay_settings;
	s.player_height_offset -= 0.1;
	if (s.player_height_offset < 0.0): s.player_height_offset = 0.0;
	_notify_and_update();
	
	
	


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
	
	vdb.gameplay_settings.custom_terrain_block_texture_item = index;

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

	var terrain_block_textures_item_list : ItemList = find_node("TerrainBlockTextures_ItemList", true, false);
	terrain_block_textures_item_list.clear()

	for s in terrain_blocks_name_list:
		terrain_block_textures_item_list.add_item(s);
		
	if (vdb.gameplay_settings.custom_terrain_block_texture_item <= terrain_blocks_name_list.size()):
		terrain_block_textures_item_list.select(vdb.gameplay_settings.custom_terrain_block_texture_item);
		_on_TerrainBlockTextures_ItemList_item_selected(vdb.gameplay_settings.custom_terrain_block_texture_item);


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



func _on_CheckBox_EnableMixedRealityCapture_toggled(button_pressed):
	vdb.gameplay_settings.enable_mixed_reality_capture = $General/CheckBox_EnableMixedRealityCapture.pressed;
	_notify_and_update();
