# This creates a mesh instance by voxelizing the pixels of a given image
# 
extends MeshInstance

var _material = preload("VoxelizedImageMeshInstance.material")

const CUBE_VERTICES = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(1.0, 0.0, 1.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, 1.0, 1.0),
	Vector3(1.0, 1.0, 1.0),
	Vector3(1.0, 1.0, 0.0)
];

const CUBE_NORMALS = [
	Vector3(-1.0, 0.0, 0.0), # left 0
	Vector3(1.0, 0.0, 0.0),  # right 1
	Vector3(0.0, 0.0, -1.0), # bottom 2
	Vector3(0.0, 0.0, 1.0),  # top 3
	Vector3(0.0, 1.0, 0.0),  # back 4
	Vector3(0.0,-1.0, 0.0),  # front 5
]

#			   4----7
#			  /|   /|
#			 5----6 |
#			 | 0--|-3
#			 |/   |/
#			 1----2
# this is the order to match the godot voxel plugin
#                            /*Left*/     /*right*/    /*bottom*/   /*top*/      /*back*/      /*front*/
const CUBE_VERTEX_INDICES = [4, 5, 1, 0,  6, 7, 3, 2,  0, 1, 2, 3,  6, 5, 4, 7,  7, 4, 0, 3,   5, 6, 2, 1];

var _base_index = 0;
var _create_collision = false;
var _collision_shapes = [];

var minVertexPos = Vector3(1e20,1e20,1e20);
var maxVertexPos = Vector3(-1e20,-1e20,-1e20);


var center_offset := Vector3();
func _vector_min(a, b):
	return Vector3(min(a.x, b.x), min(a.y, b.y), min(a.z, b.z));
func _vector_max(a, b):
	return Vector3(max(a.x, b.x), max(a.y, b.y), max(a.z, b.z));

func _helper_get_cube_vertex(i, scale, offset):
	var v = CUBE_VERTICES[CUBE_VERTEX_INDICES[i]] * scale + offset;
	
	minVertexPos = _vector_min(v, minVertexPos);
	maxVertexPos = _vector_max(v, maxVertexPos);
	
	return v;

# !!TODO: add only the faces that are visible here!!
func _add_cube(st : SurfaceTool, _color : Color, scale, offset):
	for i in range(0, 6*4):
		st.add_normal(CUBE_NORMALS[i / 4]);
		st.add_color(_color)
		st.add_vertex(_helper_get_cube_vertex(i, scale, offset));

	for i in range(_base_index, _base_index + 6 * 4, 4):
		st.add_index(0+i);
		st.add_index(1+i);
		st.add_index(2+i);
		st.add_index(0+i);
		st.add_index(2+i);
		st.add_index(3+i);

#   not supported yet by default 
#	if (_create_concave_collision):
#		for i in range(0, 6 * 4, 4):
#			_concave_collision_faces.append(_helper_get_cube_vertex(0+i, scale, offset));
#			_concave_collision_faces.append(_helper_get_cube_vertex(1+i, scale, offset));
#			_concave_collision_faces.append(_helper_get_cube_vertex(2+i, scale, offset));
#			_concave_collision_faces.append(_helper_get_cube_vertex(0+i, scale, offset));
#			_concave_collision_faces.append(_helper_get_cube_vertex(2+i, scale, offset));
#			_concave_collision_faces.append(_helper_get_cube_vertex(3+i, scale, offset));

		
	_base_index += 6 * 4;
		
		
#func init_voxel_cube(_material, uv_offset = Vector2(0,0), uv_scale = Vector2(1,1), mesh_scale = 1.0, mesh_offset = Vector3(0,0,0)):
func voxelize_from_image(image : Image, px, py, sx, sy, size_scale, center_px):
	var st = SurfaceTool.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	image.lock();
	
	#NOTE: we rotate the image here 90degree to the left (by swapping x, y)
	center_offset = Vector3(0.0, center_px.x * size_scale, center_px.y * size_scale);
	
	#var vertex_min = Vector3(-1e20,-1e20,-1e20);
	#var vertex_max = Vector3(1e20,1e20,1e20);
	var minPixPos = Vector2(sx, sy);
	var maxPixPos = Vector2(0, 0);
	
	for y in range(0, sx):
		for x in range(0, sy):
			var c = image.get_pixel(px+x, py+y);
			if (c.a == 1.0):
				minPixPos.x = min(x, minPixPos.x);
				minPixPos.y = min(x, minPixPos.y);
				maxPixPos.x = max(x, maxPixPos.x);
				maxPixPos.y = max(x, maxPixPos.y);
				
				var pos = Vector3(0.0, x*size_scale, y*size_scale) - center_offset;
				_add_cube(st, c, size_scale, pos);
				
#				This creates a box collision for all objects; but resulted in very unstable physics behaviour
#               needs more tweaking and understanding of godot bullet I think
#				if (_create_collision):
#					var box : BoxShape = BoxShape.new();
#					box.extents = Vector3(0.5, 0.5, 0.5) * size_scale;
#					var coll = CollisionShape.new();
#					coll.transform.origin = pos + box.extents;
#					coll.shape = box;
#					_collision_shapes.append(coll);
					
	

	image.unlock();
	# Commit to a mesh.
	mesh = st.commit()
	# for now a simple box shape for collisions
	if (_create_collision):
		var box : BoxShape = BoxShape.new();
		box.extents = (maxVertexPos - minVertexPos) * 0.5;
		var coll = CollisionShape.new();
		coll.transform.origin = (maxVertexPos + minVertexPos) * 0.5;
		coll.shape = box;
		_collision_shapes.append(coll);
	
	#transform.origin = -(maxVertexPos + minVertexPos) * 0.5;
	
	mesh.surface_set_material(0, _material);
	#set_material_override(_material);
	
	
func create_mesh_from_imagedata(img, x, y, sx, sy, size_scale = 0.5/16.0, center_pixel = Vector2(0, 0), create_collision = false):
	#var img = load(filename).get_data();
	if (create_collision):
		_create_collision = true;
	voxelize_from_image(img, x, y, sx, sy, size_scale, center_pixel);
	return _collision_shapes;


func _ready():
	#create_mesh_from_imagefile("res://data/default_tool_stonepick.png");
	pass;
