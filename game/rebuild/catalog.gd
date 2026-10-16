extends RefCounted

var books: Dictionary = {}

func _init() -> void:
	for name in ["cities", "vehicles", "welfare", "ingredients", "recipes", "research", "loans", "grades", "balance"]:
		books[name] = JSON.parse_string(FileAccess.get_file_as_string("res://rebuild/data/%s.json" % name))

func all(book: String) -> Array:
	return books.get(book, [])

func get_def(book: String, id: String) -> Dictionary:
	for entry in all(book):
		if entry.id == id:
			return entry
	return {}

func title(book: String, id: String) -> String:
	return str(get_def(book, id).get("name", id))

func balance(key: String):
	return books.balance[key]
