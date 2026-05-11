extends Node

var _phrases: Array[Dictionary] = []
var _categories: Array[String] = []
var _language := "English"
var _enabled_categories: Array[String] = []


func load_phrases(language: String = "English") -> void:
	_language = language
	_phrases.clear()
	_categories.clear()

	var file := FileAccess.open("res://data/phrases.json", FileAccess.READ)
	if file == null:
		push_error("Failed to open phrases.json")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Array:
		push_error("Failed to parse phrases.json")
		return

	for lang_entry in parsed:
		if lang_entry.get("Language", "") != _language:
			continue
		for cat_entry in lang_entry.get("Categories", []):
			var category: String = cat_entry.get("Category", "")
			if category.is_empty():
				continue
			_categories.append(category)
			for phrase in cat_entry.get("Phrases", []):
				_phrases.append({
					"id": phrase.get("id", ""),
					"text": phrase.get("text", ""),
					"category": category,
					"difficulty": phrase.get("difficulty", "easy"),
				})

	_enabled_categories = _categories.duplicate()
	print("Loaded %d phrases in %d categories" % [_phrases.size(), _categories.size()])


func get_random_phrases(count: int, exclude_ids: Array[String] = []) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for p in _phrases:
		if p.id in exclude_ids:
			continue
		if _enabled_categories.size() > 0 and p.category not in _enabled_categories:
			continue
		available.append(p)

	available.shuffle()
	return available.slice(0, count)


func get_categories() -> Array[String]:
	return _categories.duplicate()


func set_enabled_categories(categories: Array[String]) -> void:
	_enabled_categories = categories.duplicate()


func toggle_category(category: String) -> bool:
	var idx := _enabled_categories.find(category)
	if idx >= 0:
		_enabled_categories.remove_at(idx)
		return false
	else:
		_enabled_categories.append(category)
		return true
