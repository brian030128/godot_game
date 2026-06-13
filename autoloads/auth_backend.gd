extends RefCounted
class_name AuthBackend
## Contract for an authentication backend. Concrete backends (mock now, HTTP
## later) implement login_anonymous() and report completion via `completed`.

## Emitted when an async login finishes. On success `result` is:
##   { "player_id": String, "player_name": String, "session_token": String }
## On failure `result` is empty and `error` describes why.
signal completed(success: bool, result: Dictionary, error: String)


## Begin an anonymous login. Implementations emit `completed` when done.
func login_anonymous() -> void:
	push_error("AuthBackend.login_anonymous() is abstract; use a concrete backend.")
