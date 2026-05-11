extends Node

@onready var network: Node = $NetworkManager
@onready var phrases: Node = $PhraseManager
@onready var game: Node = $GameManager
@onready var display: Node = $DisplayManager
@onready var scene_container: Control = $SceneContainer


func _ready() -> void:
	phrases.load_phrases()
	game.initialize(network, phrases)
	display.initialize(game, network, scene_container)
	network.connect_to_relay()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				_host_advance()
			KEY_S:
				if game.get_phase() == "lobby":
					game.start_game()


func _host_advance() -> void:
	var current_phase: String = game.get_phase()
	match current_phase:
		"lobby":
			game.start_game()
		"describing", "decoy_rounds":
			game.advance_phase()
		"ended":
			game.restart_game()
