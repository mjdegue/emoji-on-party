extends Node

var game: Node
var network: Node

var current_scene: Control = null
var scene_container: Control = null

const SCENES := {
	"lobby": "res://scenes/lobby_scene.tscn",
}


func initialize(game_ref: Node, network_ref: Node, container: Control) -> void:
	game = game_ref
	network = network_ref
	scene_container = container
	game.phase_changed.connect(_on_phase_changed)
	_load_scene("lobby")


func _on_phase_changed(_previous: String, new_phase: String) -> void:
	print("Phase: %s -> %s" % [_previous, new_phase])
	match new_phase:
		"lobby":
			_load_scene("lobby")
		"dealing":
			pass
		"describing":
			pass
		"decoy_rounds":
			pass
		"ended":
			pass


func _load_scene(scene_key: String) -> void:
	if not SCENES.has(scene_key):
		push_warning("Unknown scene: %s" % scene_key)
		return

	if current_scene:
		current_scene.queue_free()
		current_scene = null

	var packed := load(SCENES[scene_key]) as PackedScene
	if packed:
		current_scene = packed.instantiate() as Control
		if current_scene and scene_container:
			scene_container.add_child(current_scene)
