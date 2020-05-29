extends "Object_Item.gd"


var _enter_area : Area = null;

var _local_start_position := Vector3(0,0,0);

var label_result : Label = null;
var label_page : Label = null;
var label_requires : Label = null;
var label_items := [];


func _ready():
	
	label_result = $OQ_UI2DCanvas.find_node("Result", true, false);
	label_page = $OQ_UI2DCanvas.find_node("PageMarker", true, false);
	label_requires = $OQ_UI2DCanvas.find_node("Requires", true, false);
	
	for i in range(1, 10):
		label_items.append($OQ_UI2DCanvas.find_node("Item_1_%d"%i, true, false));
	
	_num_pages = vdb._crafting_recipies.size();
	
	update_page();


const _min_trigger_distance = 0.15;
var _distance_left = 0.0;
var _distance_right = 0.0;

var _display_page = 0;
var _num_pages = 1;

var _grabbing_controller = null;

# todo controller param
func get_grab_object(controller):
	_grabbing_controller = controller;
	return self;

func release_grab(controller):
	_grabbing_controller = null;


func _pretty_format_name(s : String):
	return s.replace("cg_", "").replace("tg_", "").replace("_", " ");


func update_page():
	var r = vdb._crafting_recipies[_display_page];
	
	for l in label_items:
		l.set_text("");
		
	if (r.input.size() == 1):
		label_items[4].set_text(_pretty_format_name(r.input[0]));
	elif (r.input.size() == 9):
		for i in range(0, 9):
			label_items[i].set_text(_pretty_format_name(r.input[i]));
			
	label_result.set_text("Result: " + _pretty_format_name(r.output[0]));
	
	
	var requirements = str(r.crafttable_requirements);
	
	if (r.tool_requirements):
		requirements += "; " + str(r.tool_requirements);
	
	
	label_requires.set_text(_pretty_format_name(requirements));
	
	
	label_page.set_text("Page %2d/%2d" % [_display_page+1, _num_pages]);
	
	
	
	
	#$RecipeLabel.set_label_text("Page %d" % _display_page);
	#$RecipeLabel.set_label_text(pages[0]);

func trigger_right():
	_display_page = (_display_page+1) % _num_pages;
	update_page();

func trigger_left():
	_display_page = (_display_page+_num_pages-1) % _num_pages;
	update_page();

func _physics_process(_dt):
	if (_grabbing_controller != null):
		if (_grabbing_controller._button_just_pressed(vr.CONTROLLER_BUTTON.XA)):
			trigger_left();
		if (_grabbing_controller._button_just_pressed(vr.CONTROLLER_BUTTON.YB)):
			trigger_right();
	
	if (_enter_area != null):
		var delta_pos = to_local(_enter_area.global_transform.origin) - _local_start_position;
		_local_start_position = to_local(_enter_area.global_transform.origin);
		
		if (delta_pos.x < 0): _distance_left -= delta_pos.x;
		if (delta_pos.x > 0): _distance_right += delta_pos.x;
		
		#vr.show_dbg_info(name, str(_distance_left) + ", " + str(_distance_right));
		
		if (_distance_right > _min_trigger_distance):
			trigger_right();
			_distance_left = -_min_trigger_distance;
			_distance_right = 0.0;
		if (_distance_left > _min_trigger_distance):
			trigger_left();
			_distance_left = 0.0;
			_distance_right = -_min_trigger_distance;


# let's hope it works out to always track the last area that entered
func _on_Geometry_area_entered(area : Area):
	_enter_area = area;
	_local_start_position = to_local(area.global_transform.origin);


func _on_Geometry_area_exited(area):
	if (area == _enter_area):
		_enter_area = null;
		_distance_left = 0.0;
		_distance_right = 0.0;
