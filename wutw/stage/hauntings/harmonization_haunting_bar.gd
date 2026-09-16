@tool
class_name HarmonizationHauntingBar
extends FadedScrollContainer

static var HAUNTING_PREVIEW_SCENE := AsyncLoadedResource.new('res://stage/hauntings/haunting_harmonization_preview.tscn', false, AsyncLoadedResource.LoadPhase.UNLIKELY)

func clear() -> void:
	Utils.clear_node(%HauntingPreviews)

func track_haunting(haunting: Haunting_Harmonization) -> void:
	var preview := HAUNTING_PREVIEW_SCENE.instantiate_loaded_scene() as HauntingHarmonizationPreview
	preview.haunting = haunting
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	%HauntingPreviews.add_child(preview)
	haunting.triggered.connect(ensure_control_visible.bind(preview))
