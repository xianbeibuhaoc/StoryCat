## 一个讲述者的框 —— 名字 + 他这一句。
##
## 点它 = 这一幕的故事用他的说法。
class_name 讲者框
extends PanelContainer

signal 被点(id: String)

@onready var _名字: Label = %名字
@onready var _台词: Label = %台词
@onready var _点击: Button = %点击

var id: String = ""

var _样式: StyleBoxFlat
var _本色: Color = Color.WHITE
var _选中: bool = false
var _悬停: bool = false


func _ready() -> void:
	var 原 := get_theme_stylebox("panel")
	if 原 is StyleBoxFlat:
		_样式 = (原 as StyleBoxFlat).duplicate()
	else:
		_样式 = StyleBoxFlat.new()
	add_theme_stylebox_override("panel", _样式)

	_点击.pressed.connect(func(): 被点.emit(id))
	_点击.mouse_entered.connect(_设悬停.bind(true))
	_点击.mouse_exited.connect(_设悬停.bind(false))
	_刷()


func 设置内容(讲者: Dictionary, 台词: String) -> void:
	id = str(讲者.get("id", ""))
	_本色 = Color(str(讲者.get("色", "#ffffff")))
	_名字.text = str(讲者.get("名字", "?"))
	_名字.add_theme_color_override("font_color", _本色)
	_台词.text = 台词
	_刷()


func 设为选中(值: bool) -> void:
	_选中 = 值
	_刷()


func _设悬停(值: bool) -> void:
	_悬停 = 值
	_刷()


func _刷() -> void:
	if _样式 == null:
		return
	if _选中:
		_样式.bg_color = Color(_本色.r, _本色.g, _本色.b, 0.13)
		_样式.border_color = _本色
		_样式.set_border_width_all(3)
		modulate = Color(1, 1, 1, 1.0)
	elif _悬停:
		_样式.bg_color = Color(0.13, 0.11, 0.09, 0.055)
		_样式.border_color = Color(_本色.r, _本色.g, _本色.b, 0.6)
		_样式.set_border_width_all(2)
		modulate = Color(1, 1, 1, 1.0)
	else:
		_样式.bg_color = Color(0.13, 0.11, 0.09, 0.03)
		_样式.border_color = Color(0.56, 0.51, 0.41, 0.55)
		_样式.set_border_width_all(1)
		modulate = Color(1, 1, 1, 0.92)
