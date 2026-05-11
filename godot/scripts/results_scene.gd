extends Control

@onready var header_label: Label = $VBox/Header
@onready var ranking_list: VBoxContainer = $VBox/RankingList
@onready var background: ColorRect = $Background


func setup(rankings: Array) -> void:
	if not is_inside_tree():
		return

	background.color = Theme.BG_COLOR
	Theme.style_label(header_label, Theme.FONT_TITLE, Theme.GOLD)

	for child in ranking_list.get_children():
		child.queue_free()

	var idx := 0
	for r in rankings:
		var position: int = r["position"]
		var panel_color := Theme.SURFACE_COLOR
		if position == 1:
			panel_color = Color(0.25, 0.2, 0.05)

		var panel := Theme.make_panel(ranking_list, panel_color)
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(hbox)

		var pos_label := Label.new()
		pos_label.custom_minimum_size.x = 80
		var pos_color := Theme.TEXT_COLOR
		if position == 1:
			pos_color = Theme.GOLD
		elif position == 2:
			pos_color = Theme.SILVER
		elif position == 3:
			pos_color = Theme.BRONZE
		Theme.style_label(pos_label, Theme.FONT_HEADING, pos_color)
		pos_label.text = "#%d" % position
		hbox.add_child(pos_label)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_size := Theme.FONT_SUBHEADING
		if position == 1:
			name_size = Theme.FONT_HEADING
		Theme.style_label(name_label, name_size, Theme.TEXT_COLOR)
		name_label.text = r["playerName"]
		hbox.add_child(name_label)

		var score_label := Label.new()
		Theme.style_label(score_label, Theme.FONT_HEADING, Theme.PRIMARY)
		score_label.text = "%d pts" % r["totalScore"]
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(score_label)

		Theme.slide_in_from_bottom(panel, 0.5, idx * 0.15)
		idx += 1

	Theme.fade_in(self, 0.3)
