## 界面 —— **默认界面**。
##
## ============================================================
## ★★ 这一层是给你推翻的。
##
##   它只干两件事：
##     ① 订阅 对局 的信号，把 取状态() 画出来
##     ② 报出"玩家碰了什么"（只 emit 信号，不判断那意味着什么）
##
##   **它一行规则都没有。** 不判断同类、不判断任务达成、不记状态。
##
## ------------------------------------------------------------
## 三条接手法，从轻到重：
##
##   【轻】把 inspector 里的 `搭界面` 取消勾选 —— 默认框按钮全不生成。
##         ★ 和旧版不一样：**对局照常跑、信号照发、调试照样能用**，
##           因为接线的责任不在这一层（在 主.gd）。
##
##   【中】留着这个脚本，改 `_搭()` 之后的东西。
##
##   【重】整个文件删掉，自己写一个：只要
##           · 提供 `接上(局)` 方法
##           · 提供 `刷新()` 方法
##           · emit 下面这六个信号
##         主.gd 就照样能把它接起来。交互层也不用改。
##
## ------------------------------------------------------------
## 界面报出去的六个信号（交互层照着翻译成玩家动作）：
##   点了讲者(id) / 点了故事词(词) / 点了候选(词) / 点了撤销() / 点了下一幕() / 点了重来()
## ============================================================
class_name 界面
extends Control

signal 点了讲者(id: String)
signal 点了故事词(词: String)
signal 点了候选(词: String)
signal 点了撤销()
signal 点了下一幕()
signal 点了重来()

## ★ 关掉它 = 你接管界面。逻辑照跑，信号照发。
@export var 搭界面: bool = true

var 局: 对局 = null

var _搭好了: bool = false
var _代: int = 0

# ---- 控件引用 ----
var _幕次: Label = null
var _任务说明: Label = null
var _任务进度: Label = null
var _滚动: ScrollContainer = null
var _句子区: VBoxContainer = null
var _开场空: RichTextLabel = null
var _事实行: Label = null
var _嘴区: VBoxContainer = null
var _候选标题: Label = null
var _候选区: HBoxContainer = null
var _提示行: Label = null
var _撤回按钮: Button = null
var _下一幕按钮: Button = null
var _重来按钮: Button = null
var _开场层: Control = null
var _开场文: RichTextLabel = null
var _结算层: Control = null


# ============================================================ 接线
## 由 主.gd 调用。
func 接上(局_: 对局) -> void:
	局 = 局_
	局.换幕.connect(_当_换幕)
	局.你选了.connect(func(_id): 刷新())
	局.你选词.connect(func(_词): 刷新())
	局.你换了.connect(func(_旧, _新, _处): 刷新())
	局.你撤了.connect(func(): 刷新())
	局.任务进度变了.connect(func(_进): 刷新())
	# 收束：达成 → 锚定演出；没达成 → 校准演出。两块走同一个结算函数。
	局.锚定.connect(func(_结果): 放结算())
	局.未达成.connect(func(_结果): 放结算())
	if 搭界面:
		_搭()
		_搭好了 = true
	刷新()


func _当_换幕(_幕号: int, _总数: int, _名: String) -> void:
	刷新()
	_滚到底()


