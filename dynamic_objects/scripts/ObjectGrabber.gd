extends Spatial

var controller : ARVRController = null;

var grab_area : Area = null;
var held_object = null;

signal grab_released_held_object;

func _ready():
	controller = get_parent();
	if (not controller is ARVRController):
		vr.log_error(" in ObjectGrabber.gd: parent not ARVRController.");
	
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

func start_grab(area : Area):
	if (area == null): return false;
	if (!area.visible): return false; # safety check to avoid grabbing objects that were set invisible for delete

	if (area.has_method("can_grab") && area.can_grab()):
		held_object = area.get_grab_object(controller);
		_reparent_object_to_world(held_object);
		return true;
		
	var p = area.get_parent();
	if (p.has_method("can_grab") && p.can_grab()):
		held_object = p.get_grab_object(controller);
		_reparent_object_to_world(held_object);
		return true;
	
	return false;
	
func delete_held_object():
	if (held_object != null):
		held_object.get_parent().remove_child(held_object);
		held_object.queue_free();
		held_object = null;

func release_grab():
	print(held_object);
	emit_signal("grab_released_held_object", held_object);
	if (held_object.has_method("release_grab")):
		held_object.release_grab(controller);
	held_object = null;
	
func update_grab():
	if (held_object == null):
		if (controller._button_just_pressed(vr.CONTROLLER_BUTTON.GRIP_TRIGGER)):
			# find the right rigid body to grab
			var areas = grab_area.get_overlapping_areas();
			for o in areas:
				#if body is KinematicBody:
				if start_grab(o): break;
	else:
		if (!controller._button_pressed(vr.CONTROLLER_BUTTON.GRIP_TRIGGER)):
			release_grab();


func do_process(dt):
	if (held_object):
		held_object.global_transform = controller.get_grab_transform();
		pass;
	
	update_grab()

func _process(dt):
	do_process(dt);
	pass


func _physics_process(dt):
	#do_process(dt);
	pass;
