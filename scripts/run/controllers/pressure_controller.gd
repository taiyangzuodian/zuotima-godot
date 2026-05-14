class_name PressureController
extends RefCounted

const RunContext = preload("res://scripts/domain/run_context.gd")

var pressure_state := RunContext.PRESSURE_NORMAL
var speed_multiplier := 1.0
var spawn_interval_multiplier := 1.0
var reduced_duration_sec := 2.5
var increased_duration_sec := 4.0
var _remaining_duration := 0.0


func apply_reduced(duration_sec: float = reduced_duration_sec) -> void:
	pressure_state = RunContext.PRESSURE_REDUCED
	speed_multiplier = 0.85
	spawn_interval_multiplier = 1.15
	_remaining_duration = duration_sec


func apply_increased(duration_sec: float = increased_duration_sec) -> void:
	pressure_state = RunContext.PRESSURE_INCREASED
	speed_multiplier = 1.2
	spawn_interval_multiplier = 0.8
	_remaining_duration = duration_sec


func apply_eased(duration_sec: float = reduced_duration_sec) -> void:
	apply_reduced(duration_sec)


func apply_intense(duration_sec: float = increased_duration_sec) -> void:
	apply_increased(duration_sec)


func tick(delta: float) -> void:
	if pressure_state == RunContext.PRESSURE_NORMAL:
		return
	_remaining_duration -= delta
	if _remaining_duration <= 0.0:
		_reset_to_normal()


func _reset_to_normal() -> void:
	pressure_state = RunContext.PRESSURE_NORMAL
	speed_multiplier = 1.0
	spawn_interval_multiplier = 1.0
	_remaining_duration = 0.0
