## 一个词块。
##
## 清晰度用**三重表现**，不用数字：
##   ① 底色深浅  —— 越淡整块越暗
##   ② 能量条    —— 字后面一条横杠，长度 = 剩下的清晰度，低于一半变红
##   ③ 文字闪烁  —— 快没了的时候一下一下地闪，等于在喊"我快没了"
##
## 三种身份：句中词 / 空槽 / 池中词（已经掉了的）
class_name 词块
extends Button

signal 被点(词: String, 句号: int, 槽号: int)

const 类别_句中 := 0
const 类别_空槽 := 1
const 类别_池中 := 2

const 选中色 := Color(0.87, 0.72, 0.42)
const 条_满 := Color(0.86, 0.79, 0.60)
const 条_中 := Color(0.86, 0.56, 0.33)
const 条_低 := Color(0.82, 0.29, 0.27)

var 词: String = ""
var 句号: int = -1
var 槽号: int = -1

var _类别: int = 类别_句中
var _清晰: float = 1.0
var _选中: bool = false
var _幽灵词: String = ""
var _闪: float = 0.0

var _样式: StyleBoxFlat
var _条样式: StyleBoxFlat
var _条: Panel
var _字: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = ""                       # Button 自己不画字，字交给下面的 Label
	clip_contents = true

	_样式 = StyleBoxFlat.new()
	_样式.set_corner_radius_all(8)
	_样式.bg_color = Color(0.13, 0.12, 0.17, 1)
	_样式.set_border_width_all(1)
	for 态 in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(态, _样式)

	# 能量条 —— 先加，画在最下面
	_条 = Panel.new()
	_条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_条样式 = StyleBoxFlat.new()
	_条样式.set_corner_radius_all(4)
	_条样式.bg_color = 条_满
	_条.add_theme_stylebox_override("panel", _条样式)
	add_child(_条)

	# 文字 —— 后加，画在能量条上面
	_字 = Label.new()
	_字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_字.add_theme_font_size_override("font_size", 19)
	add_child(_字)

	resized.connect(_摆)
	pressed.connect(func(): 被点.emit(词, 句号, 槽号))
	set_process(false)


# ============================================================ 三种身份
func 设为句中词(内容: String, 清晰度: float, 在句号: int, 在槽号: int, 选中: bool) -> void:
	_类别 = 类别_句中
	词 = 内容
	_清晰 = 清晰度
	_选中 = 选中
	_幽灵词 = ""
	句号 = 在句号
	槽号 = 在槽号
	_字.text = 内容
	_量尺寸()
	set_process(清晰度 < 0.5)       # 快掉了才开始闪
	_刷()
	_摆()


func 设为空槽(在句号: int, 在槽号: int, 幽灵词: String = "") -> void:
	_类别 = 类别_空槽
	词 = ""
	_幽灵词 = 幽灵词
	_选中 = 幽灵词 != ""
	_清晰 = 0.0
	句号 = 在句号
	槽号 = 在槽号
	_字.text = 幽灵词 if 幽灵词 != "" else "　　"
	_量尺寸()
	set_process(false)
	_刷()
	_摆()


func 设为池中词(内容: String, 选中: bool) -> void:
	_类别 = 类别_池中
	词 = 内容
	_幽灵词 = ""
	_选中 = 选中
	_清晰 = 0.0
	句号 = -1
	槽号 = -1
	_字.text = 内容
	_量尺寸()
	set_process(false)
	_刷()
	_摆()


func _量尺寸() -> void:
	custom_minimum_size = _字.get_minimum_size() + Vector2(34, 16)


# ============================================================ 摆位
func _摆() -> void:
	if _条 == null:
		return
	var 边: float = 3.0
	var 宽: float = maxf(0.0, size.x - 边 * 2.0)
	var 高: float = maxf(0.0, size.y - 边 * 2.0)
	_条.position = Vector2(边, 边)
	_条.size = Vector2(宽 * _条比例(), 高)
	_字.position = Vector2.ZERO
	_字.size = size


func _条比例() -> float:
	if _类别 != 类别_句中:
		return 0.0
	return clampf(_清晰, 0.0, 1.0)


# ============================================================ 画
func _process(delta: float) -> void:
	_闪 += delta * 5.5
	_刷()


func _刷() -> void:
	if _样式 == null:
		return

	match _类别:
		类别_空槽:
			_条.visible = false
			_样式.bg_color = Color(0.11, 0.10, 0.15, 1)
			_样式.border_color = (
				Color(选中色.r, 选中色.g, 选中色.b, 0.75) if _选中
				else Color(1, 1, 1, 0.18)
			)
			_样式.set_border_width_all(2)
			_字.modulate = Color(1, 1, 1, 0.75 if _选中 else 0.35)

		类别_池中:
			_条.visible = false
			_样式.bg_color = Color(0.16, 0.14, 0.20, 1)
			_样式.border_color = (
				Color(选中色.r, 选中色.g, 选中色.b, 0.9) if _选中
				else Color(0.42, 0.38, 0.48, 0.6)
			)
			_样式.set_border_width_all(2 if _选中 else 1)
			_字.modulate = Color(1, 1, 1, 1.0 if _选中 else 0.5)

		_:
			_条.visible = true
			var 亮: float = clampf(_清晰, 0.0, 1.0)

			# ① 底色：越危险越往暗红走（跟条长是两个独立信号）
			var t: float = pow(1.0 - 亮, 2.5)
			_样式.bg_color = Color(0.13, 0.12, 0.17).lerp(Color(0.30, 0.09, 0.10), t)

			# ② 能量条：长度 = 剩余，颜色从暖白走到红
			if 亮 > 0.5:
				_条样式.bg_color = 条_中.lerp(条_满, (亮 - 0.5) * 2.0)
			else:
				_条样式.bg_color = 条_低.lerp(条_中, 亮 * 2.0)

			# ③ 选中：金边
			if _选中:
				_样式.border_color = 选中色
				_样式.set_border_width_all(2)
			else:
				_样式.border_color = Color(0.42, 0.39, 0.50, 0.5)
				_样式.set_border_width_all(1)

			# ④ 文字闪烁：低于 0.5 开始一下一下地闪
			var 透明: float = 1.0
			if _清晰 < 0.5:
				var 波: float = 0.5 + 0.5 * sin(_闪)
				透明 = 0.35 + 0.65 * 波
			if _选中:
				透明 = 1.0
			_字.modulate = Color(1, 1, 1, 透明)
			# 条也跟着呼吸，让"低"更抓眼
			_条.modulate = (
				Color(1, 1, 1, 0.6 + 0.4 * sin(_闪)) if _清晰 < 0.35 else Color(1, 1, 1, 1)
			)
