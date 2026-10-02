## 四张嘴 —— **默认界面**。
##
## ============================================================
## ★★ 这一层是给你推翻的。
## ============================================================
##
## 它只干两件事：
##   ① 拿一个 对局（`脚本/系统/对局.gd`）—— 规则和状态全在那儿，这里一行规则都没有
##   ② 把 对局 的状态画成"一堆框和按钮"
##
## 你要接管界面 / 交互 / 美术的话，有三条路，从轻到重：
##
##   【轻】把 `搭默认界面` 那个 @export 关掉 —— 默认的框按钮全不生成，
##        逻辑照跑、信号照发。你自己的节点连 `局.词哑了` 之类的信号去演。
##
##   【中】留着这个脚本，把 `_搭默认界面()` 之后的东西替换成你自己的。
##
##   【重】整个文件删掉，自己写一个：
##          var 局 := 对局.new()
##          局.你说了.connect(...)
##          局.下一幕()
##        对局 是 RefCounted，不依赖任何节点，随便塞哪里都行。
##
## ============================================================
## 世界跟着故事走，连这两个信号就够了：
##   局.词哑了(词, 连累)      —— 某个词被划掉（现场里对应的东西该灭了）
##   局.词变档(词, 旧档, 新档) —— 从事实掉到传闻（那东西该闪了）
## 词对应现场哪个物件，看 `口径词表.物件`，或者 局.取状态() 里每个词的 "物件" 字段。
extends Control

const 词块脚本 := preload("res://脚本/normal/词块.gd")
const 讲者框场景 := preload("res://场景/讲者框.tscn")

## ★ 关掉它 = 你接管界面。逻辑照跑，信号照发。
@export var 搭默认界面: bool = true

## ★ 这就是整局游戏。外面想动手就动它：`$四张嘴.局.下一幕()`
var 局: 对局 = 对局.new()

@onready var _幕次行: Label = %幕次行
@onready var _遗忘行: Label = %遗忘行
@onready var _句子区: VBoxContainer = %句子区
@onready var _故事空: Label = %故事空
@onready var _嘴区: VBoxContainer = %嘴区
@onready var _遗忘词行: HBoxContainer = %遗忘词行
@onready var _遗忘框: PanelContainer = %遗忘框
@onready var _提示行: Label = %提示行
@onready var _下一幕按钮: Button = %下一幕按钮
@onready var _重来按钮: Button = %重来按钮
@onready var _说出口按钮: Button = %说出口按钮
@onready var _换掉按钮: Button = %换掉按钮
@onready var _撤销按钮: Button = %撤销按钮

var _框表: Dictionary = {}
var _笔记按钮: Button = null
var _笔记层: Control = null
var _结算层: Control = null
var _代: int = 0


func _ready() -> void:
	_故事空.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not 搭默认界面:
		return

	# ---- 默认界面的接线。你的节点可以照抄这几行连到 `局` 上。----
	局.换幕.connect(_当_换幕)
	局.你选了.connect(_当_你选了)
	局.你说了.connect(_当_你说了)
	局.你换了.connect(_当_你换了)
	局.你撤了.connect(_当_你撤了)
	局.词哑了.connect(_当_词哑了)
	局.完局.connect(_当_完局)

	_下一幕按钮.pressed.connect(func(): 局.下一幕())
	_重来按钮.pressed.connect(重来)
	_说出口按钮.pressed.connect(func(): 局.说出口())
	_换掉按钮.pressed.connect(func(): 局.开始换词(); _重建())
	_撤销按钮.pressed.connect(func(): 局.撤销草稿())
	_搭笔记按钮()

	局.重来()


# ============================================================ 重来
func 重来() -> void:
	_代 += 1
	if _结算层 != null and is_instance_valid(_结算层):
		_结算层.queue_free()
	_结算层 = null
	if _笔记层 != null and is_instance_valid(_笔记层):
		_笔记层.queue_free()
	_笔记层 = null
	局.重来()


# ============================================================ 信号 → 界面
func _当_换幕(_幕号: int, _总数: int, 是不是开幕: bool) -> void:
	_重建()
	if 是不是开幕:
		_提示行.text = 口径词表.提示_选人
		return
	var 状态: Dictionary = 局.取状态()
	var 推: String = ""
	if 状态["幕"] == 1 and 局.手记.is_empty():
		推 = "\n试试看：点下面一个词，按【说出口】。你说的话，下一幕会有人接。"
	_提示行.text = "第 %d 幕。%s%s" % [int(状态["幕"]) + 1, 口径词表.提示_选人, 推]


