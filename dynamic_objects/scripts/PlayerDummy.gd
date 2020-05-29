extends Spatial

var uuid;

var INVENTORY_SIZE = 8;
var _inventory = [];
var active_inventory_slot = 0;

var _toolbelt = {
	left = null,
	right = null
};

var _hands = {
	left = {
		held_item = null,
		transform = Transform.IDENTITY,
		last_transform = null
	},
	right = {
		held_item = null,
		transform = Transform.IDENTITY,
		last_transform = null
	}
};

const INTERPOLATION_DURATION = 1 / 20;
var _t = 0;

func _ready():
	for _i in range(0, INVENTORY_SIZE):
		_inventory.append([null, 0]);

func _process(delta):
	_t += delta;

	_update_hand(_hands.left);
	_update_hand(_hands.right);

func _update_hand(hand):
	if !hand.held_item:
		return;

	var viewed_transform = hand.transform;
	
	if hand.last_transform && _t < INTERPOLATION_DURATION:
		viewed_transform = hand.last_transform.interpolate_with(hand.transform, _t / INTERPOLATION_DURATION);

	hand.held_item.global_transform = viewed_transform;

###

func update_positions(left_hand_transform, right_hand_transform):
	_t = 0;
	_hands.left.last_transform = _hands.left.transform;
	_hands.right.last_transform = _hands.right.transform;
	
	_hands.left.transform = left_hand_transform;
	_hands.right.transform = right_hand_transform;

func load_player_data(data):
	uuid = data.uuid;

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

	if(data.hand_left):
		var def = vdb.get_def_from_name(data.hand_left.name);
		var item = vdb.create_object_from_def(def);
		item.uuid = data.hand_left.uuid;

		_hands.left.held_item = item;

	if(data.hand_right):
		var def = vdb.get_def_from_name(data.hand_right.name);
		var item = vdb.create_object_from_def(def);
		item.uuid = data.hand_right.uuid;
		
		_hands.right.held_right = item;

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
		data.hand_left = {
			uuid = _hands.left.held_item.uuid,
			name = _hands.left.held_item.get_def().name
		};

	if(_hands.right.held_item):
		data.hand_right = {
			uuid = _hands.right.held_item.uuid,
			name = _hands.right.held_item.get_def().name
		};

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

func delete_held_item(hand_name):
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
