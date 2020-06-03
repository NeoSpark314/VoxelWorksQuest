extends Panel

onready var _join_server_ip_address_textedit : TextEdit = $"TabContainer/Join Server/IPAddress_TextEdit";


onready var _user_item_list := $"TabContainer/Visit World/VisitWorld_User_ItemList";
onready var _world_list := $"TabContainer/Visit World/VisitWorld_World_ItemList";
onready var _user_http := $"TabContainer/Visit World/Refresh_User_HTTPRequest";
onready var _world_http := $"TabContainer/Visit World/Refresh_World_HTTPRequest";
onready var _loadandplay_http := $"TabContainer/Visit World/LoadAndPlay_World_HTTPRequest";
onready var _vw_status := $"TabContainer/Visit World/VisitWorld_Status_Label";

onready var _visit_world_host_checkbox := $"TabContainer/Visit World/VisitWorld_Host_Checkbox";


#var _selected_user = null;

var _loaded_user_list = [];
var _loaded_world_list = [];
var _loaded_info = {}; # full loaded dicitonary

func _ready():
	_join_server_ip_address_textedit.text = vdb.gameplay_settings.last_remote_host;

	_update_user_list();
	

func _on_VisitWorld_RefreshList_Button_pressed():
	_user_item_list.clear();
	_world_list.clear();
	_loaded_user_list.clear();
	_loaded_info.clear();
	
	_vw_status.text = "Requesting User List";
	Firebase.load_json("shared-worlds-v1/world-description.json", _user_http);


func _update_user_list():
	for user_key in _loaded_info.keys():
		var user = _loaded_info[user_key] as Dictionary;
		
		if (user.size() <= 1): continue; # no shared worlds yet
		
		_user_item_list.add_item(user["user-info"].name);
		_loaded_user_list.push_back(user_key);
		

func _on_Refresh_User_HTTPRequest_request_completed(result, response_code, headers, body):
	var response_body := JSON.parse(body.get_string_from_ascii())
	if response_code != 200:
		_vw_status.text = "Request User List Error: " + response_body.result.error
	else:
		_vw_status.text = "Success requesting user list"
		print(response_body.result);
		
		_loaded_info = response_body.result;
		_update_user_list();

			

func _on_VisitWorld_User_ItemList_item_selected(index):
	_loaded_world_list.clear();
	_world_list.clear();
	var user_info = _loaded_info[_loaded_user_list[index]];
	
	for k in user_info.keys():
		if k == "user-info": continue;
		var e = user_info[k];
		_world_list.add_item(e.desc.world_name);
		_loaded_world_list.push_back(k);


var _visit_user_id = "";
var _visit_world_id = "";

func _on_VisitWorld_Visit_Button_pressed():
	var u = _user_item_list.get_selected_items();
	var w = _world_list.get_selected_items();
	
	if (u.size() == 0):
		_vw_status.text = "Error: No User Selected";
		return;
	if (w.size() == 0):
		_vw_status.text = "Error: No World Selected";
		return;
		
	_visit_user_id = _loaded_user_list[u[0]];
	_visit_world_id = _loaded_world_list[w[0]];
	
	Firebase.load_json("shared-worlds-v1/world-data/"+ _visit_user_id + "/"+_visit_world_id+".json", _loadandplay_http);


func _on_LoadAndPlay_World_HTTPRequest_request_completed(result, response_code, headers, body):
	var response_body := JSON.parse(body.get_string_from_ascii())
	if response_code != 200:
		_vw_status.text = "Request World Error: " + response_body.result.error
	else:
		_vw_status.text = "Success loading world"
		
		vdb.reset_startup_settings();
		
		# now build the full world data (desc and data in dictionary) from the now
		# loaded world + the previously loaded desc data store din _loaded_info
		vdb.startup_settings.world_dict = {
			"desc" : _loaded_info[_visit_user_id][_visit_world_id].desc,
			"data" : Firebase._restore_keys(response_body.result.data)
		}
		vdb.startup_settings.save_file_infix = "last_visited_world";
		
		vdb.startup_settings.world_dict.desc.world_name = "Last Visited World: " + vdb.startup_settings.world_dict.desc.world_name;
		
		vdb.startup_settings.host = _visit_world_host_checkbox.pressed;
		vdb.startup_settings.save_enabled = false;
		

		vr.switch_scene("res://levels/MainWorld.tscn", 0.5);


func _on_Update_HTTPRequest_request_completed(result, response_code, headers, body):
	var response_body := JSON.parse(body.get_string_from_ascii())
	if response_code != 200:
		_vw_status.text = "Update Error: " + response_body.result.error
	else:
		pass;


func _on_JoinServer_Join_Button_pressed():
	vdb.reset_startup_settings();
	
	# save the last entered ip for next start
	vdb.gameplay_settings.last_remote_host = _join_server_ip_address_textedit.text;
	vdb.save_gameplay_settings();
	
	vdb.startup_settings.remote_host = _join_server_ip_address_textedit.text;
	vdb.startup_settings.save_enabled = false;
	
	vr.switch_scene("res://levels/MainWorld.tscn", 0.5);
