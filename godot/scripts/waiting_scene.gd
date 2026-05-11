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
	background.color = UI.BG_COLOR
	UI.style_label(title_label, UI.FONT_HEADING, UI.PRIMARY)
	UI.style_label(subtitle_label, UI.FONT_BODY, UI.TEXT_MUTED)
	UI.style_label(progress_label, UI.FONT_SUBHEADING, UI.TEXT_COLOR)
	_update_labels()
	UI.fade_in(self)
	UI.shimmer(title_label)


func _update_labels() -> void:
	title_label.text = _title
	subtitle_label.text = _subtitle
