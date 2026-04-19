@tool
extends EditorPlugin

const SCENE_MANAGER_NAME: StringName = "SceneLoader"

func _enable_plugin() -> void:
	# Add autoloads here.
	assert(not ProjectSettings.has_setting("autoload/" + SCENE_MANAGER_NAME), "An autoload named " + SCENE_MANAGER_NAME + " already exist")
	add_autoload_singleton(SCENE_MANAGER_NAME, "res://addons/scene_loader/scene_loader.gd")
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	remove_autoload_singleton(SCENE_MANAGER_NAME)
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
