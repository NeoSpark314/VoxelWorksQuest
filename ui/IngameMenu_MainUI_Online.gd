extends Panel

onready var _login_status_label = $TabContainer/Login/LoginStatusMessage_Label;

onready var _login_email_line_edit = $TabContainer/Login/LoginEMail_LineEdit;
onready var _login_password_line_edit = $TabContainer/Login/Login_Password_LineEdit;
onready var _login_name_line_edit = $TabContainer/Login/LoginName_LineEdit;
onready var _login_http = $TabContainer/Login/Login_HTTPRequest;

onready var _register_http = $TabContainer/Login/Register_HTTPRequest;
onready var _register_status_label = $TabContainer/Register/Register_StatusMessage_Label;

func _ready():
	_update_from_settings();
	
	if (Firebase.is_user_logged_in()):
		_login_status_label.text = "Logged in";
	else:
		_login_status_label.text = "Not logged in";
	

func _update_from_settings():
	_login_email_line_edit.text = vdb.gameplay_settings.online_useremail;
	_login_password_line_edit.text = vdb.gameplay_settings.online_password;
	_login_name_line_edit.text = vdb.gameplay_settings.online_username;
	


func _update_gameplay_settings_from_ui():
	vdb.gameplay_settings.online_useremail = _login_email_line_edit.text ;
	vdb.gameplay_settings.online_username = _login_name_line_edit.text;
	vdb.gameplay_settings.online_password = _login_password_line_edit.text;


func _is_valid_username(name):
	if (name.length() <= 3): return false;
	if (name.length() >= 20): return false;
	return true;

func _on_Login_Button_pressed():
	_login_status_label.text = "Trying to log in...";
	
	if _login_email_line_edit.text.empty() or _login_password_line_edit.text.empty():
		_login_status_label.text = "Please, enter your login email and password"
		return;
		
	_login_name_line_edit.text = _login_name_line_edit.text.trim_prefix(" ").trim_suffix(" ");
		
	if (!_is_valid_username(_login_name_line_edit.text)):
		_login_status_label.text = "Invalid user name. Should be > 3 and < 20 chars."
		return;
		
	_update_gameplay_settings_from_ui();

	Firebase.login(_login_email_line_edit.text, _login_password_line_edit.text, _login_http)
	var result := yield(_login_http, "request_completed") as Array
	# patch the user name; !!TODO: this should happen only on register once implemented
	var response_body := JSON.parse(result[3].get_string_from_ascii());
	if (result[1] != 200):
		_login_status_label.text = "Error: " + response_body.result.error.message;
	else:
		var user_name_path = "shared-worlds-v1/world-description/"+response_body.result.localId+"/user-info.json";
		var user_info = {
			"name" : vdb.gameplay_settings.online_username
		}
		Firebase.patch_json(user_name_path, user_info, _login_http);
		result = yield(_login_http, "request_completed") as Array
		response_body = JSON.parse(result[3].get_string_from_ascii());
		print(response_body.result);
		if (result[1] != 200):
			_login_status_label.text = "Error patching username: " + response_body.result.error.message;
		else:
			_login_status_label.text = "Login sucessful!"


func _on_Register_Button_pressed():
	_register_status_label.text = "Register not yet activated."
	# not yet implemented
	pass # Replace with function body.


#var _share_world_online_http_request = null;
onready var _share_http_request = $TabContainer/Share/Share_HTTPRequest;
onready var _share_status_label = $TabContainer/Share/Share_Status_Label;


func _on_ShareWorldOnline_Button_pressed():
	if (!Firebase.is_user_logged_in()):
		_share_status_label.text = "Not logged in. Can't share world.'"
		return;
		
	var save_data = vdb._get_save_dictionary(vdb.voxel_world_player.persisted_nodes_array);
	var world_uuid = save_data.desc.world_uuid;
	
	var patch_data = {
		"world-data/"+Firebase.user_info.id+"/"+world_uuid+"/data" : Firebase._clean_keys_from_slash(save_data.data),
		"world-description/"+Firebase.user_info.id+"/"+world_uuid+"/desc" : save_data.desc,
	}
	
	var path = "shared-worlds-v1.json";
	vr.log_info("Sharing world data to " + path);
	
	_share_status_label.text = "Uploading world..."
	
	#print(to_json(patch_data));
	
	Firebase.patch_json(path, patch_data, _share_http_request);

	
func _on_Share_HTTPRequest_request_completed(result, response_code, headers, body):
	var notification_text = "";
	var response_body := JSON.parse(body.get_string_from_ascii())
	
	vr.log_info("_on_Share_World_HTTPRequest_request_completed(): " + str(response_code));
	
	if response_code != 200:
		notification_text = "Error: " + response_body.result.error
	else:
		notification_text = "Upload Successfull!"

	_share_status_label.text = notification_text
	#vr.show_notification(notification_text)