# ============================================================ 搭
func _搭() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var 皮 := Theme.new()
	var 字: FontFile = load(主题.字体路径) as FontFile
	if 字 != null:
		皮.default_font = 字
	theme = 皮

	var 根 := MarginContainer.new()
	根.set_anchors_preset(Control.PRESET_FULL_RECT)
	根.mouse_filter = Control.MOUSE_FILTER_IGNORE
	根.add_theme_constant_override("margin_left", 40)
	根.add_theme_constant_override("margin_right", 40)
	根.add_theme_constant_override("margin_top", 30)
	根.add_theme_constant_override("margin_bottom", 24)
	add_child(根)

	var 列 := VBoxContainer.new()
	列.mouse_filter = Control.MOUSE_FILTER_IGNORE
	列.add_theme_constant_override("separation", 10)
	根.add_child(列)

	# ---------------- 顶栏 ----------------
	var 顶 := HBoxContainer.new()
	顶.add_theme_constant_override("separation", 18)
	列.add_child(顶)

	_幕次 = _标签("第 1 幕", 主题.字号_幕, 主题.墨淡)
	顶.add_child(_幕次)
	顶.add_child(_弹簧())

	_任务说明 = _标签("", 主题.字号_幕, 主题.强调)
	_任务说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_任务说明.custom_minimum_size = Vector2(620, 0)
	_任务说明.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	顶.add_child(_任务说明)

	_任务进度 = _标签("", 主题.字号_提示, 主题.命中)
	_任务进度.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_任务进度.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	列.add_child(_任务进度)

	列.add_child(_横线())

	# ---------------- 中区 ----------------
	var 中 := HBoxContainer.new()
	中.size_flags_vertical = Control.SIZE_EXPAND_FILL
	中.add_theme_constant_override("separation", 16)
	列.add_child(中)

	# 左：故事
	var 左 := _纸块()
	左.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	中.add_child(左)
	var 左列 := VBoxContainer.new()
	左列.add_theme_constant_override("separation", 8)
	左.add_child(左列)
	左列.add_child(_标签("你拼出来的故事", 主题.字号_提示, 主题.墨更淡))

	_滚动 = ScrollContainer.new()
	_滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_滚动.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	左列.add_child(_滚动)

	_句子区 = VBoxContainer.new()
	_句子区.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_句子区.add_theme_constant_override("separation", 12)
	_滚动.add_child(_句子区)

	_开场空 = RichTextLabel.new()
	_开场空.bbcode_enabled = true
	_开场空.fit_content = true
	_开场空.scroll_active = false
	_开场空.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_开场空.add_theme_font_size_override("normal_font_size", 主题.字号_正文)
	_开场空.add_theme_constant_override("line_separation", 10)
	_句子区.add_child(_开场空)

	# 右：现场与四张嘴
	var 右 := _纸块()
	右.custom_minimum_size = Vector2(440, 0)
	中.add_child(右)
	var 右列 := VBoxContainer.new()
	右列.add_theme_constant_override("separation", 8)
	右.add_child(右列)

	_事实行 = _标签("", 主题.字号_说明, 主题.墨淡)
	_事实行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	右列.add_child(_事实行)
	右列.add_child(_横线())

	_嘴区 = VBoxContainer.new()
	_嘴区.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_嘴区.add_theme_constant_override("separation", 8)
	右列.add_child(_嘴区)

	# ---------------- 候选词 ----------------
	_候选标题 = _标签("", 主题.字号_提示, 主题.墨更淡)
	列.add_child(_候选标题)

	var 候选滚 := ScrollContainer.new()
	候选滚.custom_minimum_size = Vector2(0, 62)
	候选滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	候选滚.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	列.add_child(候选滚)

	_候选区 = HBoxContainer.new()
	_候选区.add_theme_constant_override("separation", 8)
	候选滚.add_child(_候选区)

	# ---------------- 底栏 ----------------
	_提示行 = _标签("", 主题.字号_提示, 主题.墨更淡)
	_提示行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	列.add_child(_提示行)

	var 底 := HBoxContainer.new()
	底.add_theme_constant_override("separation", 12)
	列.add_child(底)

	_撤回按钮 = _按钮("撤回改写", 主题.字号_说明)
	_撤回按钮.pressed.connect(func(): 点了撤销.emit())
	底.add_child(_撤回按钮)

	_下一幕按钮 = _按钮("下一幕 →", 主题.字号_正文)
	_下一幕按钮.pressed.connect(func(): 点了下一幕.emit())
	底.add_child(_下一幕按钮)

	_重来按钮 = _按钮("重来", 主题.字号_说明)
	_重来按钮.pressed.connect(func(): 点了重来.emit())
	底.add_child(_重来按钮)

	底.add_child(_弹簧())
	底.add_child(_标签("F1 调试", 主题.字号_提示, 主题.墨更淡))

	_搭开场层()


