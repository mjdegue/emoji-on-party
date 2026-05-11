extends Node

var game: Node
var network: Node

# Scene references (will be loaded dynamically)
var current_scene: Control = null
var scene_container: Control = null

const SCENES := {
	"lobby": "res://scenes/lobby_scene.tscn",
}


func initialize(game_ref: Node, network_ref: Node) -> void:
	game = game_ref
	network = network_ref
	game.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(previous: String, new_phase: String) -> void:
	print("Phase: %s -> %s" % [previous, new_phase])
	# Scene switching will be implemented as scenes are built
	match new_phase:
		"lobby":
			_load_scene("lobby")
		"dealing":
			pass  # TODO: dealing scene
		"describing":
			pass  # TODO: waiting for emojis scene
		"decoy_rounds":
			pass  # TODO: decoy round scene
		"ended":
			pass  # TODO: final results scene


func _load_scene(scene_key: String) -> void:
	if scene_key not in SCENES:
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
