class_name WaterQuality
extends RefCounted
## Automatic visual budget. This intentionally does not read or write player
## preferences: a narrow/mobile viewport gets the lightest shader path.

enum Level { LOW, MEDIUM, HIGH }


static func choose(viewport_size: Vector2, mobile: bool = OS.has_feature("mobile")) -> Level:
	if mobile or viewport_size.x < 520.0 or viewport_size.y < 420.0:
		return Level.LOW
	if viewport_size.x >= 960.0 and viewport_size.y >= 600.0:
		return Level.HIGH
	return Level.MEDIUM


static func from_metrics(metrics: Dictionary, fallback_size: Vector2) -> Level:
	var view: Vector2 = metrics.get("viewport_size", fallback_size)
	return choose(view)


static func foam_spacing(level: Level) -> float:
	match level:
		Level.LOW: return 92.0
		Level.MEDIUM: return 64.0
		_: return 46.0
