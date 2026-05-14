class_name Hazard
extends Node2D

var base_speed_px_sec := 160.0


func tick(delta: float, speed_multiplier: float = 1.0) -> void:
	position.x -= base_speed_px_sec * speed_multiplier * delta
