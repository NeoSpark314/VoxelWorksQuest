extends Spatial

var active_controller : ARVRController = null;

var _left_ui_raycast = null;
var _right_ui_raycast = null;

onready var label = $UITransform/OQ_UILabel_JogDistance;

const VISIBLE_TIME=1.0;
const VISIBLE_DIST_THRESHOLD=0.5;
const VISIBLE_ANGLE_THRESHOLD=0.75;
var _visibility_timer = 0.0;

var _button_switch_panel : Button = null;



func _update_label_text():
	var distance = vdb.global_statistics.traveled_distance - vdb.session_start_statistics.traveled_distance;
	var km = int(floor(distance / 1000));
	var m = int(floor(distance - km * 1000));
	
	var calories = int(round(vdb.calculate_approximated_calories(distance)));
	
	var p = vr.vrCamera.global_transform.origin;
	
	#label.set_label_text("Jogged: %dkm %3dm\n~ Calories: %d" % [km, m, calories]);
	label.set_label_text("""Jogged: %dkm %3dm
	World Position: %d %d %d
	Health 100/100""" % [km, m, 
	int(p.x), int(p.y), int(p.z)]);


func _process(dt):
	if (visible && active_controller):
		global_transform = active_controller.get_ui_transform();


func _check_and_make_visible(controller : ARVRController):
	if (active_controller): 
		_update_label_text();
		controller = active_controller;
	
	var trafo : Transform = controller.get_ui_transform();

	var dir_to_head = vr.vrCamera.global_transform.origin - trafo.origin;
	var distance_to_head = dir_to_head.length();
	
	if (distance_to_head < VISIBLE_DIST_THRESHOLD):
		var angle_to_head = dir_to_head.dot(-trafo.basis.x) / distance_to_head;
		
		if (!vr.inVR || angle_to_head > VISIBLE_ANGLE_THRESHOLD):
			active_controller = controller;
			_visibility_timer = VISIBLE_TIME;
			return true;
	return false;


func _check_and_process_process(_dt):
	_visibility_timer -= _dt;
	
	if (_check_and_make_visible(vr.leftController)):
		_left_ui_raycast.visible = false;
		_right_ui_raycast.visible = true;
	elif (_check_and_make_visible(vr.rightController)):
		_left_ui_raycast.visible = true;
		_right_ui_raycast.visible = false;
		
	
	visible = _visibility_timer > 0.0;
	if (!visible): 
		_right_ui_raycast.visible = false;
		_left_ui_raycast.visible = false;
		active_controller = null;
		return;


var _visible_ui_panel = 0;

func _set_visible_panel():
	for c in $UITransform.get_children():
		c.visible = false;
	$UITransform.get_child(_visible_ui_panel).visible = true;

func _switch_panel_pressed():
	_visible_ui_panel = (_visible_ui_panel + 1) % $UITransform.get_child_count();
	_set_visible_panel();
		
	
	
	pass;

func _ready():
	
	_button_switch_panel = $OQ_UI2D_SwitchPanelUI.find_node("Button_SwitchPanel", true, false);
	
	if (!_button_switch_panel):
		vr.log_error("_button_switch_panel not found in HUD!");
	else:
		_button_switch_panel.connect("pressed", self, "_switch_panel_pressed");
		
	_left_ui_raycast = vr.leftController.find_node("Feature_UIRayCast", true, false);
	_right_ui_raycast = vr.rightController.find_node("Feature_UIRayCast", true, false);
	
	if (_left_ui_raycast == null): vr.log_error("ArmUserInterface: can't fine left ui raycast!");
	if (_right_ui_raycast == null): vr.log_error("ArmUserInterface: can't fine right ui raycast!");

	_set_visible_panel();
