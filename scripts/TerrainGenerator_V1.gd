# TerrainGenerator_V1
extends VoxelStream

func get_version_string():
	return "V1";

var heightmap_noise = OpenSimplexNoise.new()

var heightmap_influence = OpenSimplexNoise.new()

var surface_influence = OpenSimplexNoise.new()

var cave_noise = OpenSimplexNoise.new()

var ore_noise = OpenSimplexNoise.new()

# Manually tweaked for now; for the future the Idea would be to first
# generate a block and only then report the start position
const world_start_position = Vector3(18.5, 1.0, 10.5);

var start_position = world_start_position;

var terrain_generator_seed = 0;


func world_check_can_mine(voxel_id):
	return true;


# a dictionary for all blocks that are persisted
# a block is a full set of voxels size resX*resY*resZ
var _persisted_blocks = {};

func persistence_change_voxel(voxel_pos: Vector3, voxel_id):
	if (buffer_size != 16):
		vr.log_error("Persistance currenlty needs a buffer size of 16!!");
	
	# needed because else some weired numerical inconsistencies happen below
	# probalby gdscript is not a good choice for integer arithmetic!!
	voxel_pos = voxel_pos.floor();
	
	#!!CAREFUL sth. is wrong with negative integer arithmetik in godot at the moment!!
	var ox = int(floor(voxel_pos.x / buffer_size)) * buffer_size;
	var oy = int(floor(voxel_pos.y / buffer_size)) * buffer_size;
	var oz = int(floor(voxel_pos.z / buffer_size)) * buffer_size ;
	
	# we need a string key here so it is easier to load from
	# a json later
	var key = "%d_%d_%d" % [ox, oy, oz];
	
	if (!_persisted_blocks.has(key)):
		_persisted_blocks[key] = [];
		
	var vx : int = int(voxel_pos.x) - ox;
	var vy : int = int(voxel_pos.y) - oy;
	var vz : int = int(voxel_pos.z) - oz;
	
	# There is a lot of optimization potential here as the actual bosition
	# is always <= buffer_size and thus could be encoded in a single int
	_persisted_blocks[key].append(int(vx + vy*16 + vz*(16*16)));
	_persisted_blocks[key].append(voxel_id);
	
	#print("Persisted " + str(_persisted_blocks[key]));
	

func _persistence_get_block(origin: Vector3):
	var key = "%d_%d_%d" % [origin.x, origin.y, origin.z];
	if (_persisted_blocks.has(key)): 
		return _persisted_blocks[key];
	return null;


func get_special_objects(pos : Vector3):
	return null;

#!!TODO: this is a very first hack to get some tower into the game...
func _get_special_objects_voxel_def(px, py, pz):
	var pos_x = 125;
	var pos_y = -3;
	var pos_z = 5;
	var dx = 10;
	var dz = 10;
	var dy = 32;
	
	var wall = vdb.voxel_types.temp_nonminable_stone_brick;
	
	var tower_aabb = AABB(Vector3(pos_x, pos_y, pos_z), Vector3(dx, dy, dz));
	var voxel_pos = Vector3(px, py, pz);

	if !tower_aabb.has_point(voxel_pos): return -1;
	
	var tx = int(px - tower_aabb.position.x);
	var ty = int(py - tower_aabb.position.y);
	var tz = int(pz - tower_aabb.position.z);
	
	# walls
	if (tx == 0 || tz == 0 || tx == dx || tz == dz):
		
		#door
		if (tz == 0 && tx == dx/2 && ty > 0 && ty < 3): return vdb.voxel_types.air;
		
		return wall;
		
	var floor_height = 8;
	
	# stairs
	if (tx == 1 && (tz%floor_height) == ((ty+1)%floor_height)):
		return wall;
		
	#ceiling
	if (ty == dy):
		return wall;
		
	#floors
	if ((ty % floor_height) == 0 &&  !(tx < 2 && tz > dz - 5)):
		return wall;
		
	# last floor
	if (ty > dy - floor_height):
		
		# spawn some treasure
		if (tx == dx/2 && tz == dz/2 && ty < dy - floor_height + 3):
			return vdb.voxel_types.gold_block;
	

	return vdb.voxel_types.air;


