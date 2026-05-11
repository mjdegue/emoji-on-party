extends Control

@onready var header_label: Label = $VBox/Header
@onready var score_list: VBoxContainer = $VBox/ScoreList


func setup(player_scores: Array, is_last: bool) -> void:
	if not is_inside_tree():
		return

	if is_last:
		header_label.text = "Final Scores"
	else:
		header_label.text = "Scores"

	for child in score_list.get_children():
		child.queue_free()

	for s in player_scores:
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = s["playerName"]
		hbox.add_child(name_label)

		var points := Label.new()
		var earned: int = s["pointsEarned"]
		if earned > 0:
			points.text = "+%d" % earned
		else:
			points.text = "—"
		hbox.add_child(points)

		var total := Label.new()
		total.text = "%d pts" % s["postRoundScore"]
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(total)

		score_list.add_child(hbox)
