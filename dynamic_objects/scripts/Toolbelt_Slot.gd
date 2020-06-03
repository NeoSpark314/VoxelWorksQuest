extends Spatial

onready var slot = $Slot;

func can_grab(controller):
	if slot.get_child_count() == 0:
		return false;

	if (vdb.gameplay_settings.toolbelt_require_second_button && !controller._button_pressed(vr.CONTROLLER_BUTTON.XA)):
		return false;
	
	return true;

func request_grab(hand_name):
	vdb.voxel_world_player.request_tool_to_hand(name, hand_name);
	
func get_slot_object():
	if slot.get_child_count() == 0: return null;
	
	var obj = slot.get_child(0);
	return obj;


func get_grab_object():
	return get_slot_object();
	
func can_put(held_obj):
	if ($Slot.get_child_count() > 0):
		return false; # already something in there
	
	if (!held_obj.get_item_def()):
		return false; # not a tool item

	if (!$Area.overlaps_area(held_obj.get_geometry_node())):
		return false; # not overlapping
	
	return true;

func put_item(held_obj):
	var p = held_obj.get_parent();

	if p:
		p.remove_child(held_obj);

	$Slot.add_child(held_obj);
	held_obj.transform = Transform();
	$MeshInstance.visible = false;

func _on_Area_area_entered(area):
	if ($Slot.get_child_count() > 0):
		$MeshInstance.visible = false;
	else:
		$MeshInstance.visible = true;


func _on_Area_area_exited(area):
	if ($Area.get_overlapping_areas().size() <= 1):
		$MeshInstance.visible = false;
