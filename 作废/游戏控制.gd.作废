## 主控 —— 地图版。
##
## 每一幕是一片地。三个讲述者站在地里，一开始都是暗的、沉默的。
## **你走过去，他才亮起来、才开口。**
##
## 注视在这里是字面意思：你的位置只有一个，你不可能同时站在两个人面前。
##
## 必须走过去才算"读过"；读过的讲述者，之后可以点他直接采纳。
## （走过去是为了建立注视的成本，走回去只是重复劳动。）
##
## 界面结构在 场景/Main.tscn，讲述者在 场景/讲述者.tscn，这个脚本只管流程。
extends Control

const 讲者场景: PackedScene = preload("res://场景/讲述者.tscn")

# ============================================================ 界面引用
@onready var _底色: ColorRect = %底色
@onready var _装饰层: Control = %装饰层
@onready var _讲者层: Control = %讲者层
@onready var _玩家: 玩家 = %玩家
@onready var _幕标题: Label = %幕标题
@onready var _结局行: Label = %结局行
@onready var _条件行: Label = %条件行
@onready var _事实行: Label = %事实行
@onready var _对话框: PanelContainer = %对话框
@onready var _说者: Label = %说者
@onready var _台词: Label = %台词
@onready var _提示行: Label = %提示行
@onready var _下一幕按钮: Button = %下一幕按钮
@onready var _重来按钮: Button = %重来按钮

# ============================================================ 状态
const 总幕数: int = 7

var 当前幕: int = 1
var 上一幕采纳: String = ""
var 本幕已选: String = ""
var 本幕草稿: Dictionary = {}
var 正史: Array = []
var 讲者表: Dictionary = {}
var 采纳次数: Dictionary = {}

## 此刻站在谁面前（"" = 谁也不在面前）。
var _近者: String = ""
var _已结算: bool = false

## 本幕三个人各自会说的完整内容（正文 + 回响）。换幕时算一次，整幕不变。
var _本幕文本: Dictionary = {}
var _本幕回响: Dictionary = {}

## 喂养引擎 —— 涌现从这儿长出来。
var _喂养: 喂养 = 喂养.new()

## 每个人上一幕说过的那句回响。同一句不重复说。
var _上次回响: Dictionary = {}

# 能走的地方。别让玩家走进顶部和底部的 UI 里。
var _活动区: Rect2 = Rect2(40, 96, 1200, 456)


func _ready() -> void:
	_下一幕按钮.pressed.connect(_下一幕)
	_重来按钮.pressed.connect(_重来)
	_玩家.活动区 = _活动区
	_重置计数()
	_进入幕(1)
	_显示前提()


## 开局把设定白给。**玩家看不懂故事，一切免谈。**
func _显示前提() -> void:
	_对话框.visible = true
	_说者.text = "这件事是这样的"
	_说者.add_theme_color_override("font_color", Color("#d4a15a"))
	_台词.text = 剧本数据.前提


func _重置计数() -> void:
	采纳次数.clear()
	for 观众 in 剧本数据.观众列表:
		采纳次数[str(观众["id"])] = 0
	_喂养.重置()
	_上次回响.clear()


# ============================================================ 每帧：谁在我面前
func _process(_delta: float) -> void:
	if _已结算 or 讲者表.is_empty():
		return

	# 找最近的那个
	var 玩家心: Vector2 = _玩家.圆心()
	var 最近: String = ""
	var 最近距: float = 1.0e9
	for id in 讲者表:
		var 讲: 讲述者 = 讲者表[id]
		var d: float = 讲.距离到(玩家心)
		if d < 最近距:
			最近距 = d
			最近 = str(id)

	# 只有最近、且在感应距离内，才算"面对面"
	var 新的近者: String = ""
	if 最近 != "" and 最近距 <= 讲述者.感应距离:
		新的近者 = 最近

	for id in 讲者表:
		讲者表[id].设为面对面(str(id) == 新的近者)

	if 新的近者 != _近者:
		_近者 = 新的近者
		if _近者 != "":
			讲者表[_近者].标记已读()

	_刷新对话()


func _unhandled_input(event: InputEvent) -> void:
	if _已结算:
		return
	if event is InputEventKey:
		var 键 := event as InputEventKey
		if 键.pressed and not 键.echo and 键.keycode == KEY_E and _近者 != "":
			_采纳(_近者)
			get_viewport().set_input_as_handled()


