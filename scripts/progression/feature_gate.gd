class_name FeatureGate
extends RefCounted
## One question, asked from anywhere: has the terminal grown enough for this?
##
## `TerminalLevelService` registers its rules here while it lives. With no
## service — a headless suite that builds only a world, the capture harness
## before `Main` — everything reads as unlocked, so a system is never hidden by
## the absence of the thing that decides to hide it.

static var _rules: TerminalLevel = null


static func bind(rules: TerminalLevel) -> void:
	_rules = rules


static func unbind(rules: TerminalLevel) -> void:
	if _rules == rules:
		_rules = null


static func unlocked(feature: StringName) -> bool:
	return _rules == null or _rules.unlocked(feature)


static func level() -> int:
	## The terminal's level, 1 when nothing is bound (headless suites).
	return _rules.level if _rules != null else 1
