## 讲述者 —— 地图上站着的一个"人"。
##
## 你走近，他才亮起来、才开口。
## **注视是字面意思：你走向谁，谁才说话。**
##
## 结构在 场景/讲述者.tscn 里，这个脚本只管行为。
class_name 讲述者
extends Control

## 被采纳时发出，带 id。
signal 被采纳(id: String)

## 走近到多近算"面对面"。
const 感应距离: float = 118.0

@export_group("观感")
@export var 未读暗淡: float = 0.32
@export var 已读暗淡: float = 0.62
@export var 走近放大: float = 1.18

@onready var _圆: Panel = %圆
@onready var _名字: Label = %名字
@onready var _点击: Button = %点击

var id: String = ""
var 台词: String = ""
var 已读: bool = false
var 已采纳: bool = false

var _样式: StyleBoxFlat
var _本色: Color = Color.WHITE
var _脸对脸: bool = false
var _悬停: bool = false
var _基尺寸: Vector2 = Vector2(56, 56)


func _ready() -> void:
	# 每个实例要一份独立的 StyleBox，不然改一个会改到所有人
	var 原 := _圆.get_theme_stylebox("panel")
	if 原 is StyleBoxFlat:
		_样式 = (原 as StyleBoxFlat).duplicate()
	else:
		_样式 = StyleBoxFlat.new()
	_圆.add_theme_stylebox_override("panel", _样式)
	_基尺寸 = _圆.size

	_点击.pressed.connect(_按下)
	_点击.mouse_entered.connect(_设悬停.bind(true))
	_点击.mouse_exited.connect(_设悬停.bind(false))

	_刷新外观()


# ============================================================ 对外
## 填入观众资料 + 他这一幕的台词。
func 设置内容(观众: Dictionary, 文本: String) -> void:
	id = str(观众.get("id", ""))
	_本色 = Color(str(观众.get("色", "#ffffff")))
	_名字.text = str(观众.get("名字", "?"))
	台词 = 文本
	_刷新外观()


## 玩家离他多远（用圆心算）。
func 距离到(点: Vector2) -> float:
	return global_position.distance_to(点)


## 走近 / 走开。
func 设为面对面(值: bool) -> void:
	_脸对脸 = 值
	_刷新外观()


## 玩家读过他了。读过之后就能从远处点他采纳。
func 标记已读() -> void:
	已读 = true
	_刷新外观()


func 设为已采纳(值: bool) -> void:
	已采纳 = 值
	_刷新外观()


## 换一幕时清空状态。
func 重置状态() -> void:
	已读 = false
	已采纳 = false
	_脸对脸 = false
	_悬停 = false
	_刷新外观()


# ============================================================ 内部
func _按下() -> void:
	# 没读过就不能采纳 —— 这是"必须走过去"的成本
	if 已读 and not 已采纳:
		被采纳.emit(id)


func _设悬停(进入: bool) -> void:
	_悬停 = 进入
	_刷新外观()


func _刷新外观() -> void:
	if _样式 == null:
		return

	# 面对面时稍微放大。先算尺寸，圆角要按当前尺寸取半，不然放大后就成了圆角方块。
	var 目标: float = 走近放大 if _脸对脸 else 1.0
	var 大小: Vector2 = _基尺寸 * 目标
	_圆.size = 大小
	_圆.position = (_基尺寸 - 大小) * 0.5

	_样式.bg_color = _本色
	_样式.set_corner_radius_all(int(大小.x * 0.5))

	# 层级：已采纳 > 面对面 > 已读 > 没读过
	var 透明度: float = 未读暗淡
	var 边框宽: int = 0
	if 已采纳:
		透明度 = 1.0
		边框宽 = 4
	elif _脸对脸:
		透明度 = 1.0
		边框宽 = 3
	elif 已读:
		透明度 = 已读暗淡
		边框宽 = 1

	var 高亮: bool = _脸对脸 or _悬停 or 已采纳
	_样式.border_color = _本色.lightened(0.45) if 高亮 else _本色.darkened(0.3)
	_样式.set_border_width_all(边框宽)

	_圆.modulate = Color(1, 1, 1, 透明度)
	_名字.modulate = Color(1, 1, 1, 1.0 if (已读 or _脸对脸 or 已采纳) else 未读暗淡)
	_点击.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if (已读 and not 已采纳) else Control.CURSOR_ARROW
	)
