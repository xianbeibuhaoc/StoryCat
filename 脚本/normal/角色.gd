## 观众卡片 —— 一个讲述者。
##
## 点击这张卡 = 注视他 = 采纳他这一幕给出的版本。
## 卡片本身不知道游戏在干什么，只负责"显示一个人 + 报告被点了"。
##
## 外观全部在 场景/角色.tscn 里调，这个脚本只管行为。
class_name 观众卡片
extends PanelContainer

## 被采纳时发出，带观众 id。
signal 被点击(id: String)

@export_group("配色")
## 鼠标悬停时的边框色。常态边框色取自场景里的 StyleBox。
@export var 悬停边框色: Color = Color("#6d6178")
## 未被采纳时整张卡的透明度。
@export_range(0.0, 1.0) var 未选中透明: float = 0.32

@onready var _名字: Label = %名字
@onready var _性格: Label = %性格
@onready var _文本: RichTextLabel = %文本
@onready var _点击层: Button = %点击层

var id: String = ""

var _边框: StyleBoxFlat
var _边框常态: Color = Color("#3a3442")
var _强调色: Color = Color.WHITE
var _已选: bool = false
var _悬停: bool = false


func _ready() -> void:
	# 每个实例必须拿一份独立的 StyleBox。
	# 场景里的 SubResource 是共享的——直接改它会一次改掉所有卡。
	var 原 := get_theme_stylebox("panel")
	if 原 is StyleBoxFlat:
		_边框 = (原 as StyleBoxFlat).duplicate()
		_边框常态 = _边框.border_color
	else:
		_边框 = StyleBoxFlat.new()
	add_theme_stylebox_override("panel", _边框)

	_点击层.pressed.connect(_按下)
	_点击层.mouse_entered.connect(_设悬停.bind(true))
	_点击层.mouse_exited.connect(_设悬停.bind(false))


# ============================================================ 对外接口
## 填入一位观众 + 他这一幕给出的文本。
func 设置内容(观众: Dictionary, 正文: String) -> void:
	id = str(观众.get("id", ""))
	_强调色 = Color(str(观众.get("色", "#ffffff")))
	_名字.text = str(观众.get("名字", "?"))
	_名字.add_theme_color_override("font_color", _强调色)
	_性格.text = str(观众.get("性格", ""))
	_文本.text = 正文


## 采纳 / 未采纳的视觉状态。未采纳的整张卡变暗。
func 设为已选(选中: bool) -> void:
	_已选 = 选中
	modulate = Color(1, 1, 1, 1.0) if 选中 else Color(1, 1, 1, 未选中透明)
	_刷新边框()


## 回到"本幕还没选"的状态，并且可以再点。
func 重置外观() -> void:
	_已选 = false
	_悬停 = false
	modulate = Color.WHITE
	_点击层.disabled = false
	_刷新边框()


## 本幕结束后锁死，不再响应点击。
func 锁定() -> void:
	_点击层.disabled = true


# ============================================================ 内部逻辑
func _按下() -> void:
	被点击.emit(id)


func _设悬停(进入: bool) -> void:
	_悬停 = 进入
	_刷新边框()


func _刷新边框() -> void:
	if _已选:
		_边框.border_color = _强调色
		_边框.set_border_width_all(3)
	elif _悬停:
		_边框.border_color = 悬停边框色
		_边框.set_border_width_all(2)
	else:
		_边框.border_color = _边框常态
		_边框.set_border_width_all(2)
