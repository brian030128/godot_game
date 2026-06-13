extends AuthBackend
class_name MockAuthBackend
## In-memory mock backend. Simulates network latency with a timer, then returns
## a generated anonymous profile. Swap this for an HttpAuthBackend later without
## touching the Auth autoload's public API or any UI.

## Simulated round-trip latency in seconds.
@export var latency_seconds: float = 0.6


func login_anonymous() -> void:
	await Engine.get_main_loop().create_timer(latency_seconds).timeout  # fake round-trip

	var suffix := str(randi() % 100000).pad_zeros(5)
	var result := {
		"player_id": "guest_%s" % suffix,
		"player_name": "Dreamer %s" % suffix,
		"session_token": "mock-%d" % Time.get_unix_time_from_system(),
	}
	completed.emit(true, result, "")
