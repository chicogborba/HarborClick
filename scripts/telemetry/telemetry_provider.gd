class_name TelemetryProvider
extends RefCounted
## The seam between the game and any telemetry backend. The build never calls
# a network API: the placeholder keeps the contract, a real provider would be
# swapped in here and nowhere else.


func deliver(events: Array) -> void:
	pass
