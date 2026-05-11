extends Control

@onready var code_label: Label = $VBox/CodeLabel
@onready var player_list: VBoxContainer = $VBox/PlayerList
@onready var start_button: Button = $VBox/StartButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var title_label: Label = $VBox/Title
@onready var background: ColorRect = $Background

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

	_apply_theme()
	_update_ui()
	UI.fade_in(self)


func _apply_theme() -> void:
	background.color = UI.BG_COLOR
	UI.style_label(title_label, UI.FONT_TITLE, UI.PRIMARY)
	UI.style_label(code_label, UI.FONT_CODE, UI.GOLD)
	UI.style_label(status_label, UI.FONT_BODY, UI.TEXT_MUTED)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = UI.PRIMARY
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.content_margin_top = 16
	btn_style.content_margin_bottom = 16
	start_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = UI.PRIMARY_DARK
	start_button.add_theme_stylebox_override("hover", btn_hover)
	var btn_disabled := btn_style.duplicate()
	btn_disabled.bg_color = UI.SURFACE_LIGHT
	start_button.add_theme_stylebox_override("disabled", btn_disabled)
	start_button.add_theme_font_size_override("font_size", UI.FONT_SUBHEADING)
	start_button.add_theme_color_override("font_color", UI.TEXT_COLOR)


func _find_main() -> Node:
	var node := get_parent()
	while node != null:
		if node.name == "Main":
			return node
		node = node.get_parent()
	return null


func _on_session_created(code: String) -> void:
	code_label.text = code
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

	var idx := 0
	for pid in game.players:
		var p: Dictionary = game.players[pid]

		var color_idx: int = p.get("color_index", idx % UI.PLAYER_COLORS.size())
		var player_color: Color = UI.PLAYER_COLORS[color_idx]

		var panel := UI.make_panel(player_list, UI.SURFACE_COLOR)
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(hbox)

		# Color dot
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = player_color
		hbox.add_child(dot)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(12, 0)
		hbox.add_child(spacer)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var display_name: String = p["name"]
		if p["is_creator"]:
			display_name += "  [HOST]"
		UI.style_label(name_label, UI.FONT_BODY, player_color)
		name_label.text = display_name
		hbox.add_child(name_label)

		if not p["is_connected"]:
			var offline_label := Label.new()
			UI.style_label(offline_label, UI.FONT_SMALL, UI.ERROR)
			offline_label.text = "OFFLINE"
			hbox.add_child(offline_label)

		UI.slide_in_from_bottom(panel, 0.3, idx * 0.05)
		idx += 1

	start_button.disabled = player_count < game.MIN_PLAYERS
	if player_count < game.MIN_PLAYERS:
		status_label.text = "Waiting for players... (%d/%d)" % [player_count, game.MAX_PLAYERS]
	else:
		status_label.text = "Ready! Press SPACE to start"
