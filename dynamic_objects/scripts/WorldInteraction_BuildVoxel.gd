extends Spatial

var _global_hit_position = Vector3();
var _voxel_def = null;

var _voxel_object = null;

func initialize(voxel_position, hit_position, voxel_block_defs):
	translation = voxel_position;
	_global_hit_position = hit_position;
	_voxel_def = voxel_block_defs;
	
	# we want only the mesh here; a full object would be grabbable
	_voxel_object = vdb.create_voxel_mesh_from_def(voxel_block_defs);
	
	# we need to reset the mesh here as it has the moved values from the
	# object creation still
	#_voxel_object.scale = Vector3(1, 1, 1);
	#_voxel_object.transform.origin = Vector3(0, 0,0);
	
	$VoxelContainer.add_child(_voxel_object);


var _time_until_reset = 3.0;
var _reset_counter = 0.0;

var _num_build_steps = 3.0;
var _build_step = 0.0;

func remove_from_world():
	get_parent().remove_child(self);
	queue_free();
	

func increment_build():
	_reset_counter = 0.0;
	
	_build_step = _build_step + 1;
	
	if (_build_step >= _num_build_steps):
		self.visible = false; # hide because the voxel is now gone
		var sfx_place = vdb.play_sfx_place(_voxel_def, _global_hit_position);
		if (sfx_place): sfx_place.connect("finished", self, "remove_from_world"); # but wait for sound to finish playing
		else: remove_from_world();
		return true;
	
	vdb.play_sfx_build(_voxel_def, _global_hit_position);
	return false;
	
#


func _process(_dt):
	_reset_counter += _dt;
	
	var s = 8.0 * (_build_step / _num_build_steps) * (_time_until_reset - _reset_counter) / _time_until_reset;
	#s = 1.0;
	$VoxelContainer.scale = Vector3(s, s, s);
	#scale = Vector3(s, s, s);
	
	if (_reset_counter > _time_until_reset):
		remove_from_world();