# ============================================================ 开场白（M2：我是谁、要干什么）
func _搭开场层() -> void:
	_开场层 = _纸层(0.99)
	add_child(_开场层)
	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 16)
	_开场层.add_child(列)

	var 顶 := _标签("欢 迎 回 来", 主题.字号_标题, 主题.墨更淡)
	列.add_child(顶)

	var 文 := RichTextLabel.new()
	文.bbcode_enabled = true
	文.fit_content = true
	文.scroll_active = false
	文.size_flags_vertical = Control.SIZE_EXPAND_FILL
	文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	文.add_theme_font_size_override("normal_font_size", 主题.字号_正文)
	文.add_theme_constant_override("line_separation", 12)
	列.add_child(文)

	var 底 := HBoxContainer.new()
	列.add_child(底)
	底.add_child(_弹簧())
	var 按钮 := _按钮("开始", 主题.字号_正文)
	按钮.pressed.connect(func(): _开场层.visible = false)
	底.add_child(按钮)

	_开场文 = 文


func _刷开场(状态: Dictionary) -> void:
	if _开场层 == null or _开场文 == null:
		return
	var 文: RichTextLabel = _开场文
	文.text = (
		"[color=#6b6152]%s[/color]\n\n"
		+ "[color=#211c16][font_size=24]%s[/font_size][/color]\n\n"
		+ "[color=#a06f1e]你的任务：%s[/color]"
	) % [str(状态["前提"]), str(状态["身份"]), str(状态["任务说明"])]


# ============================================================ 刷新
func 刷新() -> void:
	if not _搭好了 or 局 == null:
		return
	var 状态: Dictionary = 局.取状态()

	# 重来之后把上一局的结算层收掉（不然它会盖在新的一局上面）
	if _结算层 != null and is_instance_valid(_结算层) and not bool(状态["完了"]):
		_结算层.queue_free()
		_结算层 = null

	_刷开场(状态)

	_幕次.text = "第 %d 幕 / %d　·　%s" % [int(状态["幕"]), int(状态["总幕数"]), str(状态["幕名"])]
	_任务说明.text = "任务：" + str(状态["任务说明"])
	_刷任务(状态)

	_刷故事(状态)
	_刷嘴(状态)
	_刷候选(状态)
	_刷按钮(状态)

	_提示行.text = str(状态["提示"])
	var 矛: Array = 状态["矛盾"]
	if not 矛.is_empty():
		var 条: Array = []
		for 对 in 矛:
			条.append("「%s」和「%s」" % [str(对[0]), str(对[1])])
		_提示行.text += "\n★ 故事里打架了：" + "、".join(条)


func _刷任务(状态: Dictionary) -> void:
	var 进: Dictionary = 状态["任务"]
	if not 主题.显示任务进度:
		_任务进度.text = ""
		return
	var 条: Array = []
	for 一 in 进["条目"]:
		var 项: Dictionary = 一
		条.append(("✔ " if bool(项["满足"]) else "○ ") + str(项["条件"]))
	_任务进度.text = "　".join(条)
	_任务进度.add_theme_color_override(
		"font_color", 主题.命中 if bool(进["达成"]) else 主题.墨更淡
	)


func _刷故事(状态: Dictionary) -> void:
	for 子 in _句子区.get_children():
		if 子 == _开场空:
			continue
		_句子区.remove_child(子)
		子.queue_free()

	var 故事: Array = 状态["故事"]
	_开场空.visible = 故事.is_empty()
	if 故事.is_empty():
		_开场空.text = "[color=#8a7f6c]（故事还没开始。右边点一个人，用他的说法开头。）[/color]"
		return

	var 选词: String = str(状态["选中词"])
	for 句 in 故事:
		var 条: Dictionary = 句
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 6)
		_句子区.add_child(行)

		var 前缀 := _标签("·", 主题.字号_说明, 主题.墨更淡)
		前缀.custom_minimum_size = Vector2(34, 0)
		前缀.tooltip_text = "第 %d 幕 · %s 的说法" % [int(条["幕"]), str(条["讲者名"])]
		行.add_child(前缀)

		for 词条 in (条["词"] as Array):
			var 人: Dictionary = 词条
			var 词: String = str(人["词"])
			var 类: String = str(人["类"])
			# 骨架词（不在词表里的词）：进故事、参与念故事，但**换不了** ——
			# 所以画成字，不画成按钮。玩家一眼就知道哪些能碰。
			if 类 == "":
				var 素 := _标签(词, 主题.字号_词, 主题.墨)
				素.tooltip_text = "「%s」是这句话的骨架，换不了。\n能换的只有五类词：角色／物品／地点／状态／事件。" % 词
				行.add_child(素)
				continue
			var 色: Color = 主题.换过 if bool(人["换过"]) else 主题.取类色(类)
			var 按 := _词按钮(词, 色, 词 == 选词)
			按.tooltip_text = "「%s」·%s\n点它 → 下面挑一个同类的词换掉它" % [词, 类]
			按.pressed.connect(func(): 点了故事词.emit(词))
			行.add_child(按)


