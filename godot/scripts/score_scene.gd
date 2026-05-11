extends Control

@onready var header_label: Label = $VBox/Header
@onready var score_list: VBoxContainer = $VBox/ScoreList
@onready var background: ColorRect = $Background


func setup(player_scores: Array, is_last: bool) -> void:
	if not is_inside_tree():
		return

	background.color = UI.BG_COLOR

	if is_last:
		header_label.text = "Final Scores!"
		UI.style_label(header_label, UI.FONT_TITLE, UI.GOLD)
	else:
		header_label.text = "Scores"
		UI.style_label(header_label, UI.FONT_HEADING, UI.PRIMARY)

	for child in score_list.get_children():
		child.queue_free()

	var idx := 0
	for s in player_scores:
		var panel := UI.make_panel(score_list, UI.SURFACE_COLOR)
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(hbox)

		var pos_label := Label.new()
		pos_label.custom_minimum_size.x = 60
		var pos_color := UI.TEXT_COLOR
		if idx == 0:
			pos_color = UI.GOLD
		elif idx == 1:
			pos_color = UI.SILVER
		elif idx == 2:
			pos_color = UI.BRONZE
		UI.style_label(pos_label, UI.FONT_SUBHEADING, pos_color)
		pos_label.text = "#%d" % (idx + 1)
		hbox.add_child(pos_label)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.style_label(name_label, UI.FONT_BODY, UI.TEXT_COLOR)
		name_label.text = s["playerName"]
		hbox.add_child(name_label)

		var earned: int = s["pointsEarned"]
		if earned > 0:
			var points_label := Label.new()
			UI.style_label(points_label, UI.FONT_BODY, UI.SUCCESS)
			points_label.text = "+%d" % earned
			hbox.add_child(points_label)

		var total_label := Label.new()
		UI.style_label(total_label, UI.FONT_SUBHEADING, UI.PRIMARY)
		total_label.text = "%d pts" % s["postRoundScore"]
		total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(total_label)

		UI.slide_in_from_bottom(panel, 0.4, idx * 0.1)
		idx += 1

	UI.fade_in(self, 0.3)
