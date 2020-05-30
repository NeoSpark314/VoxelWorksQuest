extends Spatial

var uuid;
var pid;

var INVENTORY_SIZE = 8;
var _inventory = [];
var active_inventory_slot = 0;

var _toolbelt = {
	left = null,
	right = null
};

var _head = {
	transform = Transform.IDENTITY,
	last_transform = null,
	viewed_transform = Transform.IDENTITY,
	spatial = null,
};

var _head_options = [
	"aspen_tree",
	"tree",
	"pine_tree",
	"jungle_tree"
];

var _hands = {
	left = {
		held_item = null,
		transform = Transform.IDENTITY,
		last_transform = null,
		viewed_transform = Transform.IDENTITY,
		spatial = null
	},
	right = {
		held_item = null,
		transform = Transform.IDENTITY,
		last_transform = null,
		viewed_transform = Transform.IDENTITY,
		spatial = null
	}
};

const INTERPOLATION_DURATION = 1.0 / 20;
var _t = 0;

func _ready():
	_head.spatial = $Head;
	_hands.left.spatial = $Left_Hand;
	_hands.right.spatial = $Right_Hand;

	var block_def = vdb.get_def_from_name("cloud");
	_generate_hand(_hands.left, block_def);
	_generate_hand(_hands.right, block_def);

	for _i in range(0, INVENTORY_SIZE):
		_inventory.append([null, 0]);

func generate_head():
	var block_def = vdb.get_def_from_name(_head_options[pid]);
	var voxel_object = vdb.create_voxel_mesh_from_def(block_def);

	voxel_object.scale *= .5;
	voxel_object.translation = -voxel_object.scale / 2;

	_head.spatial.add_child(voxel_object);
	
func _generate_hand(hand, block_def):
	var voxel_object = vdb.create_voxel_mesh_from_def(block_def);
	
	voxel_object.scale *= .15;
	voxel_object.translation = -voxel_object.scale / 2;

	hand.spatial.add_child(voxel_object);

func _process(delta):
	# initial player position not set yet
	if !_head.last_transform:
		return;

	_t += delta;

	_interpolate_transform(_head);
	_update_hand(_hands.left);
	_update_hand(_hands.right);

func _update_hand(hand):
	_interpolate_transform(hand);

	hand.spatial.visible = !hand.held_item;

	if hand.held_item:
		hand.held_item.global_transform = hand.viewed_transform;

func _interpolate_transform(head_or_hand):
	if head_or_hand.last_transform && _t < INTERPOLATION_DURATION:
		var weight = _t / INTERPOLATION_DURATION;
		head_or_hand.viewed_transform = head_or_hand.last_transform.interpolate_with(head_or_hand.transform, weight);
	else:
		head_or_hand.viewed_transform = head_or_hand.transform;
	
	head_or_hand.spatial.global_transform = head_or_hand.viewed_transform;

###

func update_positions(head_transform, left_hand_transform, right_hand_transform):
	_t = 0;

	_update_transform(_head, head_transform);
	_update_transform(_hands.left, left_hand_transform);
	_update_transform(_hands.right, right_hand_transform);

func _update_transform(head_or_hand, transform):
	head_or_hand.transform = transform;

	if !head_or_hand.last_transform:
		head_or_hand.viewed_transform = transform;

	head_or_hand.last_transform = head_or_hand.viewed_transform;

func load_player_data(data):
	uuid = data.uuid;
	pid = data.pid;

	generate_head();

	apply_inventory_save_dict(data.inventory);

	if(data.toolbelt_left):
		var def = vdb.get_def_from_name(data.toolbelt_left.name);
		var item = vdb.create_object_from_def(def);
		item.uuid = data.toolbelt_left.uuid;

		_toolbelt.left = item;

	if(data.toolbelt_right):
		var def = vdb.get_def_from_name(data.toolbelt_right.name);
		var item = vdb.create_object_from_def(def);
		item.uuid = data.toolbelt_right.uuid;

		_toolbelt.right = item;

	for child in vdb.voxel_world_player.parent_world.get_children():
		if !child.has_method("can_grab"):
			continue;
		
		if data.hand_left == child.uuid:
			_hands.left.held_item = child;

			# already found the item for the right hand
			if !data.hand_right || _hands.right.held_item:
				break;
			
		if data.hand_right == child.uuid:
			_hands.right.held_item = child;

			# already found the item for the left hand
			if !data.hand_left || _hands.left.held_item:
				break;