# not sure if this is always the case; will be checked below
# but this value is needed for persistence
const buffer_size : int = 16;

func initialize(generator_seed, persisted_blocks):
	vr.log_info("Initializeing TerrainGenerator " + get_version_string())
	
	if (persisted_blocks != null):
		_persisted_blocks = persisted_blocks;
	
	terrain_generator_seed = generator_seed;
	
	var gen_seed = terrain_generator_seed;
	
	heightmap_noise.seed = gen_seed;
	heightmap_noise.octaves = 4
	heightmap_noise.period = 58.2
	heightmap_noise.persistence = 0.205
	heightmap_noise.lacunarity = 2.4
	
	heightmap_influence.seed = gen_seed+1;
	heightmap_influence.octaves = 1
	heightmap_influence.period = 44
	
	surface_influence.seed = gen_seed+2;
	surface_influence.octaves = 2
	surface_influence.period = 25
	surface_influence.persistence = 0.205
	
	cave_noise.seed = gen_seed+3;
	cave_noise.octaves = 3
	cave_noise.period = 76.7 / 8
	cave_noise.persistence = 0.203
	cave_noise.lacunarity = 2.35
	
	ore_noise.seed = gen_seed+4;
	ore_noise.octaves = 1
	ore_noise.period = 71.7 / 8
	ore_noise.persistence = 0.201
	ore_noise.lacunarity = 2.25
	
	
	start_position = world_start_position;
	var height = get_heightmap(int(start_position.x), int(start_position.z));
	start_position.y = height + 6.0;
	


const heightmap_plane_scale = 2;
const heightmap_hill_height = 32;

func get_heightmap(x, z):
	x = x * heightmap_plane_scale;
	z = z * heightmap_plane_scale;
	
	#var inf = heightmap_influence.get_noise_2d(x, z);
	
	var v = heightmap_noise.get_noise_2d(x, z); 

	#if (inf > 0.0):
	#	v = v * 4.0;
	
	v = v * heightmap_hill_height;

	
	# make a hard ground
	if v < -5:
		v += 5;
		v *= 0.25;
	elif v < 0:
		v = 0;
	
	# make some hills grow higher
	if v > 4:
		v *= 1.5;

	return v;
	

const cloud_height = 37;

func get_voxel_type_for_height(px, py, pz, height, rng : RandomNumberGenerator):
	
#	var special = _get_special_objects_voxel_def(px, py, pz);
#	if (special != -1):
#		return special;
	
	
	# world can't get lower then this
	if (py < -64):
		return vdb.voxel_types.bedrock;
		
	if (py >= cloud_height):
		if (py == cloud_height):
			var iscloud = cave_noise.get_noise_2d(px/3, pz/7);
			if (iscloud > 0.4): return vdb.voxel_types.cloud;
		return 0;
		
	# In the future we want sth. more connected here; perlin noise is not a good choice
	# for caves; but it is easy for now; and also not soo bad I think
	if (py < -4 || (height > 8 && height < 16)):
		var inf = surface_influence.get_noise_3d(py+4.1, py+13.3, px + 17.2); # rotate a bit
		var cave_value = cave_noise.get_noise_3d(px, py, pz);
		if (inf > 0.0 && cave_value > 0.2):
			return 0;

	
	if (py <= height-1): # stones and ores
		# for now we reuse the cave_noise here
		var ore_value = ore_noise.get_noise_3d(px/4.2, py/4.2, pz/4.2);
		
		var prop_mult = 0.5;
		var coal_prop = 0.25;
		var iron_prop = coal_prop + 0.0;
		var gold_prop = iron_prop + 0.0;
		
		if (py < -10):
			gold_prop += 0.2;
			coal_prop -= 0.2;
		elif (py < -5):
			iron_prop += 0.1
		elif (py < -1):
			iron_prop += 0.05
		
		if (ore_value > 0.2): 
			var p = rng.randf() / prop_mult;
			if (p < coal_prop):
				return vdb.voxel_types.stone_with_coal;
			elif (p < iron_prop):
				return vdb.voxel_types.stone_with_iron;
			elif (p < gold_prop):
				return vdb.voxel_types.stone_with_gold;
		
		return vdb.voxel_types.stone;
	elif (py <= height):
		var inf = surface_influence.get_noise_3d(px*1.1, py*1.2, pz*0.9);
		if (py < -1):
			if (inf < -0.3):
				return vdb.voxel_types.sand;
			elif (inf > 0.5):
				return vdb.voxel_types.dirt;
			else:
				return vdb.voxel_types.grass;

		if (py >= 12 + inf * 4):
				return vdb.voxel_types.snowstone;
				
		if (py >= 5):
			if (inf < (py - 6)/4):
				return vdb.voxel_types.stone;
				

		if (inf < -0.2):
			return vdb.voxel_types.sand;
		elif (inf > 0.6):
			return vdb.voxel_types.dirt;
		
		return vdb.voxel_types.grass;
		
	# nothing
	return 0;

