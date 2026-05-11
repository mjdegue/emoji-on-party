extends Control

@onready var header_label: Label = $VBox/Header
@onready var emoji_display: Label = $VBox/EmojiDisplay
@onready var author_label: Label = $VBox/AuthorLabel
@onready var phrase_list: VBoxContainer = $VBox/PhraseList
@onready var countdown_label: Label = $VBox/Countdown
@onready var background: ColorRect = $Background

var _countdown := 15.0
var _counting := false
var _players_ref := {}


func setup(emoji: String, author_name: String, phrases: Array, players_data: Dictionary = {}) -> void:
	if not is_inside_tree():
		return

	_players_ref = players_data

	background.color = Theme.BG_COLOR
	Theme.style_label(header_label, Theme.FONT_HEADING, Theme.PRIMARY)
	Theme.style_label(emoji_display, Theme.FONT_EMOJI, Theme.TEXT_COLOR)
	Theme.style_label(author_label, Theme.FONT_BODY, Theme.TEXT_MUTED)
	Theme.style_label(countdown_label, Theme.FONT_SMALL, Theme.TEXT_MUTED)

	emoji_display.text = emoji
	author_label.text = "by %s" % author_name

	for child in phrase_list.get_children():
		child.queue_free()

	var idx := 0
	for p in phrases:
		var is_real: bool = p["isReal"]
		var panel_color: Color = Theme.SURFACE_COLOR
		if is_real:
			panel_color = Color(0.15, 0.3, 0.15)

		var panel := Theme.make_panel(phrase_list, panel_color)
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(hbox)

		var phrase_label := Label.new()
		phrase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text: String = p["phrase"]
		var text_color := Theme.TEXT_COLOR
		if is_real:
			text_color = Theme.SUCCESS
		Theme.style_label(phrase_label, Theme.FONT_BODY, text_color)
		phrase_label.text = text
		hbox.add_child(phrase_label)

		if is_real:
			var badge := Label.new()
			Theme.style_label(badge, Theme.FONT_SMALL, Theme.SUCCESS)
			badge.text = "REAL"
			hbox.add_child(badge)
		else:
			var author_id: String = p.get("user", "")
			var author_color := _get_player_color(author_id)
			var author := Label.new()
			Theme.style_label(author, Theme.FONT_SMALL, author_color)
			author.text = p["userName"]
			hbox.add_child(author)

		var votes := Label.new()
		var count: int = p["selectionCount"]
		if count == 1:
			votes.text = "1 vote"
		else:
			votes.text = "%d votes" % count
		Theme.style_label(votes, Theme.FONT_SMALL, Theme.TEXT_MUTED)
		votes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(votes)

		Theme.slide_in_from_bottom(panel, 0.4, idx * 0.15)
		idx += 1

	_countdown = 15.0
	_counting = true
	_update_countdown()
	Theme.fade_in(self, 0.3)


func _get_player_color(player_id: String) -> Color:
	if _players_ref.has(player_id):
		var p: Dictionary = _players_ref[player_id]
		var ci: int = p.get("color_index", 0)
		if ci >= 0 and ci < Theme.PLAYER_COLORS.size():
			return Theme.PLAYER_COLORS[ci]
	return Theme.TEXT_MUTED


func _process(delta: float) -> void:
	if not _counting:
		return
	_countdown -= delta
	if _countdown < 0.0:
		_countdown = 0.0
		_counting = false
	_update_countdown()


func _update_countdown() -> void:
	countdown_label.text = "Next in %d..." % ceili(_countdown)
