## 调试 —— F1 叠层。
##
## ============================================================
## 为什么要有这个：
##   这是一个"改写 → 下一幕才见效"的游戏，效果延迟一幕。
##   没有这个东西，你永远不知道自己刚才那一改到底算不算数。
##
## 开法：
##   · 游戏里按 F1（键位在 project.godot 的 InputMap 里叫「调试开关」，也能在 主题.调试键 改）
##   · 启动参数：`游戏.exe -- --调试` 一进来就开着
##   · headless 跑自检时，调 `打印()` 会把整份状态打到控制台
##
## ★ 纪律：这个叠层**只读状态**（走 对局.取状态() 和 引擎 的公开查询），
##   改状态一律走 对局 的语义动作。所以它不会把游戏跑歪。
## ============================================================
class_name 调试
extends Control

var 局: 对局 = null
var 界面节点: Control = null

var _开了: bool = false
var _板: PanelContainer = null
var _文: RichTextLabel = null
var _跳幕框: SpinBox = null


func 接上(局_: 对局, 界面_: Control) -> void:
	局 = 局_
	界面节点 = 界面_
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_搭()

	局.换幕.connect(func(_a, _b, _c): if _开了: 刷新())
	局.你换了.connect(func(_a, _b, _c): if _开了: 刷新())
	局.你撤了.connect(func(): if _开了: 刷新())
	局.任务进度变了.connect(func(_a): if _开了: 刷新())

	if OS.get_cmdline_user_args().has(主题.启动即调试):
		切换(true)


func _unhandled_input(事件: InputEvent) -> void:
	if 事件 is InputEventKey:
		var 键 := 事件 as InputEventKey
		if 键.pressed and not 键.echo and 键.keycode == 主题.调试键:
			切换(not _开了)
			get_viewport().set_input_as_handled()


func 切换(开: bool) -> void:
	_开了 = 开
	visible = 开
	if 开:
		刷新()


func 开着() -> bool:
	return _开了


# ============================================================ 搭
func _搭() -> void:
	_板 = PanelContainer.new()
	_板.name = "调试板"
	_板.set_anchors_preset(Control.PRESET_FULL_RECT)
	_板.mouse_filter = Control.MOUSE_FILTER_STOP
	var 皮 := StyleBoxFlat.new()
	皮.bg_color = Color(0.06, 0.06, 0.08, 0.93)
	皮.content_margin_left = 24.0
	皮.content_margin_right = 24.0
	皮.content_margin_top = 18.0
	皮.content_margin_bottom = 18.0
	_板.add_theme_stylebox_override("panel", 皮)
	add_child(_板)

	var 列 := VBoxContainer.new()
	列.add_theme_constant_override("separation", 10)
	_板.add_child(列)

	var 顶 := HBoxContainer.new()
	顶.add_theme_constant_override("separation", 10)
	列.add_child(顶)
	顶.add_child(_标("调 试　（F1 关掉）", 18, Color(0.9, 0.85, 0.7)))
	顶.add_child(_弹())

	跳幕按钮(顶, "◀ 跳这一幕", func(): _跳(局.幕 - 1))
	_跳幕框 = SpinBox.new()
	_跳幕框.min_value = 1
	_跳幕框.max_value = maxi(1, 局.总幕数())
	_跳幕框.value = 1
	_跳幕框.custom_minimum_size = Vector2(80, 0)
	顶.add_child(_跳幕框)
	跳幕按钮(顶, "跳到 ▶", func(): _跳(int(_跳幕框.value)))
	跳幕按钮(顶, "下一幕", func(): 局.下一幕(); 刷新())
	跳幕按钮(顶, "强制达成", func(): 局.强制达成(not 局.引擎.强制达成); 刷新())
	跳幕按钮(顶, "重放并断言", _重放断言)
	跳幕按钮(顶, "重来", func(): 局.重来(); 刷新())
	跳幕按钮(顶, "打印", 打印)

	var 滚 := ScrollContainer.new()
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	列.add_child(滚)

	_文 = RichTextLabel.new()
	_文.bbcode_enabled = true
	_文.fit_content = true
	_文.scroll_active = false
	_文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_文.add_theme_font_size_override("normal_font_size", 15)
	_文.add_theme_constant_override("line_separation", 6)
	滚.add_child(_文)


func 跳幕按钮(父: Node, 文: String, 做: Callable) -> void:
	var b := Button.new()
	b.text = 文
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(做)
	父.add_child(b)


func _跳(目标: int) -> void:
	局.跳幕(目标)
	刷新()


# ============================================================ 刷新
func 刷新() -> void:
	if _文 == null or 局 == null:
		return
	_文.text = 取文本()


