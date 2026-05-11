extends Control

@onready var header_label: Label = $VBox/Header
@onready var ranking_list: VBoxContainer = $VBox/RankingList


func setup(rankings: Array) -> void:
	if not is_inside_tree():
		return

	for child in ranking_list.get_children():
		child.queue_free()

	for r in rankings:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var pos_label := Label.new()
		pos_label.text = "#%d" % r["position"]
		pos_label.custom_minimum_size.x = 60
		hbox.add_child(pos_label)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = r["playerName"]
		hbox.add_child(name_label)

		var score_label := Label.new()
		score_label.text = "%d pts" % r["totalScore"]
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(score_label)

		ranking_list.add_child(hbox)
