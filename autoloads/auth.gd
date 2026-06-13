extends Node
## Authentication orchestrator (autoload as "Auth").
##
## Public surface the UI calls. Owns a swappable AuthBackend instance (mock for
## now). On successful login it populates Game and persists the session via
## SaveManager, then re-emits a UI-friendly signal. To use a real backend later,
## change only the `_backend` assignment below.

## Emitted after a login attempt resolves, for screens to react to.
signal login_completed(success: bool, message: String)

var _backend: AuthBackend


func _ready() -> void:
	_backend = MockAuthBackend.new()
	_backend.completed.connect(_on_backend_completed)


## Kick off an anonymous login. Result arrives via `login_completed`.
func login_anonymous() -> void:
	_backend.login_anonymous()


func _on_backend_completed(success: bool, result: Dictionary, error: String) -> void:
	if not success:
		login_completed.emit(false, error)
		return
	Game.apply_session(result)
	SaveManager.save_session(result)
	login_completed.emit(true, "")
