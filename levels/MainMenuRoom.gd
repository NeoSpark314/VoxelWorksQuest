extends Spatial


onready var info_text_label = $InfoTextLabel;
onready var changelog_text_label = $ChangeLogLabel;
onready var statistics_text_label = $StatisticsTextLabel;

const info_text ="""%s %s
Welcome!

In this prototype you can explore an infinite voxel world.
It is an early prototype and all mechanics are just experimental. 
Things will change in future updates.

If you have questions or feedback join the Voxel Works Discord
(link is on the sidequest page or on itch.io).

<-- Gameplay Statistics                                       Start Game -->
""" % [vdb.GAME_NAME, vdb.GAME_VERSION_STRING];

# current changelog is always the first
const changelog_text = [
"""Changelog for %s

 - early experimental local multiplayer option 
   (with port forwarding (1234) enabled you can 
   also host a game over the internet)

 - Disable Saving for visited worlds
 - Crafting grid rotates now to hand position
 
<-- Start Game (look left)""" % [vdb.GAME_VERSION_STRING]
]


func create_some_blocks():
#	var pos = [
#	vdb.voxel_block_names2id.dirt, Vector3(0,0,0),
#	1, Vector3(0,1,0),
#	1, Vector3(1,0,0),
#	1, Vector3(1,0,1),
#	1, Vector3(0,0,1),
#	]
#
#	for i in range(0, pos.size(), 2):
#		var v = vdb.create_voxelblock_object_from_def(vdb.voxel_block_defs[pos[i]]);
#		v.scale = Vector3(8,8,8);
#		add_child(v);
#		v.transform.origin = pos[i+1];

	var size = 2;
	
	for z in range (-size, size+1):
		for y in range(0, 5):
			for x in range(-size, size+1):
				var v = null;
				
				if (x == -size || x == size || z == -size || z == size): #border
					if (y == 0):
						v = vdb.create_voxelblock_object_from_def(vdb.names2blockORitem_def.stone);
					elif (x == z || x == -z):
						v = vdb.create_voxelblock_object_from_def(vdb.names2blockORitem_def.stone);
				elif (y == 0): # ground
					v = vdb.create_voxelblock_object_from_def(vdb.names2blockORitem_def.grass);
				
				if (v):
					v.scale = Vector3(8,8,8);
					add_child(v);
					v.transform.origin = Vector3(x, y-0.5, z);


func _physics_process(delta):
#	if (vr.button_just_released(vr.BUTTON.A) ||
#		vr.button_just_released(vr.BUTTON.B) ||
#		vr.button_just_released(vr.BUTTON.X) ||
#		vr.button_just_released(vr.BUTTON.Y) ||
#		vr.button_just_released(vr.BUTTON.LEFT_INDEX_TRIGGER) ||
#		vr.button_just_released(vr.BUTTON.RIGHT_INDEX_TRIGGER)
#	):
#		_start_game();
	pass;


func _setup_statistics():
	var km = int(floor(vdb.global_statistics.traveled_distance / 1000));
	var m = int(floor(vdb.global_statistics.traveled_distance - km * 1000));
	
	var hours = int(floor(vdb.global_statistics.total_playtime / 3600));
	var minutes = int(floor(vdb.global_statistics.total_playtime / 60 - hours * 60));
	
	statistics_text_label.set_label_text("""Overall Gameplay Statistics:

	Total Jogged Distance: %3d km %3d m
	Steps taken: %d
	Total Playtime: %3d hours %2d minutes
	
	Mined Blocks (swing): %d
	Build Blocks (swing): %d
	Crafted Items (swing): %d
	
	Game Version: %s""" % [km, m, vdb.global_statistics.steps_taken, hours, minutes,
vdb.global_statistics.mined_blocks, vdb.global_statistics.build_blocks, vdb.global_statistics.crafted_items,
vdb.GAME_VERSION_STRING]);


func _ready():
	vr.leftController.set_rumble(0.0);
	vr.rightController.set_rumble(0.0);
	
	
	create_some_blocks();
	info_text_label.set_label_text(info_text);
	changelog_text_label.set_label_text(changelog_text[0]);
	
	_setup_statistics();
	



