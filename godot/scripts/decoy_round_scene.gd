extends Control

@onready var progress_badge: Label = $VBox/ProgressBadge
@onready var player_name_label: Label = $VBox/PlayerName
@onready var emoji_display: Label = $VBox/EmojiDisplay
@onready var phase_label: Label = $VBox/PhaseLabel
@onready var submission_progress: Label = $VBox/SubmissionProgress


func setup(player_name: String, emoji: String, current_index: int, total: int) -> void:
	if is_inside_tree():
		progress_badge.text = "%d / %d" % [current_index + 1, total]
		player_name_label.text = "%s's emoji:" % player_name
		emoji_display.text = emoji
		phase_label.text = "Writing fake answers..."
		submission_progress.text = ""


func set_sub_phase(sub_phase: String) -> void:
	if not is_inside_tree():
		return
	match sub_phase:
		"collecting_decoys":
			phase_label.text = "Writing fake answers..."
		"collecting_guesses":
			phase_label.text = "Guessing the real phrase..."


func update_progress(submitted: int, expected: int) -> void:
	if is_inside_tree():
		submission_progress.text = "%d / %d submitted" % [submitted, expected]
