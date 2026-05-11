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