func _刷嘴(状态: Dictionary) -> void:
	for 子 in _嘴区.get_children():
		_嘴区.remove_child(子)
		子.queue_free()

	for 人 in 状态["讲者"]:
		var 条: Dictionary = 人
		var 框 := PanelContainer.new()
		var 皮 := StyleBoxFlat.new()
		皮.bg_color = Color(0, 0, 0, 0.035 if not bool(条["选中"]) else 0.085)
		皮.set_corner_radius_all(10)
		皮.content_margin_left = 12.0
		皮.content_margin_right = 12.0
		皮.content_margin_top = 8.0
		皮.content_margin_bottom = 8.0
		框.add_theme_stylebox_override("panel", 皮)
		if bool(条["选中"]):
			皮.border_width_left = 3
			皮.border_color = Color(str(条["色"]))
		_嘴区.add_child(框)

		var 列 := VBoxContainer.new()
		列.add_theme_constant_override("separation", 3)
		框.add_child(列)

		var 名 := _标签("%s · %s" % [str(条["名"]), str(条["短"])], 主题.字号_说明, Color(str(条["色"])))
		列.add_child(名)

		var 文 := _标签(str(条["文"]), 主题.字号_说明, 主题.墨)
		文.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		列.add_child(文)

		# 整块可点：采信他的说法
		var 按 := Button.new()
		按.flat = true
		按.text = ""
		按.focus_mode = Control.FOCUS_NONE
		按.set_anchors_preset(Control.PRESET_FULL_RECT)
		按.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var id: String = str(条["id"])
		按.pressed.connect(func(): 点了讲者.emit(id))
		框.add_child(按)


func _刷候选(状态: Dictionary) -> void:
	for 子 in _候选区.get_children():
		_候选区.remove_child(子)
		子.queue_free()

	var 候选: Array = 状态["候选"]
	var 选词: String = str(状态["选中词"])
	if 选词 == "":
		_候选标题.text = "你听过的词（先点故事里的一个词，再来这儿挑同类的换）"
	else:
		_候选标题.text = "可以拿来换掉「%s」的同类词" % 选词

	if 候选.is_empty():
		var 空 := _标签("（这一幕还没有可换的词。）", 主题.字号_提示, 主题.墨更淡)
		_候选区.add_child(空)
		return

	for 条 in 候选:
		var 人: Dictionary = 条
		var 词: String = str(人["词"])
		var 类: String = str(人["类"])
		var 文: String = 词 + ("　·%s" % 类 if 主题.显示词类 else "")
		var 按 := _词按钮(文, 主题.取类色(类), false)
		按.disabled = not bool(人["能换"])
		按.tooltip_text = "「%s」·%s" % [词, 类]
		if not bool(人["能换"]) and str(人["理由"]) != "":
			按.tooltip_text += "\n" + str(人["理由"])
		按.pressed.connect(func(): 点了候选.emit(词))
		_候选区.add_child(按)


func _刷按钮(状态: Dictionary) -> void:
	var 可: Dictionary = 状态["可以"]
	_撤回按钮.disabled = not bool(可["撤销"])
	_下一幕按钮.disabled = not bool(可["下一幕"])
	_下一幕按钮.text = "下一幕 →" if int(状态["幕"]) < int(状态["总幕数"]) else "收束 →"
	if int(状态["幕"]) >= int(状态["总幕数"]):
		_下一幕按钮.text = "定下来 →"


