## 一个词块。
##
## ============================================================
## 《口径》版的四档质感 —— 这是玩家唯一能"看见"规则的地方，不给数字。
## ============================================================
##
##   档位        底色        字色      额外
##   ─────────────────────────────────────────────────────
##   事实        深蓝灰      亮白      （无）
##   存疑        暖褐        米黄      （无）
##   传闻        冷灰        灰        前后加「」
##   哑          近黑        暗灰      划掉（一条横线）
##
## 另外三种信号：
##   证人数   左下角 n 个小点（1–4）。**这是那条不告诉玩家的规则**：点越少掉越快。
##   背书     金色下划线 —— 你说出口过。这是你自己的痕迹。
##   说话人   左侧一道竖线，用那个人的颜色。
##            ★ 错位引用全靠它：妈妈那句里出现哥哥的颜色，玩家一眼就看见。
##
## 旧的 设为句中词 / 设为空槽 / 设为池中词 保留原样，裸系统.tscn 还在用。
class_name 词块
extends Button

signal 被点(词: String, 句号: int, 槽号: int)

const 类别_句中 := 0
const 类别_空槽 := 1
const 类别_池中 := 2
const 类别_手牌 := 3

## 跟 口径.gd 的档位常量对齐
const 档_哑 := 0
const 档_传闻 := 1
const 档_存疑 := 2
const 档_事实 := 3

const 选中色 := Color("#a06f1e")          ## 黄铜 —— 你的痕迹（跟 色板.你的 一致）

## 每一档的底色 / 字色
## ★ 亮纸版：**纸上没有"卡片"**。底色全部透明，一切靠「墨的浓度」说话。
##   四种色相看起来像四个状态指示灯；同一个墨从浓到淡，才是"字在一个一个消失"。
const 底 := {
	3: Color(0, 0, 0, 0),
	2: Color(0, 0, 0, 0),
	1: Color(0, 0, 0, 0),
	0: Color(0, 0, 0, 0),
}
const 字色 := {
	3: Color("#211c16"),   # 刚写下的浓墨
	2: Color("#564b3b"),   # 放了一段时间
	1: Color("#8a7d67"),   # 快看不清了
	0: Color("#a99d86"),   # 只剩个印子
}
const 墨渍 := Color(0.13, 0.11, 0.09, 0.07)   ## 悬停时的一点墨渍
const 画框 := Color("#8f8268")                 ## 淡墨线
const 纸色 := Color("#d3c7ac")                 ## 纸本身（褪色就往它靠）

## ★★ 亮纸版最要紧的一条：**色相 = 谁写的，浓度 = 掉到什么程度。**
##   妈妈那句里的字用她的褐墨写；老K 插进来一句，那行就是蓝黑墨。
##   而同一个人的笔迹会随着时间**往纸里褪** —— 这就是"记忆在流失"。
const 档_褪色 := {3: 0.00, 2: 0.38, 1: 0.64, 0: 0.86}
## 一个词有多人说过时用的中性墨（不属于任何一张嘴）
const 中性墨 := Color("#211c16")

# ---------------- 状态 ----------------
var 词: String = ""
var 句号: int = -1
var 槽号: int = -1

var _类别: int = 类别_句中
var _清晰: float = 1.0
var _档: int = 档_事实
var _证人数: int = 0
var _背书: bool = false
var _说话人色: Color = Color(0, 0, 0, 0)
var _选中: bool = false
var _悬停: bool = false
var _幽灵词: String = ""
var _闪: float = 0.0

var _样式: StyleBoxFlat
var _条样式: StyleBoxFlat
var _条: Panel
var _字: Label
var _左线: ColorRect
var _点: Label
var _划: ColorRect
var _金线: ColorRect


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	text = ""
	clip_contents = true

	_样式 = StyleBoxFlat.new()
	_样式.set_corner_radius_all(8)
	_样式.bg_color = 底[档_事实]
	_样式.set_border_width_all(1)
	for 态 in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(态, _样式)

	# 能量条 —— 先加，画在最下面
	_条 = Panel.new()
	_条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_条样式 = StyleBoxFlat.new()
	_条样式.set_corner_radius_all(4)
	_条样式.bg_color = Color(0.55, 0.52, 0.48, 0.30)
	_条.add_theme_stylebox_override("panel", _条样式)
	add_child(_条)

	# 说话人色 —— 左边一道竖线
	_左线 = ColorRect.new()
	_左线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_左线.color = Color(0, 0, 0, 0)
	add_child(_左线)

	# 文字
	_字 = Label.new()
	_字.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_字.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_字.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_字.add_theme_font_size_override("font_size", 19)
	add_child(_字)

	# 删除线（哑）
	_划 = ColorRect.new()
	_划.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_划.color = Color(0.75, 0.45, 0.42, 0.85)
	_划.visible = false
	add_child(_划)

	# 金线（你背书过）
	_金线 = ColorRect.new()
	_金线.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_金线.color = 选中色
	_金线.visible = false
	add_child(_金线)

	# 证人数小点
	_点 = Label.new()
	_点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_点.add_theme_font_size_override("font_size", 10)
	_点.add_theme_color_override("font_color", Color(0.13, 0.11, 0.09, 0.34))
	_点.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_点)

	resized.connect(_摆)
	pressed.connect(func(): 被点.emit(词, 句号, 槽号))
	mouse_entered.connect(func(): _悬停 = true; _刷())
	mouse_exited.connect(func(): _悬停 = false; _刷())
	set_process(false)


