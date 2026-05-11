extends Control

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var progress_label: Label = $VBox/Progress
@onready var background: ColorRect = $Background

var _title := "Waiting..."
var _subtitle := "Players are working on their phones"


func setup(title: String, subtitle: String) -> void:
	_title = title
	_subtitle = subtitle
	if is_inside_tree():
		_update_labels()


func update_progress(submitted: int, expected: int) -> void:
	if is_inside_tree():
		progress_label.text = "%d / %d" % [submitted, expected]


func _ready() -> void:
	background.color = Theme.BG_COLOR
	Theme.style_label(title_label, Theme.FONT_HEADING, Theme.PRIMARY)
	Theme.style_label(subtitle_label, Theme.FONT_BODY, Theme.TEXT_MUTED)
	Theme.style_label(progress_label, Theme.FONT_SUBHEADING, Theme.TEXT_COLOR)
	_update_labels()
	Theme.fade_in(self)
	Theme.pulse(title_label)


func _update_labels() -> void:
	title_label.text = _title
	subtitle_label.text = _subtitle