func _当_你选了(id: String) -> void:
	_重建()
	if id == "":
		_提示行.text = "取消选择。这一幕的故事还空着。"
		return
	var 下一步: String = 口径词表.提示_动作
	if 局.动作已做:
		下一步 = "说法换了，草稿还在。按【下一幕】生效，或者按【撤销草稿】重来。"
	_提示行.text = "用了「%s」的说法 —— 他%s。\n%s" % [
		口径词表.名字(id), str(口径词表.取讲述者(id).get("短", "")), 下一步
	]


func _当_你说了(词: String, 在场: bool) -> void:
	_重建()
	if 在场:
		_提示行.text = (
			"【草稿】「%s」被你说出口了 —— 这一幕有人提过它，\n"
			+ "所以下一幕会有人接这句话。不管他是接住还是顶回来，都算他也说了。"
		) % 词
	else:
		_提示行.text = (
			"【草稿】「%s」被你说出口了，它被托起来一截。\n"
			+ "★ 但这一幕没人提它 —— 没人会跟着你说，它还是只有你一个人记得。"
		) % 词


func _当_你换了(旧词: String, 新词: String, 处数: int) -> void:
	_重建()
	_提示行.text = (
		"【草稿】「%s」换成了「%s」—— 故事里一共 %d 处，一起变了。\n"
		+ "这段历史结不结实，看「%s」自己有几个人记得。按【下一幕】生效。"
	) % [旧词, 新词, 处数, 新词]


func _当_你撤了() -> void:
	_重建()
	_提示行.text = "草稿撤了，这一幕当没动过手。词还是会照掉 —— 什么也不做也是一种选择。"


## ★ "世界跟着故事走"的默认示范：词被划掉时补一句。
##   你要接管的，就是把这个换成"现场里那盏灯灭了"。
func _当_词哑了(词: String, 连累: Array) -> void:
	var 句: String = "「%s」划掉了。" % 词
	if not 连累.is_empty():
		句 += "　同一句的 %s 也被拖下去了。" % "、".join(连累)
	# 用追加而不是覆盖 —— 幕推进的时候"换幕"的提示可能先到
	_提示行.text = _提示行.text + "\n" + 句


func _当_完局() -> void:
	_重建()
	_放结算()


# ============================================================ 画
func _重建() -> void:
	if not 搭默认界面 or 局.完了:
		return
	var 状态: Dictionary = 局.取状态()

	_幕次行.text = "第 %d 幕 / %d　·　%s" % [
		int(状态["幕"]) + 1, int(状态["总幕数"]), str(状态["幕名"])
	]
	var 哑了: int = int(状态["哑了几个"])
	_遗忘行.text = "已划掉 %d" % 哑了
	_遗忘行.add_theme_color_override(
		"font_color", Color("#9c3a2a") if 哑了 > 0 else Color("#6b6152")
	)

	_画故事(状态)
	_画嘴(状态)
	_画手牌(状态)
	_刷按钮(状态)


func _画故事(状态: Dictionary) -> void:
	for 子 in _句子区.get_children():
		_句子区.remove_child(子)
		子.queue_free()

	if (状态["故事"] as Array).is_empty():
		_故事空.visible = true
		_故事空.text = 口径词表.前提 + "\n\n" + 口径词表.任务
		return
	_故事空.visible = false

	var 故事: Array = 状态["故事"]
	# 倒着画 —— 最新的那一句在最上面，玩家不用滚
	for i in range(故事.size() - 1, -1, -1):
		var 句: Dictionary = 故事[i]
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 7)
		_句子区.add_child(行)
		for 条 in 句["词"]:
			_造词块(条, false, 行)


func _画嘴(状态: Dictionary) -> void:
	for 子 in _嘴区.get_children():
		_嘴区.remove_child(子)
		子.queue_free()
	_框表.clear()

	for 人 in 状态["讲者"]:
		var 框: 讲者框 = 讲者框场景.instantiate()
		_嘴区.add_child(框)
		框.设置内容({
			"id": str(人["id"]),
			"名字": "%s · %s" % [str(人["名字"]), str(人["短"])],
			"色": str(人["色"]),
		}, str(人["台词"]))
		框.设为选中(bool(人["在说"]))
		框.被点.connect(_点讲者)
		_框表[str(人["id"])] = 框