# ============================================================ 结算（M5：因果链）
func 放结算() -> void:
	if not _搭好了 or 局 == null:
		return
	_代 += 1
	var 我代: int = _代
	var 结: Dictionary = 局.取结算()

	if _结算层 != null and is_instance_valid(_结算层):
		_结算层.queue_free()
	_结算层 = _纸层(0.995)
	add_child(_结算层)

	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 12)
	_结算层.add_child(列)

	var 滚动 := ScrollContainer.new()
	滚动.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚动.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	列.add_child(滚动)

	var 盒 := VBoxContainer.new()
	盒.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	盒.add_theme_constant_override("separation", 16)
	滚动.add_child(盒)

	盒.add_child(_标签(
		"锚 定 记 录" if bool(结["达成"]) else "校 准 记 录",
		主题.字号_提示, 主题.墨更淡))

	# ① 任务
	var 任务: Dictionary = 结["任务"]
	var 任务文 := "[color=#a06f1e]任务：%s[/color]\n" % str(任务["说明"])
	for 一 in 任务["条目"]:
		var 项: Dictionary = 一
		任务文 += "%s %s\n" % ["✔" if bool(项["满足"]) else "✘", str(项["条件"])]
	盒.add_child(_正文(任务文))
	if not await _等(0.45, 我代):
		return

	# ② 因果链
	var 链: Array = 结["因果链"]
	if not 链.is_empty():
		var 拼 := "[color=#3f5c43]这个故事是怎么被你的改写推着走的：[/color]\n"
		for 一 in 链:
			var 条: Dictionary = 一
			拼 += "\n[color=#6b6152]第 %d 幕[/color]　因为%s ——\n[color=#211c16]%s[/color]\n" % [
				int(条["幕"]), "，".join(条["因为"] as Array), str(条["所以"]),
			]
		盒.add_child(_正文(拼))
		if not await _等(0.5, 我代):
			return

	# ③ 你改过的词
	var 改: Array = 结["词改变"]
	if not 改.is_empty():
		var 拼2 := "[color=#8a5a2b]你动过的手：[/color]\n"
		for 一 in 改:
			var 条2: Dictionary = 一
			拼2 += "第 %d 幕　把「%s」换成「%s」（%s，故事里 %d 处一起变了）\n" % [
				int(条2["幕"]), str(条2["旧"]), str(条2["新"]),
				str(条2["类"]), int(条2["处"]),
			]
		盒.add_child(_正文(拼2))
	else:
		盒.add_child(_正文("[color=#6b6152]你一个字都没改 —— 这个故事是他们四个人的原样。[/color]"))
	if not await _等(0.45, 我代):
		return

	# ④ 念故事
	var 拼3 := "[color=#3f5c43]定下来的那个版本：[/color]\n"
	for 行 in 结["行"]:
		拼3 += str(行) + "\n"
	盒.add_child(_正文(拼3))

	var 矛: Array = 结["矛盾"]
	if not 矛.is_empty():
		var 条3: Array = []
		for 对 in 矛:
			条3.append("「%s」和「%s」" % [str(对[0]), str(对[1])])
		盒.add_child(_正文("[color=#9c3a2a]念到这儿对不上：%s。这两句摆在一起，不像同一件事。[/color]"
			% "、".join(条3)))
	if not await _等(0.55, 我代):
		return

	# ⑤ 其他合理达成方式（优先加强 4）
	var 别: Array = 结["其他版本"]
	if not 别.is_empty():
		var 拼4 := "[color=#6b6152]同一件事，还有别的走法：[/color]\n"
		var 有成立的 := false
		for 一 in 别:
			var 条4: Dictionary = 一
			if bool(条4["成立"]):
				有成立的 = true
				拼4 += "\n[color=#211c16]%s[/color]\n" % str(条4["说明"])
				for 行2 in (条4["行"] as Array):
					拼4 += "　" + str(行2) + "\n"
			else:
				拼4 += "\n[color=#8a7f6c]（有一条路没走通：%s）[/color]\n" % str(条4["理由"])
		if 有成立的:
			盒.add_child(_正文(拼4))
		if not await _等(0.5, 我代):
			return

	# ⑥ 结局台词
	var 尾 := RichTextLabel.new()
	尾.bbcode_enabled = true
	尾.fit_content = true
	尾.scroll_active = false
	尾.add_theme_font_size_override("normal_font_size", 主题.字号_结局)
	var 色: String = "#211c16" if bool(结["达成"]) else "#8a7f6c"
	尾.text = "[color=%s]「%s」[/color]" % [色, str(结["台词"])]
	盒.add_child(尾)

	# ⑦ 重放记录（可复现性，给你调试用）
	盒.add_child(_正文("[color=#8a7f6c][font_size=13]重放记录：%s[/font_size][/color]"
		% JSON.stringify(结["重放"])))

	var 底 := HBoxContainer.new()
	底.add_theme_constant_override("separation", 12)
	列.add_child(底)
	底.add_child(_弹簧())
	var 再 := _按钮("再来一次", 主题.字号_正文)
	再.pressed.connect(func(): 点了重来.emit())
	底.add_child(再)


