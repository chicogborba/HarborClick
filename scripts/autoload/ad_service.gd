extends Node
## AdService: the one door every rewarded ad goes through. Owns one `AdPolicy`
## (the rules: daily caps and cooldowns per placement, persisted as the `ads`
## save section) and one `AdProvider` (the thing that actually shows the ad —
## `PlaceholderAdProvider` until a real SDK is wired in).
##
## Callers ask `show_rewarded(placement, on_reward)` and get a bool: false when
## the placement is unknown, capped out, on cooldown, or an ad is already on
## screen. When the provider reports `rewarded`, the reward callback runs
## exactly once, the show is counted, and `reward_granted` fires; a failed or
## closed ad pays nothing and does not spend the daily cap. With
## `policy.no_ads_pass` set (the future "Passe Sem Anúncios"), the provider is
## skipped but the caps still apply.
##
## The day is the same local-day rule as `DailyOrdersService._current_day`, so
## ad caps and missions roll over at the same midnight.

signal reward_granted(placement: StringName)
signal availability_changed

const SECTION_ID := &"ads"

var policy: AdPolicy
var provider: AdProvider

var _showing: bool = false
var _pending_placement: StringName = &""
var _pending_reward: Callable


func _ready() -> void:
	policy = AdPolicy.new()
	SaveManager.register_section(SECTION_ID, policy.snapshot, _restore, _seed_new)
	set_provider(PlaceholderAdProvider.new())


func _exit_tree() -> void:
	SaveManager.unregister_section(SECTION_ID)


func set_provider(p: AdProvider) -> void:
	## Swap the ad backend without touching any screen. The old provider is
	## disconnected before it is freed, so a late `finished` from it cannot
	## reach a reward callback.
	if provider == p:
		return
	if provider != null:
		provider.finished.disconnect(_on_provider_finished)
		remove_child(provider)
		provider.queue_free()
	provider = p
	if provider != null:
		add_child(provider)
		provider.finished.connect(_on_provider_finished)


func available(placement: StringName) -> bool:
	## May `placement` be shown right now?
	return policy.can_show(placement, Time.get_unix_time_from_system(), _current_day())


func seconds_until(placement: StringName) -> float:
	## Seconds left of `placement`'s cooldown right now.
	return policy.seconds_until(placement, Time.get_unix_time_from_system(), _current_day())


func remaining_today(placement: StringName) -> int:
	## Shows left today; -1 when unlimited.
	return policy.remaining_today(placement, _current_day())


func show_rewarded(placement: StringName, on_reward: Callable) -> bool:
	## Show one rewarded ad for `placement`; on a rewarded finish, `on_reward`
	## runs exactly once. Returns false — and shows nothing — when the
	## placement cannot be shown now or an ad is already on screen.
	var now := Time.get_unix_time_from_system()
	var day := _current_day()
	if _showing:
		return false
	if not policy.can_show(placement, now, day):
		return false
	_showing = true
	_pending_placement = placement
	_pending_reward = on_reward
	if policy.no_ads_pass or provider == null:
		# No-ads pass (or no provider wired): skip the ad, pay the reward, and
		# still count the show against the caps.
		_grant()
		return true
	provider.show_rewarded(placement)
	return true


func _on_provider_finished(placement: StringName, rewarded: bool) -> void:
	if rewarded:
		_grant()
	else:
		# A skipped, closed or failed ad pays nothing and does not count.
		_showing = false
		_pending_placement = &""
		_pending_reward = Callable()


func _grant() -> void:
	var placement := _pending_placement
	var callback := _pending_reward
	_showing = false
	_pending_placement = &""
	_pending_reward = Callable()
	policy.note_shown(placement, Time.get_unix_time_from_system(), _current_day())
	if callback.is_valid():
		callback.call()
	reward_granted.emit(placement)
	availability_changed.emit()


func _restore(data: Dictionary) -> void:
	policy.restore(data)
	availability_changed.emit()


func _seed_new() -> void:
	policy.restore(AdPolicy.seed_new(_current_day()))
	availability_changed.emit()


func _current_day() -> int:
	## The local calendar day. The zone bias comes from the system, so the
	## rules in `AdPolicy` never need a clock of their own.
	var bias_seconds := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return DailyOrders.day_key(Time.get_unix_time_from_system(), bias_seconds)