func _画手牌(状态: Dictionary) -> void:
	for 子 in _遗忘词行.get_children():
		_遗忘词行.remove_child(子)
		子.queue_free()
	var 牌: Array = 状态["手牌"]
	_遗忘框.visible = not 牌.is_empty()
	for 条 in 牌:
		_造词块(条, true, _遗忘词行)


## 造一个词块并塞进容器。
## ⚠️ 必须先 add_child 再设内容 —— 词块的 _字/_样式 是 _ready() 里建的，
##    没入树就设内容会静默失败（拿到一堆 Nil）。
func _造词块(条: Dictionary, 来自手牌: bool, 父: Node) -> 词块:
	var 块: 词块 = 词块脚本.new()
	父.add_child(块)
	var 词: String = str(条["词"])
	if 来自手牌:
		块.设为手牌词(词, int(条["证人数"]), bool(条["选中"]), 条["色"], 局.词说明(词))
	else:
		块.设为口径词(
			词, float(条["清晰"]), int(条["档"]), int(条["证人数"]),
			bool(条["背书"]), bool(条["选中"]), 条["色"],
			int(条["句号"]), int(条["槽号"]), 局.词说明(词)
		)
	块.被点.connect(_点词)
	return 块


func _刷按钮(状态: Dictionary) -> void:
	var 可: Dictionary = 状态["可以"]
	_说出口按钮.disabled = not bool(可["说出口"])
	_换掉按钮.disabled = not bool(可["换词"])
	_换掉按钮.text = "换掉…" if not 局.换词模式 else "换掉谁？"
	_撤销按钮.disabled = not bool(可["撤销"])
	_下一幕按钮.text = "下一幕 →（草稿生效）" if 局.动作已做 else "下一幕 →"


# ============================================================ 输入 → 语义动作
## ★ 注意这里有多干净：界面只管把"玩家碰了什么"翻译成 局 的动作。
##   想做拖拽 / 手势 / 语音，改的就是这几个函数。
func _点讲者(id: String) -> void:
	局.选讲者(id)


func _点词(词: String, 句号: int, 槽号: int) -> void:
	var 来自手牌: bool = 句号 < 0

	# 换词模式：点故事里的词 = 拿它开刀
	if 局.换词模式 and not 来自手牌:
		局.换词(词, 局.选中词)
		return
	if 局.换词模式 and 来自手牌:
		_提示行.text = "得点上面故事里的一个词 —— 你要换掉的是哪个？"
		return

	局.选词(词, 来自手牌)
	if 局.选中词 == "":
		_提示行.text = "取消选择。"
	else:
		_重建()
		if 来自手牌:
			_提示行.text = "拿着「%s」。说出口，或者点「换掉…」再点故事里的一个词。" % 词
		else:
			_提示行.text = "选中「%s」。可以把它说出口。" % 词
		return
	_重建()


# ============================================================ 笔记（新手引导）
func _搭笔记按钮() -> void:
	var 顶栏: Node = _幕次行.get_parent()
	_笔记按钮 = Button.new()
	_笔记按钮.text = "笔记"
	_笔记按钮.focus_mode = Control.FOCUS_NONE
	_笔记按钮.pressed.connect(_开笔记)
	顶栏.add_child(_笔记按钮)
	局.笔记解锁.connect(func(_id): _刷笔记按钮())


func _刷笔记按钮() -> void:
	if _笔记按钮 == null:
		return
	if 局.笔记.size() > 0:
		_笔记按钮.text = "笔记 ●"
		_笔记按钮.add_theme_color_override("font_color", Color("#a06f1e"))
	else:
		_笔记按钮.text = "笔记"
		_笔记按钮.remove_theme_color_override("font_color")