## 这个字该用什么墨写：
##   色相  = 谁说的（一个人说过就用他的笔；多人说过就用中性墨）
##   浓度  = 掉到第几档（往纸色方向褪）
func _墨色() -> Color:
	var 基: Color = _说话人色 if _说话人色.a > 0.01 else 中性墨
	return 基.lerp(纸色, float(档_褪色.get(_档, 0.0)))


# ============================================================ ★ 主入口
## 故事里的一个词。
##   清晰度 / 档位  由 口径.gd 算好传进来（避免阈值两处各写一份）
##   证人数         左下角的小点
##   背书           金色下划线
##   说话人色       左边竖线；多人说过就传一个中性色
func 设为口径词(
	内容: String, 清晰度: float, 档位: int, 证人数: int, 背书: bool,
	选中: bool, 说话人色: Color, 在句号: int, 在槽号: int, 说明: String = ""
) -> void:
	_类别 = 类别_句中
	词 = 内容
	tooltip_text = 说明
	_清晰 = 清晰度
	_档 = clampi(档位, 0, 3)
	_证人数 = 证人数
	_背书 = 背书
	_说话人色 = 说话人色
	_选中 = 选中
	_幽灵词 = ""
	句号 = 在句号
	槽号 = 在槽号

	# 传闻 —— 前后加引号，念起来就是"据说"
	if _档 == 档_传闻:
		_字.text = "「%s」" % 内容
	else:
		_字.text = 内容

	_量尺寸()
	set_process(_档 == 档_哑 or 清晰度 < 0.34)
	_刷()
	_摆()


## 一幕的手牌：本幕四个人说过、你还没放进故事里的词。
func 设为手牌词(内容: String, 证人数: int, 选中: bool, 说话人色: Color, 说明: String = "") -> void:
	_类别 = 类别_手牌
	词 = 内容
	tooltip_text = 说明
	_清晰 = 1.0
	_档 = 档_事实
	_证人数 = 证人数
	_背书 = false
	_说话人色 = 说话人色
	_选中 = 选中
	_幽灵词 = ""
	句号 = -1
	槽号 = -1
	_字.text = 内容
	_量尺寸()
	set_process(false)
	_刷()
	_摆()


# ============================================================ 旧接口（裸系统.tscn 还在用）
func 设为句中词(内容: String, 清晰度: float, 在句号: int, 在槽号: int, 选中: bool) -> void:
	_类别 = 类别_句中
	词 = 内容
	_清晰 = 清晰度
	_选中 = 选中
	_幽灵词 = ""
	句号 = 在句号
	槽号 = 在槽号
	_证人数 = 0
	_背书 = false
	_说话人色 = Color(0, 0, 0, 0)
	_档 = 档_事实 if 清晰度 >= 0.62 else (档_存疑 if 清晰度 >= 0.30 else (档_哑 if 清晰度 <= 0.0 else 档_传闻))
	_字.text = 内容
	_量尺寸()
	set_process(清晰度 < 0.5)
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
	custom_minimum_size = _字.get_minimum_size() + Vector2(38, 18)


