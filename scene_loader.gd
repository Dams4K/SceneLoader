## SceneLoader
## 
## Autoload singleton managing threaded scene loading.
## Does not handle any UI or visual transition — connect to the exposed signals
## from a separate autoload in your project to display a loading screen.
##
## Typical usage:
## [codeblock]
##     SceneLoader.change_scene("res://scenes/game.tscn")
##
##     # Then call switch() once you are ready (e.g. after a transition)
##     await SceneLoader.load_finished
##     await my_transition.play_outro()
##     SceneLoader.switch()
## [/codeblock]
extends Node

const IT: StringName = "SceneLoader"

## Emitted when [method change_scene] is called and all guards have passed.
## Listeners should use this signal to start a visual transition or freeze the current scene.
## [br]
## [b]Note:[/b] the load has not started yet at this point. One frame is awaited
## before the threaded request is made, giving listeners time to react.
signal load_requested()

## Emitted when the threaded load request has been successfully submitted.
signal load_started()

## Emitted each frame while the resource is loading.
## [br][param progress] is in the [code][0.0, 1.0][/code] range.
signal load_progressed(progress: float)

## Emitted when the scene is fully loaded and ready to be displayed.
## [br]
## Call [method switch] whenever you are ready to perform the actual scene change.
## This lets you wait for an outro transition before switching.
signal load_finished()

## Emitted when the load fails, either at request time or during loading.
## [br][param path] is the scene that failed to load.
## [br][param err] is the [enum Error] code returned by the engine.
signal load_failed(path: String, err: Error)

## If [code]true[/code], the threaded loader will spawn additional sub-threads
## to load nested resources in parallel. May improve loading time for heavy scenes
## at the cost of higher CPU usage during loading.
var use_sub_threads: bool = true

var _loading: bool = false
var _target_scene: String = ""
var _packed: PackedScene = null

func _ready() -> void:
	set_process(false)


## Requests a scene change to [param path].
## [br]
## The following guards are checked before anything happens:
## [br]- emits a warning and returns if [param path] is already being loaded
## [br]- emits a warning and returns if a load is already in progress
## [br]- emits an error and returns if [param path] does not exist on disk
## [br]
## On success, sets the loader state as loading and emits [signal load_requested].
## [br]
## [b]Note:[/b] this method does not start the threaded load by itself.
## You must call [method begin_load] manually, typically after a transition has started.
## [codeblock]
##     SceneLoader.load_requested.connect(func():
##         await transition.play_intro()
##         SceneLoader.begin_load()
##     )
##     SceneLoader.change_scene("res://scenes/game.tscn")
## [/codeblock]
func change_scene(path: String) -> void:
	if path == _target_scene:
		push_warning(_msg("multiple load requests for %s" % path))
		return
	
	if _loading:
		push_warning(_msg("another scene is already loading"))
		return
	
	if not ResourceLoader.exists(path):
		push_error(_msg("scene %s not found" % path))
		return
	
	_loading = true
	_target_scene = path
	
	load_requested.emit()


## Submits the threaded load request for the scene previously set by [method change_scene].
## [br]
## The following guards are checked before the request is submitted:
## [br]- emits an error and returns if no target scene has been set by [method change_scene]
## [br]- resets the loading state and emits [signal load_failed] if the threaded request fails
## [br]
## On success, emits [signal load_started] and begins polling the load status each frame.
## [br]
## [b]Note:[/b] always call [method change_scene] before calling this method.
func begin_load() -> void:
	if _target_scene.is_empty():
		push_error("No target scene")
		return
	
	var err = ResourceLoader.load_threaded_request(_target_scene, "", use_sub_threads)
	if err != OK:
		_loading = false
		load_failed.emit(_target_scene, err)
		return
	
	load_started.emit()
	set_process(true)


## Performs the actual scene change using the last successfully loaded scene.
## [br]
## Must be called after [signal load_finished] has been emitted.
## Calling it before emits an error and returns without switching.
## [br]
## Separating the switch from the load allows you to wait for an outro animation
## or any other condition before committing to the scene change.
## [codeblock]
##     await SceneLoader.load_finished
##     await transition.play_outro()
##     SceneLoader.switch()
## [/codeblock]
## [b]Note:[/b] the packed scene is cleared after switching.
## Calling [method switch] twice without a new [method change_scene] will emit an error.
func switch() -> void:
	if _packed == null:
		push_error("No packed scene loaded")
	get_tree().change_scene_to_packed(_packed)
	_packed = null



func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target_scene, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			set_process(false)
			_loading = false
			load_failed.emit(_target_scene, Error.FAILED)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			load_progressed.emit(progress[0])
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_on_loaded()


func _on_loaded() -> void:
	_packed = ResourceLoader.load_threaded_get(_target_scene)
	_target_scene = ""
	_loading =  false
	
	load_finished.emit()


func _msg(message: String) -> String:
	return IT + ": " + message
