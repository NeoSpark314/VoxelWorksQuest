# A single cube as mesh instance creates from init_voxel_cube
extends MeshInstance

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

const CUBE_UVS = [
	Vector2(0.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(1.0, 1.0),
	Vector2(0.0, 1.0)
];

const CUBE_NORMALS = [
	Vector3(-1.0, 0.0, 0.0), # left 0
	Vector3(1.0, 0.0, 0.0),  # right 1
	Vector3(0.0, -1.0, 0.0), # bottom 2
	Vector3(0.0, 1.0, 0.0),  # top 3
	Vector3(0.0, 0.0, -1.0),  # back 4
	Vector3(0.0, 0.0, 1.0),  # front 5
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


func init_voxel_cube(_material, uv_offset = Vector2(0,0), uv_scale = Vector2(1,1), mesh_scale = 1.0, mesh_offset = Vector3(0,0,0)):
	var st = SurfaceTool.new()

	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	#var uv_offset = Vector2(tex_id % atlas_size, tex_id / atlas_size);
	#var uv_scale = 1.0 / atlas_size;
	
	for i in range(0, 6*4):
		st.add_normal(CUBE_NORMALS[i / 4]);
		if (uv_offset is Array):
			st.add_uv((CUBE_UVS[i % 4] + uv_offset[i / 4]) * uv_scale);
		else:
			st.add_uv((CUBE_UVS[i % 4] + uv_offset) * uv_scale);
		st.add_vertex(CUBE_VERTICES[CUBE_VERTEX_INDICES[i]] * mesh_scale + mesh_offset);

	for i in range(0, 6 * 4, 4):
		st.add_index(0+i);
		st.add_index(1+i);
		st.add_index(2+i);
		st.add_index(0+i);
		st.add_index(2+i);
		st.add_index(3+i);
	
	# Commit to a mesh.
	mesh = st.commit()
	
	#set_material_override( _material);
	mesh.surface_set_material(0, _material);

