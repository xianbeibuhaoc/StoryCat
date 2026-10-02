## 喂养引擎 —— 涌现发生的地方。
##
## 规则三条：
##   ① 你采纳谁讲的段落 → 那段里的意象，喂给**另外两个人**（记在"是谁喂的"名下）
##   ② 一个人开口时，先看**谁喂他最多**，再取那个人最常讲的**一样东西**
##   ③ 那个人占了他听到的大半 → 他"偏"了 → 回响变成「驳」，否则是「承」
##
## ⚠️ 没有人写"老刀会被冷落成什么样"。
## 他只是听，然后长。**这是整套东西里唯一不是设计出来的部分。**
##
## 第一版有个坑：直接取"听得最多的意象"，结果永远是「粥」——因为粥在故事里
## 出现得太多，谁讲都带着它。改成"先认人、再认物"之后才会有变化。
class_name 喂养
extends RefCounted

## 偏的判定：至少被喂过这么多次，且单一来源占比超过这个数。
## 门槛别太低——七幕下来一个人最多被喂六次，0.6 会让所有人都偏。
const 偏_最少次数: int = 3
const 偏_占比: float = 0.7

## id -> 来源讲述者id -> 次数（被这个人喂了几次）
var _次数: Dictionary = {}
## id -> 来源讲述者id -> {意象: 次数}
var _账: Dictionary = {}


func _init() -> void:
	重置()


func 重置() -> void:
	_次数.clear()
	_账.clear()
	for 观众 in 剧本数据.观众列表:
		var id: String = str(观众["id"])
		_次数[id] = {}
		_账[id] = {}


# ============================================================ 喂
## 有人被采纳了。他讲的这一段，喂给另外两个人。
## 意象 = 剧本数据.取喂物(...)；空串表示这一段什么也没喂出去。
func 喂(被采纳者: String, 意象: String) -> void:
	if 意象 == "":
		return

	for 观众 in 剧本数据.观众列表:
		var id: String = str(观众["id"])
		if id == 被采纳者:
			continue
		# 一个人被喂一次，只记一次
		_次数[id][被采纳者] = int(_次数[id].get(被采纳者, 0)) + 1
		var 该源: Dictionary = _账[id].get(被采纳者, {})
		该源[意象] = int(该源.get(意象, 0)) + 1
		_账[id][被采纳者] = 该源


# ============================================================ 取
## 这个人现在开口，末尾会带上什么。
## 返回 {} = 还没被喂过，他还是原来那个人。
func 取回响(id: String) -> Dictionary:
	var 我的源: Dictionary = _次数.get(id, {})
	if 我的源.is_empty():
		return {}

	# ① 谁喂我最多
	var 主源: String = ""
	var 主源次: int = 0
	var 总数: int = 0
	for 源 in 我的源:
		var c: int = int(我的源[源])
		总数 += c
		if c > 主源次:
			主源次 = c
			主源 = str(源)
	if 主源 == "":
		return {}

	# ② 那个人喂我的东西里，哪一样最多
	var 该源: Dictionary = _账.get(id, {}).get(主源, {})
	var 意象: String = ""
	var 最多次: int = 0
	for 名 in 该源:
		var c: int = int(该源[名])
		if c > 最多次:
			最多次 = c
			意象 = str(名)
	if 意象 == "":
		return {}

	# ③ 被同一个人喂到饱和 → 偏了
	var 偏了: bool = 总数 >= 偏_最少次数 and float(主源次) / float(总数) > 偏_占比

	return {
		"文本": 剧本数据.取回响句(id, 意象, 偏了),
		"意象": 意象,
		"偏": 偏了,
		"源": 主源,
		"源次": 主源次,
		"总数": 总数,
	}


## 这个人此刻"偏"没偏。
func 偏了吗(id: String) -> bool:
	return bool(取回响(id).get("偏", false))


## 账本摘要，给结算透镜用。
func 账本(id: String) -> Dictionary:
	var 我的源: Dictionary = _次数.get(id, {})
	var 片段: Array = []
	for 源 in 我的源:
		片段.append("%s×%d" % [剧本数据.取观众名(str(源)), int(我的源[源])])
	var 听: String = "什么也没听到" if 片段.is_empty() else "、".join(片段)
	return {
		"听谁的": 听,
		"回响": 取回响(id),
	}