func 取文本() -> String:
	var 状态: Dictionary = 局.取状态()
	var 进: Dictionary = 状态["任务"]
	var 行: Array = []

	行.append("[b][color=#d8c48a]第 %d/%d 幕 · %s[/color][/b]　完了=%s　草稿=%s（本幕改了 %d 次）" % [
		int(状态["幕"]), int(状态["总幕数"]), str(状态["幕名"]),
		str(状态["完了"]), str(状态["草稿"]["有"]), int(状态["草稿"]["次数"]),
	])
	行.append("选中底本=%s　选中词=%s" % [str(状态["选中底本"]), str(状态["选中词"])])

	行.append("\n[b]任务[/b]　%s" % str(进["说明"]))
	行.append("　%s" % ("✔ 已达成" if bool(进["达成"]) else "○ 差 %d 条：%s" % [
		int(进["总"]) - int(进["已满足"]), "；".join(进["差什么"] as Array)]))
	for 一 in 进["条目"]:
		var 项: Dictionary = 一
		行.append("　%s %s" % ["[color=#7fbf8a]✔[/color]" if bool(项["满足"]) else "[color=#c07a5a]✘[/color]",
			str(项["条件"])])

	行.append("\n[b]本幕变体命中[/b]　%s" % _命中文本(状态))
	行.append("[b]场景[/b]　%s" % JSON.stringify(状态["场景"]))
	行.append("[b]事实[/b]　%s" % str(状态["事实"]))

	行.append("\n[b]故事[/b]（%d 句）" % (状态["故事"] as Array).size())
	for 句 in 状态["故事"]:
		var 条: Dictionary = 句
		var 拼: String = ""
		for 词条 in (条["词"] as Array):
			var 人: Dictionary = 词条
			var 色: String = 主题.换过.to_html(false) if bool(人["换过"]) else 主题.取类色(str(人["类"])).to_html(false)
			拼 += "[color=#%s]%s[/color]" % [色, str(人["词"])]
		行.append("　第%d幕·%s　%s" % [int(条["幕"]), str(条["讲者名"]), 拼])

	行.append("\n[b]替换记录[/b]（%d 条）" % (状态["替换记录"] as Array).size())
	for 一 in 状态["替换记录"]:
		var 条2: Dictionary = 一
		行.append("　第%d幕　「%s」→「%s」　类=%s　处=%d" % [
			int(条2["幕"]), str(条2["旧"]), str(条2["新"]), str(条2["类"]), int(条2["处"])])

	行.append("\n[b]因果链[/b]（%d 条）" % (状态["因果链"] as Array).size())
	for 一 in 状态["因果链"]:
		var 条3: Dictionary = 一
		行.append("　第%d幕　因为 %s → %s" % [
			int(条3["幕"]), "，".join(条3["因为"] as Array), str(条3["所以"])])

	var 矛: Array = 状态["矛盾"]
	行.append("\n[b]矛盾[/b]　%s" % ("无" if 矛.is_empty() else JSON.stringify(矛)))

	行.append("\n[b]候选词[/b]（%d 个）" % (状态["候选"] as Array).size())
	var 拼2: Array = []
	for 一 in 状态["候选"]:
		var 条4: Dictionary = 一
		拼2.append("%s%s(%s)%s" % [
			"" if bool(条4["能换"]) else "✘",
			str(条4["词"]), str(条4["类"]),
			"" if bool(条4["能换"]) else "←" + str(条4["理由"]),
		])
	行.append("　" + "　".join(拼2))

	行.append("\n[b]重放记录[/b]　%s" % JSON.stringify(局.取重放()))
	return "\n".join(行)


func _命中文本(状态: Dictionary) -> String:
	var 命: Dictionary = 状态["本幕命中"]
	if 命.is_empty() or int(命.get("索引", -1)) < 0:
		return "（无）"
	return "第 %d 条变体　因为 %s%s" % [
		int(命["索引"]),
		"，".join(命.get("因为", []) as Array),
		"" if str(命.get("所以", "")) == "" else " → " + str(命["所以"]),
	]


# ============================================================ 重放断言（M4 可复现性）
## 一键验证"同一份记录跑两遍，结果逐字相同"。
func _重放断言() -> void:
	var 记录: Dictionary = 局.取重放()
	var 第一: String = _指纹(局.取结算())
	局.从重放(记录)
	var 第二: String = _指纹(局.取结算())
	if 第一 == 第二:
		print("[调试] 重放断言：✔ 两次逐字相同")
	else:
		print("[调试] 重放断言：✘ 不一致\n  第一次：", 第一, "\n  第二次：", 第二)
	刷新()


func _指纹(结: Dictionary) -> String:
	return JSON.stringify({
		"行": 结["行"],
		"因果链": 结["因果链"],
		"词改变": 结["词改变"],
		"达成": 结["达成"],
	})


func 打印() -> void:
	print("──────── 调试 · 状态 ────────")
	print(取文本().replace("[b]", "").replace("[/b]", "").replace("[color=#", "‹").replace("[/color]", "›"))
	print("────────────────────────────")


# ============================================================ 小工具
func _标(文: String, 号: int, 色: Color) -> Label:
	var l := Label.new()
	l.text = 文
	l.add_theme_font_size_override("font_size", 号)
	l.add_theme_color_override("font_color", 色)
	return l


func _弹() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
