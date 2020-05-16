# DungeonInstanceGenerator_V1.gd
extends VoxelStream


var start_position = Vector3(4.0, 1.0+2.0, 4.0);


func persistence_change_voxel(voxel_pos: Vector3, voxel_id):
	# we dont save anything for this generator
	pass;


func get_version_string():
	return "DIG_V1";


func world_check_can_mine(voxel_id):
	return false;


var tt0 = null;
var tt1 = null;
var tt2 = null;
var _maze = null;

var _magica_to_voxelid = PoolByteArray();

func _fill_block_translation_table():
	_magica_to_voxelid.resize(256);
	
	for i in range(0, _magica_to_voxelid.size()):
		_magica_to_voxelid[i] = 1;
		
	_magica_to_voxelid[1] = vdb.voxel_block_names2id.stone_brick;


const D_UP = 0;
const D_RIGHT = 1;
const D_DOWN = 2;
const D_LEFT = 3;

const D_MASK_UP = 1;
const D_MASK_RIGHT = 2;
const D_MASK_DOWN = 4;
const D_MASK_LEFT = 8;

const DIRMASK = [1,2,4,8];
const DIRS = [0, 1, 2, 3];
const DIR2Dvec = [Vector2(0,-1), Vector2(1,0), Vector2(0,1), Vector2(-1,0)];
const DIR2D = [[0,-1], [1,0], [0,1], [-1,0]];


func _valid_maze_pos(p, resX, resY):
	return (p.x >= 0 && p.x < resX && p.y >= 0 && p.y < resY);

func _update_frontier_cells(cell_pos : Vector2, in_cells : Dictionary, frontier_cells : Dictionary, resX, resY):
	for d in DIR2Dvec:
		var p = cell_pos + d;
		if (!_valid_maze_pos(p, resX, resY)): continue;
		if (in_cells.has(p)): continue;
		frontier_cells[p] = 0;
		
func _connect_cell(cell_pos : Vector2, in_cells : Dictionary):
	in_cells[cell_pos] = 0;
	for d in DIRS:
		var p = cell_pos + DIR2Dvec[d];
		if (in_cells.has(p)):
			in_cells[p] |= DIRMASK[(d+2)%4];
			in_cells[cell_pos] |= DIRMASK[d]; # connect the other direction too
			return;
			
			
func get_maze_map_as_string(m, resX, resY, p = null):
	var ret = "";

	for py in range(0, resY):
		for px in range(0, resX):
			var c = m[Vector2(px, py)];
			if (c & D_MASK_UP != 0): ret += ("+   ");
			else: ret += "+---";
		ret += "+\n";
		
		for px in range(0, resX):
			var c = m[Vector2(px, py)];
			
			if (c & D_MASK_LEFT != 0):  ret += "  ";
			else: ret += "| ";

			
			if (p != null && p.x == px && p.y == py):
				ret += "X ";
			else:
				ret += "  ";
			
		ret += "|\n";

	for px in range(0, resX):
		ret += "+---";
	ret += "+";
	
	return ret;


func print_maze(m, resX, resY):
#	for py in range(0, resY):
#		var l = "";
#		for px in range(0, resX):
#			var c = m[Vector2(px, py)];
#			l += str(c) + " ";
#		print(l);
	
	print(get_maze_map_as_string(m, resX, resY));



func generate_2d_maze(resX, resY):
	var rng := RandomNumberGenerator.new();
	
	var in_cells = {};
	var frontier_cells = {};
	var start_pos = Vector2(rng.randi_range(0, resX-1), rng.randi_range(0, resY-1));

	#print("Start Position = " + str(start_pos));
	in_cells[start_pos] = 0;
	_update_frontier_cells(start_pos, in_cells, frontier_cells, resX, resY);
	
	while (!frontier_cells.empty()):
		var next_cell = vr.randomArrayElement(rng, frontier_cells.keys());
		
		_connect_cell(next_cell, in_cells);
		_update_frontier_cells(next_cell, in_cells, frontier_cells, resX, resY);
		frontier_cells.erase(next_cell);
	
	return in_cells;


# here we can inspect the template and do some transformations on the
# data or create derived information like enemy spawners
func _parse_vox_as_template(vox_data):
	var t = {};
	
	t["mvoxel_data"] = vox_data;
	
	for i in range(0, vox_data.size()/4):
		#var x = vox_data[i*4+0];
		#var y = vox_data[i*4+2];
		#var z = vox_data[i*4+1]; #!!CAREFUL: it is flipped below when instanced; but these are local coordinates anyway and shold not be needed here
		
		var id = vox_data[i*4+3];
	
	
	
	
	return t;
	
	

func load_templates(prefix):
	var templates = []
	var path = "res://data/voxel_templates/dungeon_templates/";
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()
	var read = File.new();
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with(".") and file.begins_with(prefix):
			var vox = vdb.load_vox_onlyvoxels(path + file);
			templates.append(_parse_vox_as_template(vox[3]));
	
	dir.list_dir_end();
	
	print("Loaded " + str(templates.size()) + " " + prefix + " .vox templates");
	return templates


var maze_res = 4;

var _rooms := {};