func _滚到底() -> void:
	if _滚动 == null:
		return
	await get_tree().process_frame
	if is_instance_valid(_滚动):
		_滚动.scroll_vertical = int(_滚动.get_v_scroll_bar().max_value)


## 等一会儿。返回 false = 这一局的结算已经被重来踢掉，别再往下画了。
func _等(秒: float, 我代: int) -> bool:
	await get_tree().create_timer(秒).timeout
	if 我代 != _代 or not is_instance_valid(self):
		return false
	return true


# ============================================================ 造控件的小工具
func _弹簧() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _横线() -> Control:
	var c := ColorRect.new()
	c.color = 主题.线
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _标签(文: String, 号: int, 色: Color) -> Label:
	var l := Label.new()
	l.text = 文
	l.add_theme_font_size_override("font_size", 号)
	l.add_theme_color_override("font_color", 色)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _正文(bb: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_font_size_override("normal_font_size", 主题.字号_说明)
	r.add_theme_constant_override("line_separation", 8)
	r.text = bb
	return r


func _按钮(文: String, 号: int) -> Button:
	var b := Button.new()
	b.text = 文
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 号)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _词按钮(文: String, 色: Color, 选中: bool) -> Button:
	var b := Button.new()
	b.text = 文
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 主题.字号_词)
	b.add_theme_color_override("font_color", 色)
	b.add_theme_color_override("font_hover_color", 主题.强调)
	b.add_theme_color_override("font_disabled_color", 主题.墨更淡)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if 选中:
		var 皮 := StyleBoxFlat.new()
		皮.bg_color = Color(0.627, 0.435, 0.118, 0.18)
		皮.set_corner_radius_all(6)
		皮.content_margin_left = 6.0
		皮.content_margin_right = 6.0
		b.add_theme_stylebox_override("normal", 皮)
		b.add_theme_stylebox_override("hover", 皮)
	return b


func _纸块() -> PanelContainer:
	var p := PanelContainer.new()
	var 皮 := StyleBoxFlat.new()
	皮.bg_color = Color(0.129, 0.110, 0.086, 0.045)
	皮.set_corner_radius_all(12)
	皮.content_margin_left = 18.0
	皮.content_margin_right = 18.0
	皮.content_margin_top = 14.0
	皮.content_margin_bottom = 14.0
	p.add_theme_stylebox_override("panel", 皮)
	return p


func _纸层(不透明: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var 皮 := StyleBoxFlat.new()
	皮.bg_color = Color(主题.纸.r, 主题.纸.g, 主题.纸.b, 不透明)
	皮.content_margin_left = 64.0
	皮.content_margin_right = 64.0
	皮.content_margin_top = 44.0
	皮.content_margin_bottom = 36.0
	p.add_theme_stylebox_override("panel", 皮)
	return p
