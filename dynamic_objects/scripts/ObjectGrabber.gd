extends Spatial

var controller : ARVRController = null;

var grab_area : Area = null;
var held_object = null;
var hand_name;
var _requested_release = false;

signal grab_released_held_object;

func _ready():
	controller = get_parent();
	if (not controller is ARVRController):
		vr.log_error(" in ObjectGrabber.gd: parent not ARVRController.");
	
	if controller.get_hand() == ARVRPositionalTracker.TRACKER_LEFT_HAND:
		hand_name = "left";
	else:
		hand_name = "right";
	
	var static_grab = controller.find_node("Feature_StaticGrab", false, false)
	if (static_grab == null):
		vr.log_error(" ObjectGrabber.gd requires Feature_StaticGrab on parent controller.");
	else:
		grab_area = static_grab.grab_area;

# this is a workaround that we reparent always on grab to make
# sure it is in the world as for example crafting areas will reparent
# the object to fit in the grid
func _reparent_object_to_world(o : Spatial):
	# ??!!
	var scene_root = get_parent().get_parent().get_parent().get_parent();
	
	var p = o.get_parent();
	if (p != null && p != scene_root):
		p.remove_child(o);
		scene_root.add_child(o);

func start_grab(area):
	if (area == null): return false;
	if (!area.visible): return false; # safety check to avoid grabbing objects that were set invisible for delete

	if (area.has_method("can_grab") && area.can_grab(controller)):
		area.request_grab(hand_name);
		return true;
		
	var p = area.get_parent();
	if (p.has_method("can_grab") && p.can_grab(controller)):
		p.request_grab(hand_name);
		return true;
	
	return false;
	
func delete_held_object():
	if (held_object != null):
		held_object.get_parent().remove_child(held_object);
		held_object.queue_free();
		held_object = null;
		controller.visible = true;

func release_grab():
	if (held_object && held_object.has_method("release_grab")):
		held_object.release_grab(controller);
	held_object = null;
	controller.visible = true;
	_requested_release = false;
	
func update_grab():
	if (held_object == null):
		if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.GRIP_TRIGGER)):
			# find the right rigid body to grab
			var areas = grab_area.get_overlapping_areas();
			for o in areas:
				#if body is KinematicBody:
				if start_grab(o): break;
	else:
		if (!_requested_release && !controller._button_pressed(vr.CONTROLLER_BUTTON.GRIP_TRIGGER)):
			_requested_release = true;
			held_object.visible = false;
			emit_signal("grab_released_held_object", hand_name, held_object);


# position update needs to be in the process
func _process(dt):
	if (held_object):
		held_object.global_transform = controller.get_grab_transform();
		pass;

# key presses in the _physics_process
func _physics_process(dt):
	update_grab()
