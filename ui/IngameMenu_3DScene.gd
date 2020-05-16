extends Spatial

var _ingame_menu_ui = null;

func toggle_visible():
	visible = !visible;
	
	if (visible):
		_ingame_menu_ui._update_from_settings();
		global_transform.origin = vr.vrCamera.global_transform.origin;
		global_transform.basis = Basis(Vector3(0,1,0), vr.vrCamera.global_transform.basis.get_euler().y);
	
	$OQ_UI2DLogWindow.visible = vdb.gameplay_settings.show_debug_console;
	
func _ready():
	
	_ingame_menu_ui = find_node("IngameMenu_MainUI", true, false);
	
	if (_ingame_menu_ui == null):
		vr.log_error("Could not find _ingame_menu_ui");



func _process(_dt):
	if (!visible): return;
	
	$OQ_UI2DLogWindow.visible = vdb.gameplay_settings.show_debug_console;
	
	if visible && (global_transform.origin - vr.vrCamera.global_transform.origin).length_squared() > 4:
		toggle_visible();
	

