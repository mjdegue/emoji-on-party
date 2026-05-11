extends Node

var game: Node
var network: Node

var current_scene: Control = null
var scene_container: Control = null

const SCENES := {
	"lobby": "res://scenes/lobby_scene.tscn",
	"waiting": "res://scenes/waiting_scene.tscn",
	"decoy_round": "res://scenes/decoy_round_scene.tscn",
	"reveal": "res://scenes/reveal_scene.tscn",
	"score": "res://scenes/score_scene.tscn",
	"results": "res://scenes/results_scene.tscn",
}


func initialize(game_ref: Node, network_ref: Node, container: Control) -> void:
	game = game_ref
	network = network_ref
	scene_container = container

	game.phase_changed.connect(_on_phase_changed)
	game.decoy_round_started.connect(_on_decoy_round_started)
	game.reveal_ready.connect(_on_reveal_ready)
	game.score_ready.connect(_on_score_ready)
	game.submission_progress.connect(_on_submission_progress)

	_load_scene("lobby")


func _on_phase_changed(_previous: String, new_phase: String) -> void:
	print("Display: %s -> %s" % [_previous, new_phase])

	match new_phase:
		"lobby":
			_load_scene("lobby")
		"dealing":
			_load_scene("waiting")
			_setup_waiting("Dealing Phrases", "Assigning phrases to players...")
		"describing":
			_load_scene("waiting")
			_setup_waiting("Describe with Emojis!", "Players are creating emoji descriptions on their phones")
		"ended":
			_load_scene("results")
			var rankings = game._build_final_rankings()
			if current_scene and current_scene.has_method("setup"):
				current_scene.setup(rankings)


func _on_decoy_round_started(target_name: String, emoji: String, index: int, total: int) -> void:
	_load_scene("decoy_round")
	if current_scene and current_scene.has_method("setup"):
		current_scene.setup(target_name, emoji, index, total)


func _on_reveal_ready(emoji: String, author_name: String, phrases: Array) -> void:
	_load_scene("reveal")
	if current_scene and current_scene.has_method("setup"):
		current_scene.setup(emoji, author_name, phrases)


func _on_score_ready(player_scores: Array, is_last: bool) -> void:
	_load_scene("score")
	if current_scene and current_scene.has_method("setup"):
		current_scene.setup(player_scores, is_last)


func _on_submission_progress(submitted: int, expected: int) -> void:
	if current_scene and current_scene.has_method("update_progress"):
		current_scene.update_progress(submitted, expected)


func _setup_waiting(title: String, subtitle: String) -> void:
	if current_scene and current_scene.has_method("setup"):
		current_scene.setup(title, subtitle)


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
