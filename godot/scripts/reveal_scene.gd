extends Control

@onready var header_label: Label = $VBox/Header
@onready var emoji_display: Label = $VBox/EmojiDisplay
@onready var author_label: Label = $VBox/AuthorLabel
@onready var phrase_list: VBoxContainer = $VBox/PhraseList
@onready var countdown_label: Label = $VBox/Countdown

var _countdown := 15.0
var _counting := false


func setup(emoji: String, author_name: String, phrases: Array) -> void:
	if not is_inside_tree():
		return

	emoji_display.text = emoji
	author_label.text = "by %s" % author_name

	for child in phrase_list.get_children():
		child.queue_free()

	for p in phrases:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var phrase_label := Label.new()
		phrase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var text: String = p["phrase"]
		if p["isReal"]:
			text += "  [REAL]"
		phrase_label.text = text
		hbox.add_child(phrase_label)

		var author := Label.new()
		author.text = p["userName"]
		hbox.add_child(author)

		var votes := Label.new()
		var count: int = p["selectionCount"]
		if count == 1:
			votes.text = "1 vote"
		else:
			votes.text = "%d votes" % count
		votes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(votes)

		phrase_list.add_child(hbox)

	_countdown = 15.0
	_counting = true
	_update_countdown()


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
