## 主控 —— 一幕一幕往下走。
##
## 七幕（出行遇转险夜终）。每一幕：
##   多位观众各自给出"下一段"，玩家只能采纳一个。
##
## 玩家要凑齐的不是三个词，而是三个"形状"——
## 判定藏在每段的"关"里，看不出来，只能靠读懂文意判断。
##
## 卡牌 / 地图 / 观众变形 / 美术，暂时故意不做。
##
## 界面全部在 场景/Main.tscn 里，这个脚本只管流程。
extends Control

const 卡片场景: PackedScene = preload("res://场景/角色.tscn")

# ============================================================ 界面引用
# 用"场景唯一名"（场景树里名字旁边的 % 图标）引用。
# 这样节点在场景里怎么挪都不会断，不用写一长串路径。
@onready var _幕标题: Label = %幕标题
@onready var _结局行: Label = %结局行
@onready var _条件行: Label = %条件行
@onready var _观众区: HBoxContainer = %观众区
@onready var _正史文本: Label = %正史文本
@onready var _锚点行: Label = %锚点行
@onready var _提示行: Label = %提示行
@onready var _下一幕按钮: Button = %下一幕按钮
@onready var _重来按钮: Button = %重来按钮

# ============================================================ 状态
const 总幕数: int = 7

var 当前幕: int = 1
var 上一幕采纳: String = ""
var 本幕已选: String = ""
## 本幕选中、但还没提交的那一段（整个字典，含"文"和"关"）。
var 本幕草稿: Dictionary = {}
## 已经提交的段落（数组，每项是一个"段"字典）。
var 正史: Array = []
var 卡片表: Dictionary = {}
## 每位观众累计被采纳过几次。目前只作显示，还没有后果。
var 采纳次数: Dictionary = {}


func _ready() -> void:
	_下一幕按钮.pressed.connect(_下一幕)
	_重来按钮.pressed.connect(_重来)
	_重置计数()
	_进入幕(1)


func _重置计数() -> void:
	采纳次数.clear()
	for 观众 in 剧本数据.观众列表:
		采纳次数[str(观众["id"])] = 0


# ============================================================ 流程
func _进入幕(幕号: int) -> void:
	当前幕 = 幕号
	本幕已选 = ""
	本幕草稿 = {}

	_幕标题.text = "第 %d 幕 · %s" % [幕号, 剧本数据.幕名[幕号 - 1]]
	_结局行.text = "终点 · 他从没去过的地方"
	_条件行.text = _条件说明()
	_提示行.text = "读三段，选一段。你选的那一版会变成故事。"
	# 锚点行全程留空 —— 凑到几样由你自己读出来，不给进度条。
	_锚点行.text = ""
	_下一幕按钮.text = "下一幕 →" if 幕号 < 总幕数 else "收束 →"
	_下一幕按钮.visible = false
	_重来按钮.visible = false

	# 清掉上一幕的卡
	for 子 in _观众区.get_children():
		_观众区.remove_child(子)
		子.queue_free()
	卡片表.clear()

	# 按当前前情，问每位观众要他的版本
	for 观众 in 剧本数据.观众列表:
		var id: String = str(观众["id"])
		var 卡: 观众卡片 = 卡片场景.instantiate()
		卡.name = id
		_观众区.add_child(卡)
		卡.设置内容(观众, 剧本数据.取文本(幕号, 上一幕采纳, id), int(采纳次数.get(id, 0)))
		卡.被点击.connect(_采纳)
		卡片表[id] = 卡

	_刷新正史()


## 开头那句"要凑齐哪三样"。写成意思，不写成词——这样才没法扫。
func _条件说明() -> String:
	var 片段: Array = []
	for i in 剧本数据.终点说明.size():
		片段.append("%d. %s" % [i + 1, str(剧本数据.终点说明[i])])
	return "要走到那里，故事得凑齐三样：   " + "     ".join(片段)


## 点卡 = 采纳。在按「下一幕」之前，随时可以改选。
func _采纳(id: String) -> void:
	if 本幕已选 == id:
		return

	本幕已选 = id
	本幕草稿 = 剧本数据.取段(当前幕, 上一幕采纳, id)

	for 观众id in 卡片表:
		卡片表[观众id].设为已选(观众id == id)

	_提示行.text = "已采纳「%s」。改主意的话，点别人就行 —— 按下「%s」才算数。" % [
		剧本数据.取观众名(id), _下一幕按钮.text
	]
	_下一幕按钮.visible = true
	_刷新正史()


## 到这里才真正提交本幕的选择，其他版本永久作废。
func _下一幕() -> void:
	if 本幕已选 == "":
		return

	正史.append(本幕草稿)
	采纳次数[本幕已选] = int(采纳次数.get(本幕已选, 0)) + 1
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


# ============================================================ 结算
func _结算() -> void:
	for 观众id in 卡片表:
		卡片表[观众id].锁定()
		# 本幕的提交刚刚才发生，把计数补上
		卡片表[观众id].设置采纳数(int(采纳次数.get(观众id, 0)))

	_下一幕按钮.visible = false
	_重来按钮.visible = true
	_幕标题.text = "完"

	# 到这一步才揭晓：终点原文 + 你凑齐了哪几样
	var 各段关: Array = []
	for 段 in 正史:
		各段关.append((段 as Dictionary).get("关", []))
	var 立起: Array = 剧本数据.汇总终点(各段关)

	_结局行.text = "终点 · " + 剧本数据.结局正文
	_条件行.text = _条件说明()
	_锚点行.text = _终点清单(立起)

	match 立起.size():
		3:
			_提示行.text = "三样都凑齐了。他走到了那里。"
		2:
			_提示行.text = "差一样。故事拐了个弯，停在了别处。"
		1:
			_提示行.text = "只凑齐一样。这故事离那个终点还远。"
		_:
			_提示行.text = "一样也没凑齐。这个故事和那个终点，从头到尾无关。"


func _终点清单(立起: Array) -> String:
	var 片段: Array = []
	for 名 in 剧本数据.终点名:
		片段.append(("● " + str(名)) if 名 in 立起 else ("○ " + str(名)))
	return "凑齐   " + "    ".join(片段)


# ============================================================ 刷新
func _刷新正史() -> void:
	# 显示 = 已提交的 + 本幕尚未提交的草稿
	var 段落: Array = []
	for 段 in 正史:
		段落.append(str((段 as Dictionary).get("文", "")))
	if not 本幕草稿.is_empty():
		段落.append(str(本幕草稿.get("文", "")))

	if 段落.is_empty():
		_正史文本.text = "（还没有人开口。）"
		_正史文本.add_theme_color_override("font_color", Color("#847c8c"))
	else:
		_正史文本.text = "\n\n".join(段落)
		_正史文本.add_theme_color_override("font_color", Color("#e9e3d9"))
	# 注意：这里**不刷新终点进度**。全程不给，是这一版的核心改动。
