class_name HazardSpawner
extends Node2D

signal collision_detected

const Hazard = preload("res://scripts/run/world/hazard.gd")
const RunContext = preload("res://scripts/domain/run_context.gd")
const HAZARD_TEXTURE = preload("res://assets/game/track/bush.png")

var base_interval_sec := 3.0
var spawn_x := 1280.0
var spawn_y := 420.0
var spawned_hazards: Array[Hazard] = []
var _elapsed_sec := 0.0
var _run_phase := RunContext.PHASE_WARMUP


func tick(delta: float, spawn_interval_multiplier: float = 1.0) -> void:
	for hazard in spawned_hazards:
		hazard.tick(delta)
	if not _can_spawn():
		return
	_elapsed_sec += delta
	var interval := base_interval_sec * spawn_interval_multiplier
	if _elapsed_sec < interval:
		return
	spawn_hazard()
	_elapsed_sec -= interval


func spawn_hazard() -> Hazard:
	var hazard := Hazard.new()
	hazard.position = Vector2(spawn_x, spawn_y)
	hazard.add_child(_hazard_shape())
	spawned_hazards.append(hazard)
	add_child(hazard)
	return hazard


func _hazard_shape() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = HAZARD_TEXTURE
	sprite.scale = Vector2(0.16, 0.16)
	sprite.position = Vector2(0.0, -18.0)
	return sprite


func set_run_phase(phase: String) -> void:
	_run_phase = phase
	if not _can_spawn():
		_elapsed_sec = 0.0


func _can_spawn() -> bool:
	return _run_phase == RunContext.PHASE_ACTIVE or _run_phase == RunContext.PHASE_JUDGING


func notify_player_collision() -> void:
	if _run_phase != RunContext.PHASE_ACTIVE and _run_phase != RunContext.PHASE_JUDGING:
		return
	collision_detected.emit()
