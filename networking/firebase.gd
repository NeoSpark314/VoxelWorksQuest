extends Node

var API_KEY : String = preload("app_id.gd").new().id;
const PROJECT_ID := "voxel-works-quest";


var REGISTER_URL := "https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=%s" % API_KEY
var LOGIN_URL := "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=%s" % API_KEY
#const FIRESTORE_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/" % PROJECT_ID

const FIREBASE_URL := "https://voxel-works-quest.firebaseio.com/"

var current_token := ""

var user_info := {
	"token": null,
	"id": "no_user_id"
}

func is_user_logged_in():
	return user_info.token != null;


func _get_user_info(result: Array) -> Dictionary:
	var result_body := JSON.parse(result[3].get_string_from_ascii()).result as Dictionary
	return {
		"token": result_body.idToken,
		"id": result_body.localId
	}


func _get_request_headers() -> PoolStringArray:
	return PoolStringArray([
		"Content-Type: application/json",
	])


func register(email: String, password: String, http: HTTPRequest) -> void:
	var body := {
		"email": email,
		"password": password,
	}
	http.request(REGISTER_URL, [], false, HTTPClient.METHOD_POST, to_json(body))
	var result := yield(http, "request_completed") as Array
	if result[1] == 200:
		user_info = _get_user_info(result)


func login(email: String, password: String, http: HTTPRequest) -> void:
	var body := {
		"email": email,
		"password": password,
		"returnSecureToken": true
	}
	http.request(LOGIN_URL, [], false, HTTPClient.METHOD_POST, to_json(body))
	var result := yield(http, "request_completed") as Array
	if result[1] == 200:
		user_info = _get_user_info(result)



func _restore_keys(data_dict: Dictionary):
	for k in data_dict.keys():
		if (data_dict[k] is Dictionary):
			data_dict[k] = _restore_keys(data_dict[k]);
			
		if (k.begins_with("~")):
			var new_k = NodePath(k.replace("~", "/"));
			data_dict[new_k] = data_dict[k];
			data_dict.erase(k);
			
	return data_dict;


func _clean_keys_from_slash(data_dict: Dictionary):
	for k in data_dict.keys():
		
		#recursively clean keys
		if (data_dict[k] is Dictionary):
			data_dict[k] = _clean_keys_from_slash(data_dict[k]);
		
		# a node path will contain / so we replace it here with ~
		if (k is NodePath):
			var new_k = str(k).replace("/", "~");
			data_dict[new_k] = data_dict[k];
			data_dict.erase(k);
	return data_dict;

func load_shallow_json(path: String, http: HTTPRequest) -> void:
	var auth = "";
	if (user_info.token): auth = "&auth=" + user_info.token;

	var url = FIREBASE_URL + path + "?shallow=true" + auth;
	vr.log_info("load_shallow_json(): " + url);
	http.request(url, _get_request_headers(), false, HTTPClient.METHOD_GET)


func load_json(path: String, http: HTTPRequest) -> void:
	var auth = "";
	if (user_info.token): auth = "?auth=" + user_info.token;
	
	var url = FIREBASE_URL + path + auth
	vr.log_info("load_json(): " + url);
	http.request(url, _get_request_headers(), false, HTTPClient.METHOD_GET)


func patch_json(path: String, data: Dictionary, http: HTTPRequest) -> void:
	var auth = "";
	if (user_info.token): auth = "?auth=" + user_info.token;

	var body := to_json(data);
	var url = FIREBASE_URL + path + auth;
	#print(body);
	http.request(url, _get_request_headers(), false, HTTPClient.METHOD_PATCH, body)
