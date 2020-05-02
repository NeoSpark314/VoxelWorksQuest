extends TabContainer

onready var ob_turn_mode : OptionButton = $"Standard/OptionButton_TurnMode";
onready var label_turn_value : Label = $"Standard/TurnSettings/Label_TurnValue";
onready var label_stick_speedmultiplier_value : Label = $"Standard/SpeedSettings/Label_SpeedValue";





func _ready():
	
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
		
	$General/Button_ToolbeltRequireButton.pressed = s.toolbelt_require_second_button
	
	

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


