## 玩家 —— 地图上走的那个人。
##
## 没有物理、没有碰撞，就是在一个矩形里走。
## 地图只有一屏大，所以也不需要摄像机。
class_name 玩家
extends Control

@export var 速度: float = 330.0

## 能走的地方。由 游戏控制 在换幕时设定。
var 活动区: Rect2 = Rect2(0, 0, 1280, 720)

@onready var _圆: Panel = %圆

var _样式: StyleBoxFlat
var _基准色: Color


func _ready() -> void:
	var 原 := _圆.get_theme_stylebox("panel")
	if 原 is StyleBoxFlat:
		_样式 = (原 as StyleBoxFlat).duplicate()
	else:
		_样式 = StyleBoxFlat.new()
	_圆.add_theme_stylebox_override("panel", _样式)
	_基准色 = _样式.bg_color


func _process(delta: float) -> void:
	var 方向 := _读方向()
	if 方向 == Vector2.ZERO:
		return

	position += 方向 * 速度 * delta
	position.x = clampf(position.x, 活动区.position.x, 活动区.end.x - size.x)
	position.y = clampf(position.y, 活动区.position.y, 活动区.end.y - size.y)


## 走到某个位置（换幕时把玩家放到起点）。
func 移到(点: Vector2) -> void:
	position = 点 - size * 0.5


## 圆心。和讲述者算距离用这个，不然会差半个身位。
func 圆心() -> Vector2:
	return global_position + size * 0.5


func _读方向() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1.0
	if d.length() > 0.0:
		return d.normalized()
	return d
