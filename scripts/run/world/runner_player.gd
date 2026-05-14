class_name RunnerPlayer
extends Node2D

@export var run_texture: Texture2D
@export var jump_texture: Texture2D
@export var run_frame_size := Vector2i(80, 72)
@export var jump_frame_size := Vector2i(80, 82)
@export var run_frame_count := 9
@export var jump_frame_count := 16
@export var sprite_scale := Vector2(1.78, 1.78)
@export var sprite_floor_offset := 58.0

var ground_y := 420.0
var jump_velocity := -900.0
var gravity := 1800.0
var velocity := Vector2.ZERO

@onready var sprite := get_node_or_null("Sprite2D") as Sprite2D

var _run_anim_time := 0.0
var _jump_anim_time := 0.0


func _init() -> void:
	position.y = ground_y


func _ready() -> void:
	position.y = ground_y
	_configure_sprite()
	_update_visual(0.0)


func request_jump() -> bool:
	if not is_grounded():
		return false
	velocity.y = jump_velocity
	_jump_anim_time = 0.0
	return true


func tick(delta: float) -> void:
	if is_grounded() and velocity.y >= 0.0:
		position.y = ground_y
		velocity.y = 0.0
		_update_visual(delta)
		return
	velocity.y += gravity * delta
	position.y += velocity.y * delta
	if position.y >= ground_y:
		position.y = ground_y
		velocity.y = 0.0
	_update_visual(delta)


func is_grounded() -> bool:
	return position.y >= ground_y and velocity.y >= 0.0


func _configure_sprite() -> void:
	if sprite == null:
		return
	sprite.centered = true
	sprite.region_enabled = true
	sprite.scale = sprite_scale
	sprite.position = Vector2(0.0, -sprite_floor_offset)


func _update_visual(delta: float) -> void:
	if sprite == null:
		return
	if is_grounded():
		sprite.texture = run_texture
		_run_anim_time += delta * 10.0
		var run_frame := int(_run_anim_time) % maxi(run_frame_count, 1)
		sprite.region_rect = Rect2(
			Vector2(run_frame * run_frame_size.x, 0.0), Vector2(run_frame_size)
		)
		sprite.position = Vector2(0.0, -sprite_floor_offset + sin(_run_anim_time * 0.85) * 2.0)
	else:
		sprite.texture = jump_texture
		_jump_anim_time += delta * 16.0
		var jump_frame := mini(int(_jump_anim_time), maxi(jump_frame_count - 1, 0))
		sprite.region_rect = Rect2(
			Vector2(jump_frame * jump_frame_size.x, 0.0), Vector2(jump_frame_size)
		)
		sprite.position = Vector2(0.0, -sprite_floor_offset - 6.0)
