extends Control

signal sequence_done

@onready var header_label: Label = $VBox/Header
@onready var emoji_display: Label = $VBox/EmojiDisplay
@onready var author_label: Label = $VBox/AuthorLabel
@onready var card_container: VBoxContainer = $VBox/PhraseList
@onready var countdown_label: Label = $VBox/Countdown
@onready var background: ColorRect = $Background

var _players_ref := {}
var _countdown := 5.0
var _counting_down := false

const VOTE_TICK_DELAY := 0.5
const VOTER_SHOW_DELAY := 0.7
const POST_SHAKE_PAUSE := 0.8
const BETWEEN_CARDS_PAUSE := 2.5
const POST_SEQUENCE_COUNTDOWN := 5.0


func setup(emoji: String, author_name: String, phrases: Array, players_data: Dictionary = {}) -> void:
	if not is_inside_tree():
		return

	_players_ref = players_data

	background.color = UI.BG_COLOR
	UI.style_label(header_label, UI.FONT_HEADING, UI.PRIMARY)
	UI.style_label(emoji_display, UI.FONT_EMOJI, UI.TEXT_COLOR)
	UI.style_label(author_label, UI.FONT_BODY, UI.TEXT_MUTED)
	UI.style_label(countdown_label, UI.FONT_SMALL, UI.TEXT_MUTED)
	countdown_label.text = ""

	emoji_display.text = emoji
	author_label.text = "by %s" % author_name

	for child in card_container.get_children():
		child.queue_free()

	UI.fade_in(self, 0.3)

	_run_sequence(phrases)


func _run_sequence(phrases: Array) -> void:
	# Sort: fakes with votes (ascending), then the real answer last
	var fakes_with_votes: Array = []
	var real_phrase: Dictionary = {}

	for p in phrases:
		if p["isReal"]:
			real_phrase = p
		elif p["selectionCount"] > 0:
			fakes_with_votes.append(p)

	fakes_with_votes.sort_custom(func(a, b): return a["selectionCount"] < b["selectionCount"])

	for phrase in fakes_with_votes:
		if not is_inside_tree():
			return
		await _reveal_single(phrase)
		await get_tree().create_timer(BETWEEN_CARDS_PAUSE).timeout

	if not real_phrase.is_empty() and is_inside_tree():
		await _reveal_single(real_phrase)
		await get_tree().create_timer(BETWEEN_CARDS_PAUSE).timeout

	# Start post-sequence countdown
	if is_inside_tree():
		_countdown = POST_SEQUENCE_COUNTDOWN
		_counting_down = true


func _reveal_single(phrase: Dictionary) -> void:
	var is_real: bool = phrase["isReal"]
	var text: String = phrase["phrase"]
	var vote_count: int = phrase["selectionCount"]
	var voters: Array = phrase.get("selectedBy", [])
	var author_id: String = phrase.get("user", "")
	var phrase_author_name: String = phrase.get("userName", "")

	# --- Step 1: Card appears with just the text ---
	var panel = UI.make_panel(card_container, UI.SURFACE_COLOR)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var text_label := Label.new()
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_label(text_label, UI.FONT_BODY, UI.TEXT_COLOR)
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(text_label)

	var info_hbox := HBoxContainer.new()
	info_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(info_hbox)

	var vote_label := Label.new()
	vote_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_label(vote_label, UI.FONT_SMALL, UI.TEXT_MUTED)
	vote_label.text = ""
	info_hbox.add_child(vote_label)

	var verdict_label := Label.new()
	UI.style_label(verdict_label, UI.FONT_SMALL, UI.TEXT_MUTED)
	verdict_label.text = ""
	verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_hbox.add_child(verdict_label)

	UI.slide_in_from_bottom(panel, 0.4)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return

	# --- Step 2: Count up votes ---
	if vote_count == 0:
		vote_label.text = "0 votes"
		await get_tree().create_timer(0.6).timeout
	else:
		for i in range(1, vote_count + 1):
			if not is_inside_tree():
				return
			if i == 1:
				vote_label.text = "1 vote"
			else:
				vote_label.text = "%d votes" % i
			await get_tree().create_timer(VOTE_TICK_DELAY).timeout

	if not is_inside_tree():
		return

	# --- Step 3: Show who voted for it ---
	for voter_id in voters:
		if not is_inside_tree():
			return
		var voter_name := _get_player_name(voter_id)
		var voter_color := _get_player_color(voter_id)
		var voter_label := Label.new()
		UI.style_label(voter_label, UI.FONT_SMALL, voter_color)
		voter_label.text = "    %s" % voter_name
		vbox.add_child(voter_label)
		UI.fade_in(voter_label, 0.2)
		await get_tree().create_timer(VOTER_SHOW_DELAY).timeout

	if not is_inside_tree():
		return

	# --- Step 4: Shake ---
	await _shake(panel)
	await get_tree().create_timer(POST_SHAKE_PAUSE).timeout
	if not is_inside_tree():
		return

	# --- Step 5: Reveal verdict ---
	if is_real:
		var style = panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var new_style: StyleBoxFlat = style.duplicate()
			new_style.bg_color = Color(0.15, 0.3, 0.15)
			panel.add_theme_stylebox_override("panel", new_style)
		UI.style_label(text_label, UI.FONT_BODY, UI.SUCCESS)
		verdict_label.text = "REAL!"
		UI.style_label(verdict_label, UI.FONT_BODY, UI.SUCCESS)
	else:
		var fake_color := _get_player_color(author_id)
		verdict_label.text = "FAKE — %s" % phrase_author_name
		UI.style_label(verdict_label, UI.FONT_SMALL, fake_color)


func _shake(node: Control) -> void:
	var original_x := node.position.x
	var tween := node.create_tween()
	for i in range(10):
		var offset := 12.0 if i % 2 == 0 else -12.0
		tween.tween_property(node, "position:x", original_x + offset, 0.035)
	tween.tween_property(node, "position:x", original_x, 0.035)
	await tween.finished


func _get_player_name(player_id: String) -> String:
	if _players_ref.has(player_id):
		var p: Dictionary = _players_ref[player_id]
		return p.get("name", "Unknown")
	return "Unknown"


func _get_player_color(player_id: String) -> Color:
	if _players_ref.has(player_id):
		var p: Dictionary = _players_ref[player_id]
		var ci: int = p.get("color_index", 0)
		if ci >= 0 and ci < UI.PLAYER_COLORS.size():
			return UI.PLAYER_COLORS[ci]
	return UI.TEXT_MUTED


func _process(delta: float) -> void:
	if not _counting_down:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_countdown = 0.0
		_counting_down = false
		sequence_done.emit()
	_update_countdown()


func _update_countdown() -> void:
	countdown_label.text = "Next in %d..." % ceili(_countdown)