## 念白面板：优先显示面前这个；否则显示本幕已采纳的那个。
func _刷新对话() -> void:
	var 显示谁: String = _近者
	if 显示谁 == "":
		显示谁 = 本幕已选

	if 显示谁 == "":
		_对话框.visible = false
		return

	_对话框.visible = true
	_说者.text = "%s 说：" % 剧本数据.取观众名(显示谁)
	_说者.add_theme_color_override("font_color", Color(str(剧本数据.取观众(显示谁).get("色", "#ffffff"))))
	_台词.text = str(_本幕文本.get(显示谁, ""))


# ============================================================ 流程
func _进入幕(幕号: int) -> void:
	当前幕 = 幕号
	本幕已选 = ""
	本幕草稿 = {}
	_近者 = ""
	_已结算 = false

	_幕标题.text = "第 %d 幕 · %s" % [幕号, 剧本数据.幕名[幕号 - 1]]
	# 这一幕发生了什么 —— 中立陈述，白给。三个人讲的是同一件事的三种讲法。
	_事实行.text = 剧本数据.取事实(幕号)
	# 过程中不点破终点 —— 只给个方向
	_结局行.text = "终点 · 一个他没去过的地方"
	_条件行.text = _条件说明()
	_提示行.text = "WASD / 方向键 走路 · 走近谁，谁才开口"
	_下一幕按钮.text = "下一幕 →" if 幕号 < 总幕数 else "收束 →"
	_下一幕按钮.visible = false
	_重来按钮.visible = false

	_布置场景(幕号)


## 开头那句"要凑齐哪三样"。写成意思，不写成词——这样才没法扫。
func _条件说明() -> String:
	var 片段: Array = []
	for i in 剧本数据.终点说明.size():
		片段.append("%d. %s" % [i + 1, str(剧本数据.终点说明[i])])
	return "要走到那里，故事得凑齐三样：    " + "     ".join(片段)


## 铺第 N 幕的地，并把三个人放上去。
func _布置场景(幕号: int) -> void:
	var 布局: Dictionary = 剧本数据.取布局(幕号)
	_底色.color = Color(str(布局.get("底色", "#0b0a10")))

	# 地形
	for 子 in _装饰层.get_children():
		_装饰层.remove_child(子)
		子.queue_free()
	for 项 in 布局.get("装饰", []):
		var 块 := ColorRect.new()
		块.position = Vector2(float(项[0]), float(项[1]))
		块.size = Vector2(float(项[2]), float(项[3]))
		块.color = Color(str(项[4]))
		块.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_装饰层.add_child(块)

	# 人
	for 子 in _讲者层.get_children():
		_讲者层.remove_child(子)
		子.queue_free()
	讲者表.clear()
	_本幕文本.clear()
	_本幕回响.clear()

	var 站位: Array = 布局.get("站位", [])
	for i in 剧本数据.观众列表.size():
		if i >= 站位.size():
			break
		var 观众: Dictionary = 剧本数据.观众列表[i]
		var id: String = str(观众["id"])
		var 处: Array = 站位[i]

		# 正文 + 他此刻的回响。回响是从喂养账本里长出来的，不是写死的。
		var 正文: String = 剧本数据.取文本(幕号, id)
		var 回响: Dictionary = _喂养.取回响(id)
		var 完整: String = 正文
		var 这句: String = str(回响.get("文本", ""))
		# 只在**变了**的时候开口。没听到新东西的人，不会把同一句再念一遍。
		if 这句 != "" and 这句 != str(_上次回响.get(id, "")):
			完整 = 正文 + "\n" + 这句
		if 这句 != "":
			_上次回响[id] = 这句
		_本幕文本[id] = 完整
		_本幕回响[id] = 回响

		var 讲: 讲述者 = 讲者场景.instantiate()
		_讲者层.add_child(讲)
		讲.position = Vector2(float(处[0]), float(处[1])) - Vector2(28, 28)
		讲.设置内容(观众, 完整)
		讲.被采纳.connect(_采纳)
		讲者表[id] = 讲

	# 玩家回到起点
	_玩家.移到(_找落脚点())
	_对话框.visible = false


## 挑一个离所有人都够远的落脚点。
## 不这么做的话，有些幕的站位正好压在默认起点上，一进场就白送一段台词。
func _找落脚点() -> Vector2:
	var 底: float = _活动区.end.y - 30.0
	var 安全距: float = 讲述者.感应距离 + 40.0
	for 候选x in [150.0, 640.0, 1130.0]:
		var 点: Vector2 = Vector2(float(候选x), 底)
		var 都够远: bool = true
		for id in 讲者表:
			if 讲者表[id].距离到(点) < 安全距:
				都够远 = false
				break
		if 都够远:
			return 点
	return Vector2(150.0, 底)


