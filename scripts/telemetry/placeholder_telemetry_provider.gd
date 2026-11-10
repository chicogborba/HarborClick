class_name PlaceholderTelemetryProvider
extends TelemetryProvider
## Accepts events and does nothing with them — the game's telemetry is local
# only (see `Telemetry`): the JSONL mirror in `user://` is the player-visible
# record, this provider is where a real backend would plug in.


func deliver(_events: Array) -> void:
	pass