func _开笔记() -> void:
	if _笔记层 != null and is_instance_valid(_笔记层):
		_笔记层.queue_free()
		_笔记层 = null
		_刷笔记按钮()
		return

	_笔记按钮.text = "收起笔记"
	_笔记层 = PanelContainer.new()
	_笔记层.name = "笔记层"
	_笔记层.set_anchors_preset(Control.PRESET_FULL_RECT)
	_笔记层.mouse_filter = Control.MOUSE_FILTER_STOP
	var 皮 := StyleBoxFlat.new()
	皮.bg_color = Color(0.827, 0.780, 0.675, 0.985)
	皮.content_margin_left = 70.0
	皮.content_margin_right = 70.0
	皮.content_margin_top = 44.0
	皮.content_margin_bottom = 36.0
	_笔记层.add_theme_stylebox_override("panel", 皮)
	add_child(_笔记层)

	var 滚动 := ScrollContainer.new()
	滚动.set_anchors_preset(Control.PRESET_FULL_RECT)
	滚动.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_笔记层.add_child(滚动)

	var 列 := VBoxContainer.new()
	列.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	列.add_theme_constant_override("separation", 18)
	滚动.add_child(列)

	var 头 := Label.new()
	头.text = "我 记 的 笔 记"
	头.add_theme_font_size_override("font_size", 15)
	头.add_theme_color_override("font_color", Color("#6b6152"))
	列.add_child(头)

	var 已解锁: int = 0
	for 条 in 口径词表.笔记:
		if not 局.笔记.has(str(条["id"])):
			continue
		已解锁 += 1
		var 块 := VBoxContainer.new()
		块.add_theme_constant_override("separation", 4)
		var 题 := Label.new()
		题.text = "· " + str(条["标题"])
		题.add_theme_font_size_override("font_size", 17)
		题.add_theme_color_override("font_color", Color("#211c16"))
		块.add_child(题)
		var 文 := Label.new()
		文.text = str(条["文"])
		文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		文.add_theme_font_size_override("font_size", 15)
		文.add_theme_color_override("font_color", Color("#3d3529"))
		块.add_child(文)
		列.add_child(块)

	if 已解锁 == 0:
		var 空 := Label.new()
		空.text = "还没有。你撞上什么事，这里才会多一条。"
		空.add_theme_font_size_override("font_size", 15)
		空.add_theme_color_override("font_color", Color("#6b6152"))
		列.add_child(空)

	var 尾 := Label.new()
	尾.text = "\n（再点一次右上角的按钮收起来。游戏不会停下来等你。）"
	尾.add_theme_font_size_override("font_size", 14)
	尾.add_theme_color_override("font_color", Color("#8a7f6c"))
	列.add_child(尾)


