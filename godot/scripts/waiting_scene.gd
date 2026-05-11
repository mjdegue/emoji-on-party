extends Control

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var progress_label: Label = $VBox/Progress

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
	_update_labels()


func _update_labels() -> void:
	title_label.text = _title
	subtitle_label.text = _subtitle
