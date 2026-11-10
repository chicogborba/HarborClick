class_name AdProvider
extends Node
## The seam between the game and a real ad SDK. `AdService` asks the current
## provider to show one rewarded ad for a placement and waits for `finished`;
## the provider decides what "showing" means — a placeholder countdown today,
## an AdMob/H5Ads interstitial later. Swapping providers touches no screen.

## The ad for `placement` ended. `rewarded` true means the player watched it
## to the end and the reward may be paid; false means it was skipped, closed
## or failed, and pays nothing.
signal finished(placement: StringName, rewarded: bool)


func show_rewarded(_placement: StringName) -> void:
	## Virtual. The base implementation grants nothing — a provider that forgot
	## to override must never hand out free rewards — and always answers, so a
	## caller is never left waiting on a signal that never comes.
	finished.emit(_placement, false)