## 采纳。在按「下一幕」之前随时可以改主意。
func _采纳(id: String) -> void:
	本幕已选 = id
	# 存的是"组装后的那一段"（正文 + 他此刻的回响），不是原始台词
	var 段: Dictionary = 剧本数据.取段(当前幕, id).duplicate(true)
	段["文"] = str(_本幕文本.get(id, 段.get("文", "")))
	段["回响"] = _本幕回响.get(id, {})
	段["喂"] = 剧本数据.取喂物(当前幕, id)
	本幕草稿 = 段

	for 观众id in 讲者表:
		讲者表[观众id].设为已采纳(str(观众id) == id)

	_提示行.text = "已采纳「%s」。改主意就走去点别人 —— 按「%s」才算数。" % [
		剧本数据.取观众名(id), _下一幕按钮.text
	]
	_下一幕按钮.visible = true
	_刷新对话()


## 到这里才真正提交本幕的选择，另外两版永久作废。
func _下一幕() -> void:
	if 本幕已选 == "":
		return

	正史.append(本幕草稿)
	采纳次数[本幕已选] = int(采纳次数.get(本幕已选, 0)) + 1

	# ★ 涌现在这里发生：他讲的这段，喂给了另外两个人。
	#   没有人写他们下一幕会说什么——是听出来的。
	_喂养.喂(本幕已选, str(本幕草稿.get("喂", "")))

	上一幕采纳 = 本幕已选

	if 当前幕 >= 总幕数:
		_结算()
	else:
		_进入幕(当前幕 + 1)


func _重来() -> void:
	正史.clear()
	上一幕采纳 = ""
	_重置计数()
	_进入幕(1)
	_显示前提()


# ============================================================ 结算
func _结算() -> void:
	_已结算 = true
	_下一幕按钮.visible = false
	_重来按钮.visible = true
	_幕标题.text = "完"

	# 到这一步才揭晓：终点原文 + 你凑齐了哪几样
	var 各段关: Array = []
	for 段 in 正史:
		各段关.append((段 as Dictionary).get("关", []))
	var 立起: Array = 剧本数据.汇总终点(各段关)

	_结局行.text = "终点 · " + 剧本数据.结局正文
	_条件行.text = _终点清单(立起) + "        " + _条件说明()

	match 立起.size():
		3:
			_提示行.text = "三样都凑齐了。他走到了那里。"
		2:
			_提示行.text = "差一样。故事拐了个弯，停在了别处。"
		1:
			_提示行.text = "只凑齐一样。这个故事离那个终点还远。"
		_:
			_提示行.text = "一样也没凑齐。这个故事和那个终点，从头到尾无关。"

	# 结算时把整篇故事摊在对话板上，并在末尾附上"喂养账本"
	# —— 这是透镜：让人看见故事是怎么长出来的，而不是告诉他答案。
	_对话框.visible = true
	_说者.text = "你们讲出来的故事"
	_说者.add_theme_color_override("font_color", Color("#d4a15a"))

	var 段落: Array = []
	for 段 in 正史:
		段落.append(str((段 as Dictionary).get("文", "")))
	var 全文: String = "\n\n".join(段落)

	全文 += "\n\n──────────\n谁被喂了什么（这是故事自己长出来的那部分）\n"
	for 观众 in 剧本数据.观众列表:
		var id: String = str(观众["id"])
		var 账: Dictionary = _喂养.账本(id)
		var 回响: Dictionary = 账["回响"]
		var 行: String = "%s　听谁的：%s" % [剧本数据.取观众名(id), str(账["听谁的"])]
		if not 回响.is_empty():
			行 += "　→　现在满嘴都是「%s」（%s）" % [
				str(回响["意象"]),
				"顶回去了 · 偏了" if bool(回响["偏"]) else "接住了",
			]
		全文 += 行 + "\n"

	_台词.text = 全文


func _终点清单(立起: Array) -> String:
	var 片段: Array = []
	for 名 in 剧本数据.终点名:
		片段.append(("● " + str(名)) if 名 in 立起 else ("○ " + str(名)))
	return "凑齐   " + "    ".join(片段)
