extends Node
## Owns persistence of the player session to disk (user://session.json).
##
## Isolated from Game so the global state singleton stays thin: Game holds the
## in-memory session, SaveManager handles file I/O. JSON is used because it is
## human-readable, trivial to inspect/delete while testing, and mirrors the
## shape of a future backend response.

const SESSION_PATH := "user://session.json"


## Returns the saved session dict, or an empty dict if none/invalid.
func load_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open session file.")
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("SaveManager: session file was not a valid object; ignoring.")
	return {}


## Writes the given session dict to disk. Returns true on success.
func save_session(session: Dictionary) -> bool:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not write session file.")
		return false
	file.store_string(JSON.stringify(session, "\t"))
	file.close()
	return true


## Deletes the saved session (used on log out / for test resets).
func clear_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.open("user://").remove("session.json")