const MAX_GRASS_HEIGHT = 8;

# needed to not throw errors from within voxel module
# might be faster to do this check inside the voxel module without throwing an
# error
func validate_position(buffer, x, y, z):
	return (x >= 0 && x < buffer.get_size_x() && \
			y >= 0 && y < buffer.get_size_y() && \
			z >= 0 && z < buffer.get_size_z());
			
			
func grow_vegetation(buffer, x, y, z, rng : RandomNumberGenerator):
	#buffer.set_voxel(vdb.voxel_types.fence_full_NS, x, y+1, z, 0);
	
	var num = rng.randi_range(1,7)
	
	var ggg = "";
	
	if (num <= 5):
		ggg = "plant_grass_" + str(num);
	elif (num == 6):
		ggg = "plant_flower_tulip";
	else:
		ggg = "plant_flower_dandelion_white";
	
	buffer.set_voxel(vdb.voxel_types[ggg], x, y+1, z, 0);

func grow_tree(buffer, x, y, z, rng : RandomNumberGenerator):
	var trunk_type = vdb.voxel_types.tree;
	var leaves_type = vdb.voxel_types.leaves;
	var height = 3 + rng.randi_range(0, 1);
	
	# for now tree type is based on noise
	var tree_type_inf = cave_noise.get_noise_2d(x/4, y/4);
	
	if (tree_type_inf < 0.0):
		trunk_type = vdb.voxel_types.aspen_tree;
		leaves_type = vdb.voxel_types.aspen_leaves;
		height += 1;
	
	
	for _i in range(0, height):
		y = y + 1;
		if (!validate_position(buffer, x, y, z)): continue;
		buffer.set_voxel(trunk_type, x, y, z, 0);
		

	for dy in range(0, 4):
		var offs  = dy / 2;
		for dx in range (-2 + offs, 3 - offs):
			for dz in range (-2 + offs, 3 - offs):
				if (dx == 0 && dz == 0 && dy == 0): continue;
				
				if (!validate_position(buffer, x+dx, y+dy, z+dz)): continue;
				
				if (buffer.get_voxel(x+dx, y+dy, z+dz, 0) == 0):
					buffer.set_voxel(leaves_type, x+dx, y+dy, z+dz, 0);



# where we start to generate dungeons... they are part of the world
# for now
#const dungeon_ground_level = -256;