# ============================================================ 结算
## ⚠️ 结算（念故事的那套演出）现在是**界面层**的东西 —— 什么时候念、念多慢，
##    归你管。规则和文案从 局.取结算() 拿。
func _放结算() -> void:
	var 我代: int = _代
	var 结: Dictionary = 局.取结算()

	_下一幕按钮.visible = false
	_说出口按钮.visible = false
	_换掉按钮.visible = false
	_撤销按钮.visible = false
	_嘴区.visible = false
	_遗忘框.visible = false

	_结算层 = PanelContainer.new()
	_结算层.name = "结算层"
	_结算层.set_anchors_preset(Control.PRESET_FULL_RECT)
	_结算层.mouse_filter = Control.MOUSE_FILTER_STOP
	var 皮 := StyleBoxFlat.new()
	皮.bg_color = Color(0.827, 0.780, 0.675, 0.99)
	皮.content_margin_left = 60.0
	皮.content_margin_right = 60.0
	皮.content_margin_top = 40.0
	皮.content_margin_bottom = 32.0
	_结算层.add_theme_stylebox_override("panel", 皮)
	add_child(_结算层)

	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 14)
	_结算层.add_child(列)

	var 滚动 := ScrollContainer.new()
	滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	列.add_child(滚动)

	var 盒 := VBoxContainer.new()
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	盒.add_theme_constant_override("separation", 16)
	滚动.add_child(盒)

	var 头 := Label.new()
	头.text = "回 访 记 录"
	头.add_theme_font_size_override("font_size", 15)
	头.add_theme_color_override("font_color", Color("#6b6152"))
	盒.add_child(头)

	var 文 := RichTextLabel.new()
	文.bbcode_enabled = true
	文.fit_content = true
	文.scroll_active = false
	文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	文.add_theme_font_size_override("normal_font_size", 21)
	文.add_theme_constant_override("line_separation", 12)
	盒.add_child(文)

	var 拼: String = ""
	for 行 in 结["行"]:
		拼 += _上色(str(行))
		文.text = 拼
		if not await _等(0.62, 我代):
			return
	if not await _等(0.5, 我代):
		return

	var 矛: Array = 结["矛盾"]
	if not 矛.is_empty():
		拼 += "\n\n"
		文.text = 拼
		var 条: Array = []
		for 对 in 矛:
			条.append("「%s」和「%s」" % [str(对[0]), str(对[1])])
		var 矛标 := Label.new()
		矛标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		矛标.add_theme_font_size_override("font_size", 16)
		矛标.add_theme_color_override("font_color", Color("#a06f1e"))
		矛标.text = "念到这儿，我听下来对不上：\n" + "、".join(条) + "\n这两句摆在一起，不像同一件事。"
		盒.add_child(矛标)
		if not await _等(0.7, 我代):
			return

	var 手记: Array = 结["手记"]
	if not 手记.is_empty():
		var 行2: Array = []
		for 记 in 手记:
			if str(记["动作"]) == "换词":
				行2.append("第%d幕　把「%s」换成了「%s」（%d 处）" % [
					int(记["幕"]), str(记["旧"]), str(记["新"]), int(记["处"])
				])
			else:
				行2.append("第%d幕　把「%s」说出口" % [int(记["幕"]), str(记["词"])])
		var 手 := Label.new()
		手.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		手.add_theme_font_size_override("font_size", 15)
		手.add_theme_color_override("font_color", Color("#6b6152"))
		手.text = "你动过的手：\n" + "\n".join(行2)
		盒.add_child(手)
		if not await _等(0.6, 我代):
			return

	var 意 := Label.new()
	意.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	意.add_theme_font_size_override("font_size", 16)
	意.add_theme_color_override("font_color", Color("#564b3b"))
	意.text = str(结["校准"])
	盒.add_child(意)
	if not await _等(0.9, 我代):
		return

	var 尾文: Dictionary = 结["结尾"]
	var 尾 := RichTextLabel.new()
	尾.bbcode_enabled = true
	尾.fit_content = true
	尾.scroll_active = false
	尾.add_theme_font_size_override("normal_font_size", 30)
	var 引子: String = "[color=#6b6472][font_size=16]%s\n\n[/font_size][/color]" % str(尾文["提示"])
	if bool(尾文["划掉"]):
		尾.text = 引子 + "[color=#9c3a2a][s]%s[/s][/color]" % str(尾文["句"])
	elif bool(尾文["淡"]):
		尾.text = 引子 + "[color=#a99d86]%s[/color]" % str(尾文["句"])
	else:
		尾.text = 引子 + "[color=#211c16]%s[/color]" % str(尾文["句"])
	盒.add_child(尾)

	列.add_child(_弹簧())
	var 底 := HBoxContainer.new()
	底.add_theme_constant_override("separation", 14)
	列.add_child(底)
	底.add_child(_弹簧())
	var 再 := Button.new()
	再.text = "再来一次"
	再.pressed.connect(重来)
	底.add_child(再)


func _弹簧() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, 4)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 等一会儿。返回 false = 这一局的结算已经被重来踢掉，别再往下画了。
func _等(秒: float, 我代: int) -> bool:
	await get_tree().create_timer(秒).timeout
	if 我代 != _代:
		return false
	if not is_instance_valid(self):
		return false
	return true


## 把引擎给的文本（哑的用〖〗、传闻用「」）翻译成 bbcode
func _上色(行: String) -> String:
	var 出: String = ""
	var i: int = 0
	while i < 行.length():
		var c: String = 行[i]
		if c == "〖":
			var 止: int = 行.find("〗", i)
			if 止 < 0:
				止 = 行.length()
			出 += "[color=#9c3a2a][s]%s[/s][/color]" % 行.substr(i + 1, 止 - i - 1)
			i = 止 + 1
			continue
		if c == "「":
			var 止2: int = 行.find("」", i)
			if 止2 < 0:
				止2 = 行.length()
			出 += "[color=#8a7d67]「%s」[/color]" % 行.substr(i + 1, 止2 - i - 1)
			i = 止2 + 1
			continue
		出 += c
		i += 1
	return 出 + "\n"
