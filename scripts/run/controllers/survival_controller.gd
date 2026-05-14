class_name SurvivalController
extends RefCounted

const RunContext = preload("res://scripts/domain/run_context.gd")

var shield_state := RunContext.SHIELD_SHIELDED
var break_protection_duration_sec := 0.75
var _break_protection_remaining_sec := 0.0


func reset_for_run() -> void:
	shield_state = RunContext.SHIELD_SHIELDED
	_break_protection_remaining_sec = 0.0


func handle_collision(formal_risk_active: bool) -> void:
	if not formal_risk_active or shield_state == RunContext.SHIELD_DEAD:
		return
	if shield_state == RunContext.SHIELD_SHIELDED:
		shield_state = RunContext.SHIELD_BROKEN
		_break_protection_remaining_sec = break_protection_duration_sec
		return
	if is_break_protected():
		return
	shield_state = RunContext.SHIELD_DEAD


func tick(delta: float) -> void:
	if _break_protection_remaining_sec <= 0.0:
		return
	_break_protection_remaining_sec = maxf(0.0, _break_protection_remaining_sec - delta)


func restore_shield() -> void:
	if shield_state != RunContext.SHIELD_DEAD:
		shield_state = RunContext.SHIELD_SHIELDED
		_break_protection_remaining_sec = 0.0


func is_break_protected() -> bool:
	return shield_state == RunContext.SHIELD_BROKEN and _break_protection_remaining_sec > 0.0


func is_dead() -> bool:
	return shield_state == RunContext.SHIELD_DEAD
