extends Control

@onready var progress_badge: Label = $VBox/ProgressBadge
@onready var player_name_label: Label = $VBox/PlayerName
@onready var emoji_display: Label = $VBox/EmojiDisplay
@onready var phase_label: Label = $VBox/PhaseLabel
@onready var submission_progress: Label = $VBox/SubmissionProgress
@onready var background: ColorRect = $Background


func setup(player_name: String, emoji: String, current_index: int, total: int) -> void:
	if not is_inside_tree():
		return

	background.color = Theme.BG_COLOR
	Theme.style_label(progress_badge, Theme.FONT_SMALL, Theme.TEXT_MUTED)
	Theme.style_label(player_name_label, Theme.FONT_SUBHEADING, Theme.TEXT_COLOR)
	Theme.style_label(emoji_display, Theme.FONT_EMOJI, Theme.TEXT_COLOR)
	Theme.style_label(phase_label, Theme.FONT_BODY, Theme.PRIMARY)
	Theme.style_label(submission_progress, Theme.FONT_BODY, Theme.TEXT_MUTED)

	progress_badge.text = "Emoji %d of %d" % [current_index + 1, total]
	player_name_label.text = "%s's emoji:" % player_name
	emoji_display.text = emoji
	phase_label.text = "Write a fake answer!"
	submission_progress.text = ""

	Theme.fade_in(self, 0.3)
	Theme.pulse(emoji_display)


func set_sub_phase(sub_phase: String) -> void:
	if not is_inside_tree():
		return
	match sub_phase:
		"collecting_decoys":
			phase_label.text = "Write a fake answer!"
		"collecting_guesses":
			phase_label.text = "Guess the real one!"


func update_progress(submitted: int, expected: int) -> void:
	if is_inside_tree():
		submission_progress.text = "%d / %d" % [submitted, expected]