func _generate_rooms_from_maze(maze : Dictionary):
	var rooms = {};
	
	for key in maze.keys():
		var cell = maze[key];
		var mvox_rotation = 0;
		var mvox_flipped = false;
		var mvox_template = null;
		
		if ((cell & D_MASK_UP != 0) && (cell & D_MASK_LEFT != 0)):
			mvox_template = vr.randomArrayElement(temp_rng, tt2);
		elif (cell & (D_MASK_UP) != 0):
			mvox_template = vr.randomArrayElement(temp_rng, tt1);
		elif (cell & (D_MASK_LEFT) != 0):
			mvox_template = vr.randomArrayElement(temp_rng, tt1);
			mvox_rotation = 3;
			mvox_flipped = true;
		else:
			mvox_template = vr.randomArrayElement(temp_rng, tt0);

		
		var r = {
			"maze_cell" : maze[key],
			"mvox_template" : mvox_template,
			"mvox_rotation" : mvox_rotation,
			"mvox_flipped" : mvox_flipped,
		}
		
		
		
		rooms[key] = r;
		
	return rooms;


func initialize(generator_seed):
	vr.log_info("Initializeing DungeonInstanceGenerator " + get_version_string())
	
	_fill_block_translation_table();

	tt0 = load_templates("t_0");
	tt1 = load_templates("t_1");#vdb.load_vox_onlyvoxels("res://data/voxel_templates/dungeon_templates/t_1_000.vox")[3];
	tt2 = load_templates("t_2");#vdb.load_vox_onlyvoxels("res://data/voxel_templates/dungeon_templates/t_2_000.vox")[3];

	_maze = generate_2d_maze(maze_res, maze_res);
	_rooms = _generate_rooms_from_maze(_maze);
	
	#print(_rooms)
	#print_maze(_maze, maze_res, maze_res);

	
	#var template_size = 8;
	#var vox = vdb.load_vox_onlyvoxels("res://data/voxel_templates/dungeon_templates/t8x8x8_.vox");
	#if (vox[0] != template_size || vox[1] != template_size || vox[2] != template_size):
	#	vr.log_error(".vox tempalte has unexpected size %d %d %d" % [vox[0],vox[1],vox[2]]);
	#	return;
	


const buffer_size : int = 16;

const template_size = Vector3(8, 8, 8);



# put an instance into the voxel buffer block
var temp_rng = RandomNumberGenerator.new();
func fill_instance(buffer, buffer_origin : Vector3, _template, rotate, flip=false):
	
	#!!TODO: this is not good here and the rng seed should be decided
	#        on maze generation
	var tt = _template.mvoxel_data;
	
	for i in range(0, tt.size()/4):
		var mID = tt[i*4+3];
		if (mID == 0): continue; # no 0 voxels
		
		var ttx = tt[i*4+0]; 
		if (flip): ttx = (int(template_size.x) - 1 - tt[i*4+0]);
		var ty = tt[i*4+2];
		var ttz = (int(template_size.z) - 1 - tt[i*4+1])
		
		var tx = ttx;
		var tz = ttz;
		if (rotate == 0):
			pass;
		if (rotate == 1):
			tx = template_size.z - ttz - 1;
			tz = ttx;
		if (rotate == 2):
			tx = template_size.x - ttx - 1;
			tz = template_size.z - ttz - 1;
		if (rotate == 3):
			tx = ttz;
			tz = template_size.x - ttx - 1;
		
		var x = int(buffer_origin.x) + tx;
		var y = int(buffer_origin.y) + ty;
		var z = int(buffer_origin.z) + tz;
		var voxelId = _magica_to_voxelid[mID];
		
		buffer.set_voxel(voxelId, x, y, z, 0);

func block2_fromVec3(v : Vector3, d : Vector3):
	return Vector2(int(v.x) / int(d.x), int(v.z) / int(d.z));

func fill_floor(buffer : VoxelBuffer, buffer_origin : Vector3, rooms : Dictionary, maze_block_origin: Vector3):
	var maze_block_cell_pos = block2_fromVec3(maze_block_origin + buffer_origin, template_size);
	
	if (rooms.has(maze_block_cell_pos)):
		
		var room = rooms[maze_block_cell_pos];
		var cell = room.maze_cell;
		
		#print(str(maze_block_cell_pos) + " => " + str(cell));
		
		fill_instance(buffer, buffer_origin, room.mvox_template, room.mvox_rotation, room.mvox_flipped);
		
#		if ((cell & D_MASK_UP != 0) && (cell & D_MASK_LEFT != 0)):
#			fill_instance(buffer, buffer_origin, tt2, 0);
#		elif (cell & (D_MASK_UP) != 0):
#			fill_instance(buffer, buffer_origin, tt1, 0);
#		elif (cell & (D_MASK_LEFT) != 0):
#			fill_instance(buffer, buffer_origin, tt1, 3, true);
#		else:
#			fill_instance(buffer, buffer_origin, tt0, 0);
		#buffer.fill_area(1, buffer_origin, buffer_origin + template_size, 0);
	else:
		buffer.fill_area(_magica_to_voxelid[1], buffer_origin, buffer_origin + template_size, 0);


func emerge_block(buffer : VoxelBuffer, origin : Vector3, lod : int) -> void:
	if (lod != 0): return;
	
	if (buffer_size != buffer.get_size_x() ||
		buffer_size != buffer.get_size_y() ||
		buffer_size != buffer.get_size_z()):
		vr.log_error("TerrainGenerator: buffer_size != %d" % buffer_size)

	var resX = buffer.get_size_x();
	var resY = buffer.get_size_y();
	var resZ = buffer.get_size_z();
	
	
	if (origin.y == 0): # floor level 0
		fill_floor(buffer, Vector3(0, 0, 0), _rooms, origin);
		fill_floor(buffer, Vector3(8, 0, 0), _rooms, origin);
		fill_floor(buffer, Vector3(0, 0, 8), _rooms, origin);
		fill_floor(buffer, Vector3(8, 0, 8), _rooms, origin);



# here we create all the enemies based on the map
func spawn_enemies(world):
	pass;
