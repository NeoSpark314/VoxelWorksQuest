extends Spatial


var temp_material = preload("res://data/CrackShader.material").duplicate();
const _num_textures = 8;
var tex = preload("res://data/fire_basic_flame_animated.png");


func _ready():
	temp_material.set_shader_param("albedo_texture", tex);


func _process(_dt):
	var tex_offset = floor(_num_textures * 0.0) / _num_textures;
	temp_material.set_shader_param("offset_y", tex_offset);