func apply_inventory_save_dict(data):
	active_inventory_slot = data.active_inventory_slot;

	for i in range(0, INVENTORY_SIZE):
		var def_name = data.def_names[i];
		var def = null;
		
		if def_name:
			def = vdb.get_def_from_name(def_name);
		
		_inventory[i][0] = def;
		_inventory[i][1] = data.item_count[i];

### core Player interface

func gen_player_data():
	var data = {
		uuid = uuid,
		pid = pid,
		inventory = {
			def_names = [],
			item_count = [],
			active_inventory_slot = active_inventory_slot
		},
		toolbelt_left = null,
		toolbelt_right = null,
		hand_left = null,
		hand_right = null
	};

	for i in range(0, INVENTORY_SIZE):
		var slot = _inventory[i];
		var item_name = null;

		if(slot[0]):
			item_name = slot[0].name;

		data.inventory.def_names.append(item_name);
		data.inventory.item_count.append(slot[1]);

	if(_toolbelt.left):
		data.toolbelt_left = {
			uuid = _toolbelt.left.uuid,
			name = _toolbelt.left.get_def().name
		};

	if(_toolbelt.right):
		data.toolbelt_right = {
			uuid = _toolbelt.right.uuid,
			name = _toolbelt.right.get_def().name
		};

	if(_hands.left.held_item):
		data.hand_left = _hands.left.held_item.uuid;

	if(_hands.right.held_item):
		data.hand_right = _hands.right.held_item.uuid;

	return data;

func grab_with(hand_name, item):
	_hands[hand_name].held_item = item;

func release_with(hand_name):
	var hand = _hands[hand_name];
	var item = hand.held_item;
	hand.held_item = null;
	
	return item;

func get_held_object(hand_name):
	return _hands[hand_name].held_item;

func delete_held_object(hand_name):
	var item = _hands[hand_name].held_item;
	
	if !item:
		return;

	item.queue_free();

	_hands[hand_name].held_item = null;

func give_item(item_def, slot):
	_inventory[slot][0] = item_def;
	_inventory[slot][1] += 1;

func get_available_slot(voxel_or_item_def):
	var empty_space = -1;

	for pos_it in range(0, INVENTORY_SIZE):
		# start at the displayed slot and wrap around
		var slot = (pos_it + active_inventory_slot) % INVENTORY_SIZE;
		var item = _inventory[slot][0];
		var item_count = _inventory[slot][1];

		# get first available slot
		if !item && empty_space == -1:
			empty_space = slot;

		# return a stackable slot
		if item && item.name == voxel_or_item_def.name && item_count < item.stackability:
			return slot;
	
	return empty_space;

func take_item_from_slot(slot):
	# construct a new object and spawn it into the world
	if (_inventory[slot][1] <= 0): return null; # nothing to grab in the inventory

	var def = _inventory[slot][0];
	_inventory[slot][1] -= 1;
	
	if (_inventory[slot][1] == 0):
		_inventory[slot][0] = null;

	var voxel_object = vdb.create_object_from_def(def);
	vdb.voxel_world_player.parent_world.add_child(voxel_object);

	return voxel_object;

func set_active_slot(slot):
	active_inventory_slot = slot;

func move_held_item_to_tool_slot(hand_name, slot_name):
	var item = _hands[hand_name].held_item;
	
	item.get_parent().remove_child(item);

	_toolbelt[slot_name] = item;
	_hands[hand_name].held_item = null;

func move_tool_to_hand(slot_name, hand_name):
	var item = _toolbelt[slot_name];

	vdb.voxel_world_player.parent_world.add_child(item);

	_hands[hand_name].held_item = item;
	_toolbelt[slot_name] = null;