func emerge_block(buffer : VoxelBuffer, origin : Vector3, lod : int) -> void:
	if (lod != 0): return;
	
	if (buffer_size != buffer.get_size_x() ||
		buffer_size != buffer.get_size_y() ||
		buffer_size != buffer.get_size_z()):
		vr.log_error("TerrainGenerator: buffer_size != %d" % buffer_size)
	

	var rng = RandomNumberGenerator.new();
	rng.seed = origin.x + origin.y * 17 + origin.z * 33; # ???

	var vegetation_rng = RandomNumberGenerator.new();
	vegetation_rng.seed = origin.x + origin.y * 13 + origin.z * 17; # ???
	
	var resX = buffer.get_size_x();
	var resY = buffer.get_size_y();
	var resZ = buffer.get_size_z();
	
	# cache the generated surface heights
	var surface_heights = Array();
	surface_heights.resize(resX * resZ);
	
	var surface_type = Array();
	surface_type.resize(resX * resZ);

	# Basic heightmap based terrain generation
	for z in range(0, resZ):
		var pz = (origin.z + z);
		for x in range(0, resX):
			var px = (origin.x + x);
			var height = get_heightmap(px, pz);

			surface_type[x + z * resX] = 0;
			surface_heights[x + z * resX]  = origin.y;
			for y in range(0, resY):
				
				# note: we shift here by 4 up because at the moment tree generation can only happen inside a chunk and not across boundaries	
				var py = (origin.y + y - 4);
				
				var voxel_type = get_voxel_type_for_height(px, py, pz, height, rng);
				if (voxel_type != 0):
					buffer.set_voxel(voxel_type, x, y, z, 0);
					
					# remember the surface that was generated for plant population below
					surface_type[x + z * resX] = voxel_type;
					surface_heights[x + z * resX] = y;
					#print(str(y) + " " + str(py));

	# check if we are in a tree gros area:
	
	
	# vegetation:
	if (origin.y >= 0 && origin.y < 16):
		# note: we skip the boundaries of the block here so trees are not cut off
		for z in range(0, resZ, 1):
			var pz = (origin.z + z);
			for x in range(0, resX, 1):
				var px = (origin.x + x);
				var height = surface_heights[x + z * resX];
				if (height > 9): continue;
				if (vegetation_rng.randf() > 0.05): continue;
				var surf = surface_type[x + z * resX];
				if ((surf == vdb.voxel_types.grass || surf == vdb.voxel_types.dirt)):
					grow_vegetation(buffer, x, height, z, vegetation_rng);
				


#	# now grow some trees; but only in a valid grow area
	#print(origin.y)
	var _last_tree_x = -1;
	var _last_tree_z = -1;
	if (origin.y >= 0 && origin.y < 16):
		# note: we skip the boundaries of the block here so trees are not cut off
		for z in range(2, resZ-2, 1):
			var pz = (origin.z + z);
			if (abs(pz - start_position.z) < 2): continue;
			for x in range(2, resX-2, 1):
				
				if (abs(x - start_position.x) < 2): continue;
				
				if (x == _last_tree_x+1 && z == _last_tree_z): continue;
				
				var px = (origin.x + x);
				if (abs(px - start_position.x) < 2): continue;

				var height = surface_heights[x + z * resX];
				
				# also skip too high in the block
				if (height > 9): continue;
				var inf = surface_influence.get_noise_2d(px * 3.0 + 11.1, pz * 3.0+ 19.3) * 0.5 + 0.5;
				if (inf < 0.5): continue;
				if (rng.randf() > 0.05): continue;
				
				var surf = surface_type[x + z * resX];
				
				if ((surf == vdb.voxel_types.grass || surf == vdb.voxel_types.dirt)):
					grow_tree(buffer, x, height, z, rng);
					_last_tree_x = x;
					_last_tree_z = z;


	# and now overwrite everything from what is persisted
	var block = _persistence_get_block(origin);
	if (block != null):
		for i in range(0, block.size(), 2):
			var v : int = int(block[i+0]);
			var x : int = v&0xF;
			var y : int = (v>>4)&0xF;
			var z : int = (v>>8)&0xF;
			var id = int(block[i+1]);
			buffer.set_voxel(id, x, y, z, 0);
			#print("Restored Voxel %d (%d %d %d)" % [id, x, y, z]);
			
		

