extends Spatial

var _game;

onready var _anim := $AnimationPlayer;
onready var _area := $MeshTransformNode/Area;


var _state_timer = 0.0;

func initialize_npc(game):
	_game = game;

func _ready():
	_anim.play("Idle");
	pass # Replace with function body.
	
	
# this function should be called 
func hit_with_something():
	_anim.play("Hurt");
	_state_timer = 1.0;
	pass;
	
func get_state():
	return _anim.current_animation;


func _transition_state(_dt):
	var dir_to_player = vr.vrCamera.global_transform.origin - global_transform.origin;
	var distance_to_player = dir_to_player.length();

	if (get_state() == "Hurt"):
		_state_timer -= _dt;
		if (_state_timer > 0.0): # we stay in this state
			return;
	
	if (distance_to_player > 16.0):
		_anim.play("Idle");
	elif (distance_to_player > 0.2):
		_anim.play("Follow");
	

	
func _process(_dt):
	var dir_to_player = vr.vrCamera.global_transform.origin - global_transform.origin;
	
	_transition_state(_dt);
	var state = get_state();
	
	
	if (state == "Hurt"):
		global_translate(global_transform.basis.z * _dt * 4.0);
	
	if (state == "Follow"):
		var at = vr.vrCamera.global_transform.origin;
		at.y = global_transform.origin.y;
		look_at(at, Vector3(0,1,0));
		global_translate(dir_to_player.normalized() * _dt);
	



func _on_Area_area_entered(area):
	hit_with_something();
	pass # Replace with function body.
