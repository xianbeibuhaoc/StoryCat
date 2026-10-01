## 主控 —— 一幕一幕往下走。
##
## demo 只跑 2 幕，只验证一件事：
##   「读三个版本，然后只能选一个」——这件事本身有没有乐趣。
##
## 卡牌 / 落差 / 观众变形 / 5 幕 / 美术，全部故意不做。
## 那些是锦上添花；核心选择不成立的话，它们全都白做。
##
## 界面全部在 场景/Main.tscn 里，这个脚本只管流程。
extends Control

const 卡片场景: PackedScene = preload("res://场景/角色.tscn")

# ============================================================ 界面引用
# 用"场景唯一名"（场景树里名字旁边的 % 图标）引用。
# 这样节点在场景里怎么挪都不会断，不用写一长串路径。
@onready var _幕标题: Label = %幕标题
@onready var _结局行: Label = %结局行
@onready var _观众区: HBoxContainer = %观众区
@onready var _正史文本: Label = %正史文本
@onready var _锚点行: Label = %锚点行
@onready var _提示行: Label = %提示行
@onready var _下一幕按钮: Button = %下一幕按钮
@onready var _重来按钮: Button = %重来按钮

# ============================================================ 状态
const 总幕数: int = 2

var 当前幕: int = 1
var 上一幕采纳: String = ""
var 本幕已选: String = ""
## 本幕选中、但还没提交的段落。改选时直接覆盖它。
var 本幕草稿: String = ""
## 已经提交的段落。
var 正史: Array = []
var 卡片表: Dictionary = {}


func _ready() -> void:
	_下一幕按钮.pressed.connect(_下一幕)
	_重来按钮.pressed.connect(_重来)
	_进入幕(1)


# ============================================================ 流程
func _进入幕(幕号: int) -> void:
	当前幕 = 幕号
	本幕已选 = ""
	本幕草稿 = ""

	_幕标题.text = "第 %d 幕 · %s" % [幕号, 剧本数据.幕名[幕号 - 1]]
	_结局行.text = "规定结局 · " + 剧本数据.结局正文
	_提示行.text = "注视其中一位 —— 只能选一个"
	_下一幕按钮.text = "下一幕 →" if 幕号 < 总幕数 else "看结果 →"
	_下一幕按钮.visible = false
	_重来按钮.visible = false

	# 清掉上一幕的卡
	for 子 in _观众区.get_children():
		_观众区.remove_child(子)
		子.queue_free()
	卡片表.clear()

	# 按当前前情，问每位观众要他的版本
	for 观众 in 剧本数据.观众列表:
		var 卡: 观众卡片 = 卡片场景.instantiate()
		卡.name = str(观众["id"])
		_观众区.add_child(卡)
		卡.设置内容(观众, 剧本数据.取文本(幕号, 上一幕采纳, str(观众["id"])))
		卡.被点击.connect(_采纳)
		卡片表[str(观众["id"])] = 卡

	_刷新正史()


## 点卡 = 采纳。在按「下一幕」之前，随时可以改选。
func _采纳(id: String) -> void:
	if 本幕已选 == id:
		return

	本幕已选 = id
	本幕草稿 = 剧本数据.取文本(当前幕, 上一幕采纳, id)

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
	上一幕采纳 = 本幕已选

	if 当前幕 >= 总幕数:
		_结算()
	else:
		_进入幕(当前幕 + 1)


func _重来() -> void:
	正史.clear()
	上一幕采纳 = ""
	_进入幕(1)


# ============================================================ 结算
func _结算() -> void:
	for 观众id in 卡片表:
		卡片表[观众id].锁定()

	_下一幕按钮.visible = false
	_重来按钮.visible = true
	_幕标题.text = "demo 到此为止"

	var 全文: String = "\n\n".join(正史)
	var 命中: Array = 剧本数据.命中锚点(全文)

	if 命中.size() == 剧本数据.锚点.size():
		_提示行.text = "结局达成。"
	else:
		_提示行.text = "命中 %d / %d 个锚点 —— 2 幕埋不下一条完整的线，正式版要 5 幕。" % [
			命中.size(), 剧本数据.锚点.size()
		]


# ============================================================ 刷新
func _刷新正史() -> void:
	# 显示 = 已提交的 + 本幕尚未提交的草稿
	var 段落: Array = 正史.duplicate()
	if 本幕草稿 != "":
		段落.append(本幕草稿)

	if 段落.is_empty():
		_正史文本.text = "（还没有人开口。）"
		_正史文本.add_theme_color_override("font_color", Color("#847c8c"))
	else:
		_正史文本.text = "\n\n".join(段落)
		_正史文本.add_theme_color_override("font_color", Color("#e9e3d9"))
	_刷新锚点()


func _刷新锚点() -> void:
	var 全文: String = "\n\n".join(正史) + 本幕草稿
	var 命中: Array = 剧本数据.命中锚点(全文)
	var 片段: Array = []
	for 词 in 剧本数据.锚点:
		片段.append(("● " + str(词)) if 词 in 命中 else ("○ " + str(词)))
	_锚点行.text = "锚点   " + "    ".join(片段)
