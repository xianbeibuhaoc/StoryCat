## 裸系统 —— 只管手感，不接任何剧情。
##
## 一回合 = 你选一个词（**只是选中，随时可以改**）+ 按「下一回合」才生效
##        → 时间流逝一格：词变淡、该掉的掉、掉的时候带塌一片
##
## **规则一条都不告诉玩家。** 让它自己被发现——那才是这个游戏好玩的地方。
extends Control

const 词块脚本 := preload("res://脚本/normal/词块.gd")

const 计划_无 := 0
const 计划_复述 := 1
const 计划_填回 := 2

@onready var _回合行: Label = %回合行
@onready var _遗忘行: Label = %遗忘行
@onready var _句子区: VBoxContainer = %句子区
@onready var _遗忘词行: HBoxContainer = %遗忘词行
@onready var _遗忘框: PanelContainer = %遗忘框
@onready var _提示行: Label = %提示行
@onready var _下一回合按钮: Button = %下一回合按钮
@onready var _重来按钮: Button = %重来按钮

var _记忆: 记忆 = 记忆.new()
var 回合: int = 0
var _完了: bool = false

# ---- 本回合的草稿。按「下一回合」之前随便改。----
var _计划: int = 计划_无
var _计划词: String = ""
var _计划句号: int = -1
var _计划槽号: int = -1


func _ready() -> void:
	_下一回合按钮.pressed.connect(_下一回合)
	_重来按钮.pressed.connect(_重来)
	_重来()


func _重来() -> void:
	_记忆.载入(测试词表.句表, 测试词表.证人数)
	回合 = 0
	_完了 = false
	_清计划()
	_提示行.text = "点句子里快淡的词＝再说一遍　·　点下面掉了的词、再点一个空槽＝放回去　·　选好了再按「下一回合」"
	_下一回合按钮.visible = true
	_下一回合按钮.text = "下一回合 →"
	_重建()


func _清计划() -> void:
	_计划 = 计划_无
	_计划词 = ""
	_计划句号 = -1
	_计划槽号 = -1


# ============================================================ 界面
func _重建() -> void:
	_回合行.text = "回合 %d / %d" % [回合, 测试词表.回合数]
	_遗忘行.text = "已遗忘 %d" % _记忆.已遗忘
	_遗忘行.add_theme_color_override(
		"font_color", Color("#e0776a") if _记忆.已遗忘 > 0 else Color("#6b6472")
	)

	# ---- 句子 ----
	for 子 in _句子区.get_children():
		_句子区.remove_child(子)
		子.queue_free()

	for i in _记忆.句子.size():
		var 句: Array = _记忆.句子[i]
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", 8)
		_句子区.add_child(行)

		for j in 句.size():
			var 内容: String = str(句[j])
			var 块: 词块 = 词块脚本.new()
			行.add_child(块)
			块.被点.connect(_点了)

			if 内容 != "":
				# 句中词：同一个词在多句里都会一起亮，因为它本来就是同一个词
				var 选: bool = _计划 != 计划_无 and 内容 == _计划词
				块.设为句中词(内容, float(_记忆.清晰度.get(内容, 0.0)), i, j, 选)
			else:
				# 空槽：如果这里是你的落点，就把词淡淡地预填进去
				var 幽灵: String = ""
				if _计划 == 计划_填回 and _计划句号 == i and _计划槽号 == j:
					幽灵 = _计划词
				块.设为空槽(i, j, 幽灵)

	# ---- 掉了的词 ----
	for 子 in _遗忘词行.get_children():
		_遗忘词行.remove_child(子)
		子.queue_free()

	var 掉了: Array = _记忆.掉了的词()
	_遗忘框.visible = not 掉了.is_empty()
	for 词 in 掉了:
		var 块: 词块 = 词块脚本.new()
		_遗忘词行.add_child(块)
		块.被点.connect(_点了)
		块.设为池中词(str(词), _计划 == 计划_填回 and _计划词 == str(词))


# ============================================================ 点词 = 只是选中
func _点了(词: String, 句号: int, 槽号: int) -> void:
	if _完了:
		return

	# ① 点了下面"掉了的词"
	if 句号 < 0:
		if _计划 == 计划_填回 and _计划词 == 词:
			_清计划()                      # 再点一次 = 取消
			_提示行.text = "取消选择。"
		else:
			_计划 = 计划_填回
			_计划词 = 词
			_计划句号 = -1
			_计划槽号 = -1
			_提示行.text = "想把「%s」放回哪儿？点上面一个空槽。" % 词
		_重建()
		return

	# ② 点了句子里已有的词 → 打算复述它
	if str(_记忆.句子[句号][槽号]) != "":
		var 目标: String = str(_记忆.句子[句号][槽号])
		if _计划 == 计划_复述 and _计划词 == 目标:
			_清计划()
			_提示行.text = "取消选择。"
		else:
			_计划 = 计划_复述
			_计划词 = 目标
			_计划句号 = 句号
			_计划槽号 = 槽号
			_提示行.text = "打算再说一遍「%s」。不满意就点别的，或者再点它一下取消。" % 目标
		_重建()
		return

	# ③ 点了空槽
	if _计划 == 计划_填回 and _计划词 != "":
		_计划句号 = 句号
		_计划槽号 = 槽号
		_提示行.text = "「%s」放这儿。换地方就点别的空槽。" % _计划词
		_重建()
		return

	_提示行.text = "先点下面一个掉了的词，再点这里的空槽。"


# ============================================================ 下一回合 = 才生效
func _下一回合() -> void:
	if _完了:
		return
	if _计划 == 计划_无:
		_提示行.text = "这一回合你还没选词。"
		return
	if _计划 == 计划_填回 and _计划槽号 < 0:
		_提示行.text = "点了「%s」，还得点一个空槽告诉它放哪儿。" % _计划词
		return

	var 说法: String = ""
	if _计划 == 计划_复述:
		_记忆.复述(_计划词)
		说法 = "你把「%s」又说了一遍。" % _计划词
	else:
		_记忆.填回(_计划词, _计划句号, _计划槽号)
		说法 = "「%s」被你放回去了。" % _计划词
	_清计划()

	回合 += 1
	var 掉了: Array = _记忆.流逝()
	_重建()

	if not 掉了.is_empty():
		_提示行.text = "%s　——　可是「%s」掉了。" % [说法, "、".join(掉了)]
	else:
		_提示行.text = 说法

	if 回合 >= 测试词表.回合数:
		_结算()


func _结算() -> void:
	_完了 = true
	_下一回合按钮.visible = false
	_提示行.text = "走完了。原来那 %d 格里，还剩 %d 格。　一共空掉 %d 格。" % [
		_记忆.总数(), _记忆.复原数(), _记忆.已遗忘
	]
