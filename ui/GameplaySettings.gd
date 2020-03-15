extends TabContainer

onready var ob_turn_mode : OptionButton = $"Standard/OptionButton_TurnMode";
onready var label_turn_value : Label = $"Standard/Label_TurnValue";





func _ready():
	
	ob_turn_mode.add_item("Click");
	ob_turn_mode.add_item("Smooth");
	
	_update_from_settings();
	
	
	
func _update_from_settings():
	var s = vdb.gameplay_settings;
	
	set_tab_disabled(1, !vdb.casual_mode);
	
	ob_turn_mode.select(s.stick_locomotion_turn_mode);
	
	$"Standard/Label_ClickTurnAngle".visible = false;
	$"Standard/Label_SmoothTurnSpeed".visible = false;
	if (s.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.CLICK):
		$"Standard/Label_ClickTurnAngle".visible = true;
		label_turn_value.set_text(str(s.stick_locomotion_click_turn_angle));
	elif (s.stick_locomotion_turn_mode == vr.LocomotionStickTurnType.SMOOTH):
		$"Standard/Label_SmoothTurnSpeed".visible = true;
		label_turn_value.set_text(str(s.stick_locomotion_smooth_turn_speed));
		

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
