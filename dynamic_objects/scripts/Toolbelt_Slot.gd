extends Spatial

onready var slot = $Slot;

func can_grab():
	if slot.get_child_count() == 0: return false;
	return true;
	
	
func get_slot_object():
	if slot.get_child_count() == 0: return null;
	
	var obj = slot.get_child(0);
	return obj;


func get_grab_object(controller):
	if (vdb.gameplay_settings.toolbelt_require_second_button):
		if (!controller._button_pressed(vr.CONTROLLER_BUTTON.XA)):
			return null;
	
	return get_slot_object();
	
func check_and_put_in_toolbelt_slot(held_obj):
	if ($Slot.get_child_count() > 0): return false; # already something in there
	var item_def = held_obj.get_item_def();
	if (item_def == null): return false; # not a tool item
	
	# here we need to check if we have a parent; only then we are already
	# in the world
	if (held_obj.get_parent()): 
		if (!$Area.overlaps_area(held_obj.get_geometry_node())): return false;
		held_obj.get_parent().remove_child(held_obj);
		
	slot.add_child(held_obj);
	held_obj.transform = Transform();
	
	$MeshInstance.visible = false;
	


func _on_Area_area_entered(area):
	if (slot.get_child_count() > 0):
		$MeshInstance.visible = false;
	else:
		$MeshInstance.visible = true;


func _on_Area_area_exited(area):
	if ($Area.get_overlapping_areas().size() <= 1):
		$MeshInstance.visible = false;
