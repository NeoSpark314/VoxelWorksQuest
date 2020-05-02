extends Spatial

var temp_material = preload("res://data/CrackShader.material").duplicate();

const _crack_num_textures = 10;
var tex = preload("res://data/crack_anylength.png");

var _global_hit_position = Vector3();

var _voxel_def = null;

func _ready():
	temp_material.set_shader_param("albedo_texture", tex);
	
	var eps = 1.0/512.0;
	var eps2 = eps/2.0;
	
	$damage_1.init_voxel_cube(temp_material, Vector2(0,0), Vector2(1, 1.0/10.0), 1.0 + eps, -Vector3(eps2,eps2,eps2));


func initialize(voxel_position, hit_position, voxel_block_defs):
	_max_hit_points = voxel_block_defs.stability;
	translation = voxel_position;
	_global_hit_position = hit_position;
	_voxel_def = voxel_block_defs;
	

var _max_hit_points = 3;
var _damage = 0.0;

var _time_until_reset = 3.0;
var _reset_counter = 0.0;

func remove_from_world():
	get_parent().remove_child(self);
	queue_free();
	

func increment_destroy(dmg):
	_damage += dmg;
	_reset_counter = 0.0;
	
	if (_damage >= _max_hit_points):
		self.visible = false; # hide because the voxel is now gone
		var sfx_dug = vdb.play_sfx_dug(_voxel_def, _global_hit_position);
		if (sfx_dug): sfx_dug.connect("finished", self, "remove_from_world"); # but wait for sound to finish playing
		else: remove_from_world();
		return true;

	vdb.play_sfx_dig(_voxel_def, _global_hit_position);
	var tex_offset = floor(_crack_num_textures * (_damage / _max_hit_points)) / _crack_num_textures;
	temp_material.set_shader_param("offset_y", tex_offset);
	return false;


func _process(_dt):
	_reset_counter += _dt;
	if (_reset_counter > _time_until_reset):
		remove_from_world();


