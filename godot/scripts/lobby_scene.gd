extends Control

@onready var code_label: Label = $VBox/CodeLabel
@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var start_button: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var title_label: Label = $VBox/Title

var game: Node
var network: Node


func _ready() -> void:
	var main := _find_main()
	if main == null:
		push_error("LobbyScene: Could not find Main node")
		return

	game = main.get_node("GameManager")
	network = main.get_node("NetworkManager")

	network.session_created.connect(_on_session_created)
	game.player_added.connect(_on_player_added)
	game.player_removed.connect(_on_player_removed)
	start_button.pressed.connect(_on_start_pressed)

	_update_ui()


func _find_main() -> Node:
	var node := get_parent()
	while node != null:
		if node.name == "Main":
			return node
		node = node.get_parent()
	return null


func _on_session_created(code: String) -> void:
	code_label.text = "Join at: %s" % code
	_update_ui()


func _on_player_added(_player_id: String, _player_name: String) -> void:
	_update_ui()


func _on_player_removed(_player_id: String) -> void:
	_update_ui()


func _on_start_pressed() -> void:
	game.start_game()


func _update_ui() -> void:
	for child in player_list.get_children():
		child.queue_free()

	if game == null:
		return

	var player_count: int = game.get_player_count()

	for pid in game.players:
		var p: Dictionary = game.players[pid]
		var label := Label.new()
		var status := ""
		if not p["is_connected"]:
			status = " (disconnected)"
		var creator := ""
		if p["is_creator"]:
			creator = " [HOST]"
		label.text = "%s%s%s" % [p["name"], creator, status]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_list.add_child(label)

	start_button.disabled = player_count < game.MIN_PLAYERS
	if player_count < game.MIN_PLAYERS:
		status_label.text = "Waiting for players... (%d/%d)" % [player_count, game.MAX_PLAYERS]
	else:
		status_label.text = "Ready to start!"
