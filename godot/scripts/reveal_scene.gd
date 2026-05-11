extends Control

signal sequence_done

@onready var header_label: Label = $VBox/Header
@onready var emoji_display: Label = $VBox/EmojiDisplay
@onready var author_label: Label = $VBox/AuthorLabel
@onready var active_area: CenterContainer = $VBox/ActiveArea
@onready var dismissed_area: HBoxContainer = $VBox/DismissedArea
@onready var countdown_label: Label = $VBox/Countdown
@onready var background: ColorRect = $Background

var _players_ref := {}
var _countdown := 5.0
var _counting_down := false
var _active_card: PanelContainer = null

const VOTE_TICK_DELAY := 0.5
const VOTER_SHOW_DELAY := 0.7
const POST_SHAKE_PAUSE := 0.8
const BETWEEN_CARDS_PAUSE := 2.5
const POST_SEQUENCE_COUNTDOWN := 5.0
const DISMISS_DURATION := 0.5


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

	for child in active_area.get_children():
		child.queue_free()
	for child in dismissed_area.get_children():
		child.queue_free()

	UI.fade_in(self, 0.3)
	_run_sequence(phrases)


func _run_sequence(phrases: Array) -> void:
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
		await _reveal_single(phrase, false)
		await _dismiss_active_card(phrase)
		if not is_inside_tree():
			return
		await get_tree().create_timer(BETWEEN_CARDS_PAUSE).timeout

	if not real_phrase.is_empty() and is_inside_tree():
		await _reveal_single(real_phrase, true)
		if is_inside_tree():
			await get_tree().create_timer(BETWEEN_CARDS_PAUSE).timeout

	if is_inside_tree():
		_countdown = POST_SEQUENCE_COUNTDOWN
		_counting_down = true


func _reveal_single(phrase: Dictionary, is_final: bool) -> void:
	var text: String = phrase["phrase"]
	var vote_count: int = phrase["selectionCount"]
	var voters: Array = phrase.get("selectedBy", [])
	var author_id: String = phrase.get("user", "")
	var phrase_author_name: String = phrase.get("userName", "")
	var is_real: bool = phrase["isReal"]

	# Clear previous active card
	for child in active_area.get_children():
		child.queue_free()

	# --- Step 1: Card appears center stage ---
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UI.SURFACE_COLOR
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(700, 0)
	active_area.add_child(panel)
	_active_card = panel

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var text_label := Label.new()
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(text_label, UI.FONT_SUBHEADING, UI.TEXT_COLOR)
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(text_label)

	var info_hbox := HBoxContainer.new()
	info_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_hbox)

	var vote_label := Label.new()
	UI.style_label(vote_label, UI.FONT_BODY, UI.TEXT_MUTED)
	vote_label.text = ""
	info_hbox.add_child(vote_label)

	var voters_vbox := VBoxContainer.new()
	voters_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voters_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(voters_vbox)

	var verdict_label := Label.new()
	verdict_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.style_label(verdict_label, UI.FONT_BODY, UI.TEXT_MUTED)
	verdict_label.text = ""
	vbox.add_child(verdict_label)

	UI.slide_in_from_bottom(panel, 0.5)
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree():
		return

	# --- Step 2: Count votes ---
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

	# --- Step 3: Show voters ---
	for voter_id in voters:
		if not is_inside_tree():
			return
		var voter_name := _get_player_name(voter_id)
		var voter_color := _get_player_color(voter_id)
		var voter_label := Label.new()
		voter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UI.style_label(voter_label, UI.FONT_SMALL, voter_color)
		voter_label.text = voter_name
		voters_vbox.add_child(voter_label)
		UI.fade_in(voter_label, 0.25)
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
		style.bg_color = Color(0.12, 0.35, 0.12)
		panel.add_theme_stylebox_override("panel", style)
		UI.style_label(text_label, UI.FONT_HEADING, UI.SUCCESS)
		verdict_label.text = "THE REAL ANSWER!"
		UI.style_label(verdict_label, UI.FONT_SUBHEADING, UI.SUCCESS)
	else:
		var fake_color := _get_player_color(author_id)
		verdict_label.text = "FAKE — by %s" % phrase_author_name
		UI.style_label(verdict_label, UI.FONT_BODY, fake_color)


func _dismiss_active_card(phrase: Dictionary) -> void:
	if _active_card == null or not is_inside_tree():
		return

	var card := _active_card
	_active_card = null

	# Animate shrinking
	var tween := card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "modulate:a", 0.0, DISMISS_DURATION).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "scale", Vector2(0.7, 0.7), DISMISS_DURATION).set_ease(Tween.EASE_IN)
	await tween.finished

	if not is_inside_tree():
		return

	# Remove the big card
	card.queue_free()

	# Add a small summary to the dismissed area
	var author_id: String = phrase.get("user", "")
	var phrase_author_name: String = phrase.get("userName", "")
	var fake_color := _get_player_color(author_id)

	var mini_panel := PanelContainer.new()
	var mini_style := StyleBoxFlat.new()
	mini_style.bg_color = UI.SURFACE_LIGHT
	mini_style.corner_radius_top_left = 10
	mini_style.corner_radius_top_right = 10
	mini_style.corner_radius_bottom_left = 10
	mini_style.corner_radius_bottom_right = 10
	mini_style.content_margin_left = 14
	mini_style.content_margin_right = 14
	mini_style.content_margin_top = 8
	mini_style.content_margin_bottom = 8
	mini_panel.add_theme_stylebox_override("panel", mini_style)
	mini_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dismissed_area.add_child(mini_panel)

	var mini_vbox := VBoxContainer.new()
	mini_vbox.add_theme_constant_override("separation", 2)
	mini_panel.add_child(mini_vbox)

	var mini_text := Label.new()
	UI.style_label(mini_text, UI.FONT_SMALL, UI.TEXT_MUTED)
	mini_text.text = phrase["phrase"]
	mini_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mini_vbox.add_child(mini_text)

	var mini_author := Label.new()
	UI.style_label(mini_author, 14, fake_color)
	mini_author.text = phrase_author_name
	mini_vbox.add_child(mini_author)

	UI.fade_in(mini_panel, 0.3)


func _shake(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var tween := node.create_tween()
	for i in range(12):
		var angle := 3.0 if i % 2 == 0 else -3.0
		tween.tween_property(node, "rotation_degrees", angle, 0.04)
	tween.tween_property(node, "rotation_degrees", 0.0, 0.04)
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