# ============================================================ 摆位
func _摆() -> void:
	if _条 == null:
		return
	var 边: float = 3.0
	var 宽: float = maxf(0.0, size.x - 边 * 2.0)
	var 高: float = maxf(0.0, size.y - 边 * 2.0)

	# 能量条：字后面那道横杠，长度 = 还剩下多少
	_条.position = Vector2(边, 边)
	_条.size = Vector2(宽 * _条比例(), 高)

	# 说话人竖线 —— ★ 亮纸版不用它了：字本身就用那个人的墨写，"谁的笔"直接看得见。
	#（留着这个节点只是不想动老代码；想恢复的话把 visible 改回去）
	_左线.visible = false

	_字.position = Vector2.ZERO
	_字.size = size

	# 删除线：横过整个字
	var 哑: bool = _类别 == 类别_句中 and _档 == 档_哑
	_划.visible = 哑
	if 哑:
		var 文宽: float = maxf(0.0, size.x - 26.0)
		_划.position = Vector2((size.x - 文宽) * 0.5, size.y * 0.5 - 1.0)
		_划.size = Vector2(文宽, 2.0)

	# 金线：你背书过
	_金线.visible = _背书 and _类别 == 类别_句中
	if _金线.visible:
		var 宽2: float = clampf(_字.get_minimum_size().x, 12.0, maxf(12.0, size.x - 20.0))
		_金线.position = Vector2((size.x - 宽2) * 0.5, size.y - 9.0)
		_金线.size = Vector2(宽2, 2.0)

	# 证人数小点
	_点.text = "•".repeat(clampi(_证人数, 0, 4))
	_点.position = Vector2(8, 2)
	_点.size = Vector2(maxf(0.0, size.x - 16.0), 12.0)


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

	if _类别 == 类别_空槽:
		_条.visible = false
		_样式.bg_color = 墨渍
		_样式.border_color = (
			Color(选中色.r, 选中色.g, 选中色.b, 0.75) if _选中
			else Color(画框.r, 画框.g, 画框.b, 0.45)
		)
		_样式.set_border_width_all(2)
		_字.modulate = Color(1, 1, 1, 0.7 if _选中 else 0.3)
		return

	if _类别 == 类别_池中:
		_条.visible = false
		_样式.bg_color = 墨渍
		_样式.border_color = (
			Color(选中色.r, 选中色.g, 选中色.b, 0.9) if _选中
			else Color(画框.r, 画框.g, 画框.b, 0.55)
		)
		_样式.set_border_width_all(2 if _选中 else 1)
		_字.add_theme_color_override("font_color", 字色[档_存疑])
		_字.modulate = Color(1, 1, 1, 1.0 if _选中 else 0.72)
		return

	# ---------------- 手牌：还没写到纸上的话 ----------------
	# 一张淡墨底 + 底下一道墨线，像贴在纸边上的便签。选中 → 黄铜。
	if _类别 == 类别_手牌:
		_条.visible = false
		_样式.bg_color = Color(画框.r, 画框.g, 画框.b, 0.16 if _选中 else 0.07)
		_样式.border_color = (
			Color(选中色.r, 选中色.g, 选中色.b, 0.95) if _选中
			else Color(画框.r, 画框.g, 画框.b, 0.40)
		)
		_样式.set_border_width_all(2 if _选中 else 1)
		_字.add_theme_color_override("font_color", 字色[档_事实])
		_字.modulate = Color(1, 1, 1, 1.0 if _选中 else 0.82)
		return

	# ---------------- 句中词：写在纸上的字 ----------------
	# ★ 纸上没有卡片。底色只在悬停/选中时出现一点点墨渍，其余全是透明的。
	var 亮: float = clampf(_清晰, 0.0, 1.0)
	var 哑: bool = _档 == 档_哑

	if _选中:
		_样式.bg_color = Color(选中色.r, 选中色.g, 选中色.b, 0.12)
	elif _悬停:
		_样式.bg_color = 墨渍
	else:
		_样式.bg_color = Color(0, 0, 0, 0)

	# 边框：不画框。只有选中 / 背书时才浮出一道线来。
	if _选中:
		_样式.border_color = Color(选中色.r, 选中色.g, 选中色.b, 0.95)
		_样式.set_border_width_all(1)
	elif _背书:
		_样式.border_color = Color(选中色.r, 选中色.g, 选中色.b, 0.42)
		_样式.set_border_width_all(1)
	else:
		_样式.border_color = Color(0, 0, 0, 0)
		_样式.set_border_width_all(0)

	# 能量条：只在真的快没了的时候才出来 —— 平时别当仪表盘用。
	_条.visible = (亮 < 0.5 and not 哑) or 哑
	if _条.visible:
		var 条色: Color
		if 哑:
			条色 = Color(0.61, 0.23, 0.16, 0.30)
		else:
			条色 = Color(0.61, 0.23, 0.16, 0.42).lerp(Color(画框.r, 画框.g, 画框.b, 0.35), 亮 * 2.0)
		_条样式.bg_color = 条色

	# 字色 = 谁的笔 + 褪到什么程度
	_字.add_theme_color_override("font_color", _墨色())

	# ⑤ 哑掉的 / 快掉的，呼吸
	var 透明: float = 1.0
	if _档 == 档_哑:
		透明 = 0.55 + 0.12 * (0.5 + 0.5 * sin(_闪 * 0.6))
	elif _清晰 < 0.34:
		var 波: float = 0.5 + 0.5 * sin(_闪)
		透明 = 0.55 + 0.45 * 波
	if _选中:
		透明 = 1.0
	_字.modulate = Color(1, 1, 1, 透明)
