## 对局 —— 一局的流程和状态。**一行界面代码都没有。**
##
## ============================================================
## v3 §5 的核心循环，在这一层落地：
##
##   1. 四位亲历者分别讲述同一事件          → 数据里本来就写着
##   2. 玩家选一个说法作为当前故事的底本      → 选底本(讲者id)
##   3. 玩家替换一个词，或暂时不编辑         → 换词(旧, 新) / 什么也不做
##   4. 进入下一幕，观察上一次改写如何改变场景 → 下一幕()，变体在下一幕入口求值
##   5. 重复
##   6. 达成本故事的特定任务                → 引擎.任务进度()
##   7. 主角亲自经历最终版本                → 锚定 / 未达成
##
## ============================================================
## 三层纪律：
##   · 这一层里**不许**出现 get_node / Control / Color / 场景 preload
##   · 规则判断全在 引擎.gd，这一层只负责"什么时候叫它"
##   · 界面只能通过 取状态() 知道该画什么
class_name 对局
extends RefCounted

## ⚠️ 必须用这个常量来 new 引擎 —— 因为下面那个成员变量也叫「引擎」，
##    会把类名 引擎 遮住（`引擎.new()` 会解析成 Null.new）。
const 引擎类 := preload("res://脚本/系统/引擎.gd")

# ============================================================ 信号
signal 换幕(幕号: int, 总幕数: int, 幕名: String)
signal 场景变了(场景: Dictionary)
signal 你选了(讲者id: String)
signal 你选词(词: String)
signal 你换了(旧词: String, 新词: String, 处数: int)
signal 你撤了()
signal 因果链新增(一条: Dictionary)
signal 任务进度变了(进度: Dictionary)
signal 锚定(结果: Dictionary)
signal 未达成(结果: Dictionary)


# ============================================================ 状态
var 数据: Dictionary = {}
var 引擎: 引擎类 = null
var 幕: int = 1                   ## 1 起算
var 完了: bool = false
var 选中底本: String = ""
var 选中词: String = ""            ## 故事里被选中、准备被替换掉的那个词
var 草稿有: bool = false
var 本幕替换数: int = 0
var 锚定结果: Dictionary = {}
var 底本表: Array = []             ## 每一幕最终选了谁（重放用）
var 最后提示: String = ""

var _快照: Dictionary = {}


func _init(数据_: Dictionary = {}) -> void:
	if not 数据_.is_empty():
		载入(数据_)


# ============================================================ 开局 / 重来
func 载入(数据_: Dictionary) -> void:
	数据 = 数据_
	引擎 = 引擎类.new(数据)
	重来()


func 重来() -> void:
	引擎.重置()
	幕 = 1
	完了 = false
	选中底本 = ""
	选中词 = ""
	草稿有 = false
	本幕替换数 = 0
	锚定结果 = {}
	底本表.clear()
	最后提示 = ""
	_快照 = {}
	_进幕()


func 总幕数() -> int:
	return 故事.取总幕数(数据)


func _进幕() -> void:
	# ★ 变体在这里求值：用的是"此刻的故事"，也就是第 1..N-1 幕攒出来的东西。
	#   所以你在第 N 幕改的词，第 N+1 幕见效（v3 §5）。
	var 命: Dictionary = 引擎.定幕(幕)
	场景变了.emit(引擎.取场景(幕))
	换幕.emit(幕, 总幕数(), 幕名())
	var 进: Dictionary = 引擎.任务进度()
	任务进度变了.emit(进)
	if int(命.get("索引", -1)) >= 0 and not (命.get("因为", []) as Array).is_empty():
		因果链新增.emit({
			"幕": 幕, "因为": (命["因为"] as Array).duplicate(),
			"所以": str(命.get("所以", "")), "变体": int(命["索引"]),
		})


func 幕名() -> String:
	return str(故事.取幕(数据, 幕).get("名", ""))


# ============================================================ ① 选底本
func 选底本(id: String) -> Dictionary:
	if 完了:
		return {"ok": false, "提示": "这一局已经结束了。"}
	var 说法表: Array = 引擎.取说法(幕)
	var 找: Dictionary = 故事.取说法({"说法": 说法表}, id)
	if 找.is_empty():
		return {"ok": false, "提示": "这一幕没有这个人开口。"}

	# 换说法之前，先把本幕的改写撤掉 —— 否则改过的词会变成幽灵留在句子里
	if 草稿有:
		_回滚()
	if 选中底本 != "":
		引擎.撤回最后一句()

	选中词 = ""
	if 选中底本 == id:
		选中底本 = ""
		你选了.emit("")
		return {"ok": true, "提示": "取消选择。这一幕的故事还空着。"}

	选中底本 = id
	引擎.追加句子(幕, id, 找.get("词", []))
	你选了.emit(id)
	var 进: Dictionary = 引擎.任务进度()
	任务进度变了.emit(进)
	return {"ok": true, "提示": "用了「%s」的说法。" % 故事.取讲者名(数据, id)}


# ============================================================ ② 选一个词（要换掉的那个）
func 选词(词: String) -> Dictionary:
	if 完了:
		return {"ok": false, "提示": "这一局已经结束了。"}
	if 选中词 == 词:
		选中词 = ""
		你选词.emit("")
		return {"ok": true, "提示": "取消选择。"}
	if not 引擎.在故事里(词):
		return {"ok": false, "提示": "「%s」不在故事里。" % 词}
	if 故事.取词类(数据, 词) == "":
		return {"ok": false, "提示": "「%s」是这句话的骨架，换不了 —— 能换的只有五类词。" % 词}
	选中词 = 词
	你选词.emit(词)
	return {"ok": true, "提示": "要换掉「%s」—— 下面给它一个同类词。" % 词}


# ============================================================ ③ 换词
func 换词(旧词: String, 新词: String) -> Dictionary:
	if 完了:
		return {"ok": false, "提示": "这一局已经结束了。"}
	if 选中底本 == "":
		return {"ok": false, "提示": "先给这一幕选一个说法，再动它。"}
	if 主题.每幕替换次数 >= 0 and 本幕替换数 >= 主题.每幕替换次数:
		if 主题.允许撤销:
			return {"ok": false, "提示": "这一幕已经改过了。想换别的，先按【撤回改写】。"}
		return {"ok": false, "提示": "这一幕已经改过了。"}

	if not 草稿有:
		_快照 = 引擎.取快照()

	var 果: Dictionary = 引擎.换词(旧词, 新词, 幕)
	if not bool(果["ok"]):
		return {"ok": false, "提示": str(果["理由"])}

	草稿有 = true
	本幕替换数 += 1
	选中词 = ""
	你换了.emit(旧词, 新词, int(果["处"]))
	var 进: Dictionary = 引擎.任务进度()
	任务进度变了.emit(进)
	return {
		"ok": true,
		"提示": "「%s」换成了「%s」—— 故事里 %d 处一起变了。" % [旧词, 新词, int(果["处"])],
	}


# ============================================================ ④ 撤销本幕的改写
func 撤销() -> Dictionary:
	if 完了:
		return {"ok": false, "提示": "这一局已经结束了。"}
	if not 草稿有:
		return {"ok": false, "提示": "这一幕还没动过手。"}
	if not 主题.允许撤销:
		return {"ok": false, "提示": "这个版本不许撤回改写。"}
	_回滚()
	你撤了.emit()
	var 进: Dictionary = 引擎.任务进度()
	任务进度变了.emit(进)
	return {"ok": true, "提示": "改回来了。"}


func _回滚() -> void:
	if not 草稿有:
		return
	引擎.恢复(_快照)
	草稿有 = false
	本幕替换数 = 0
	_快照 = {}


# ============================================================ ⑤ 下一幕
func 下一幕() -> Dictionary:
	if 完了:
		return {"ok": false, "提示": "这一局已经结束了。"}
	if 选中底本 == "":
		return {"ok": false, "提示": "先选一个说法。"}

	底本表.append(选中底本)

	if 幕 >= 总幕数():
		完了 = true
		_收束()
		return {"ok": true, "提示": "收束。"}

	幕 += 1
	草稿有 = false
	本幕替换数 = 0
	选中底本 = ""
	选中词 = ""
	_快照 = {}
	_进幕()
	return {"ok": true, "提示": "第 %d 幕。" % 幕}


func _收束() -> void:
	var 进: Dictionary = 引擎.任务进度()
	var 结: Dictionary = {
		"达成": bool(进["达成"]),
		"任务": 进,
		"台词": str((数据.get("任务", {}) as Dictionary).get(
			"结局台词" if bool(进["达成"]) else "未达成台词", "")),
		"矛盾": 引擎.查矛盾(),
		"故事": 引擎.取故事文本(),
	}
	锚定结果 = 结
	if bool(进["达成"]):
		锚定.emit(结)
	else:
		未达成.emit(结)


# ============================================================ 重放（可复现性）
func 取重放() -> Dictionary:
	var 换表: Array = []
	for r in 引擎.替换记录:
		var 条: Dictionary = r
		换表.append({"幕": int(条["幕"]), "旧": str(条["旧"]), "新": str(条["新"])})
	return {
		"版本": 1,
		"故事": str(数据.get("id", "")),
		"底本": 底本表.duplicate(),
		"替换": 换表,
		"强制达成": 引擎.强制达成,
	}


## 用一份记录重跑一遍。跑完 完了 == true 表示跑通了。
func 从重放(记录: Dictionary) -> bool:
	var 底本: Array = 记录.get("底本", [])
	if 底本.is_empty():
		return false
	重来()
	引擎.强制达成 = bool(记录.get("强制达成", false))
	for i in 底本.size():
		var 号: int = i + 1
		if 号 > 总幕数():
			break
		选底本(str(底本[i]))
		for r in 记录.get("替换", []):
			var 条: Dictionary = r
			if int(条.get("幕", 0)) == 号:
				换词(str(条["旧"]), str(条["新"]))
		下一幕()
	return 完了


# ============================================================ 调试用
## 跳到第 N 幕：前面几幕自动用第一个人的说法铺一遍，故事是完整的。
func 跳幕(目标: int) -> Dictionary:
	var 到: int = clampi(目标, 1, 总幕数())
	重来()
	while 幕 < 到:
		var 表: Array = 引擎.取说法(幕)
		if 表.is_empty():
			break
		var 第一人: String = str((表[0] as Dictionary).get("讲者", ""))
		if 第一人 == "":
			break
		选底本(第一人)
		下一幕()
	return {"ok": true, "提示": "跳到第 %d 幕。" % 幕}


func 强制达成(开: bool = true) -> void:
	引擎.强制达成 = 开
	var 进: Dictionary = 引擎.任务进度()
	任务进度变了.emit(进)


# ============================================================ 取状态
func 取状态() -> Dictionary:
	var 讲者: Array = []
	for 人 in 故事.取讲者表(数据):
		var 条: Dictionary = 人
		var id: String = str(条.get("id", ""))
		var 说: Dictionary = 故事.取说法({"说法": 引擎.取说法(幕)}, id)
		讲者.append({
			"id": id,
			"名": str(条.get("名", id)),
			"短": str(条.get("短", "")),
			"色": str(条.get("色", "#211c16")),
			"立绘": str(条.get("立绘", "")),      # ← 美术空位
			"位": 条.get("位", null),              # ← 美术空位
			"文": str(说.get("文", "")),
			"词": 说.get("词", []),
			"选中": 选中底本 == id,
		})

	var 进: Dictionary = 引擎.任务进度()
	return {
		"幕": 幕,
		"总幕数": 总幕数(),
		"幕名": 幕名(),
		"完了": 完了,
		"前提": str(数据.get("前提", "")),
		"身份": str(数据.get("身份", "")),
		"任务说明": str(数据.get("任务说明", "")),
		"事实": 引擎.取事实(幕),
		"场景": 引擎.取场景(幕),
		"讲者": 讲者,
		"故事": 引擎.取故事行(),
		"选中底本": 选中底本,
		"选中词": 选中词,
		"候选": _候选表(),
		"替换记录": 引擎.替换记录.duplicate(true),
		"因果链": 引擎.因果链.duplicate(true),
		"本幕命中": (引擎.本幕命中.get(str(幕), {}) as Dictionary).duplicate(true),
		"矛盾": 引擎.查矛盾(),
		"任务": 进,
		"草稿": {"有": 草稿有, "次数": 本幕替换数},
		"可以": {
			"选底本": not 完了,
			"选词": not 完了 and 选中底本 != "",
			"换词": not 完了 and 选中词 != ""
				and (主题.每幕替换次数 < 0 or 本幕替换数 < 主题.每幕替换次数),
			"撤销": not 完了 and 草稿有 and 主题.允许撤销,
			"下一幕": not 完了 and 选中底本 != "",
		},
		"提示": 最后提示,
	}


## 候选词：没选词时给全体（只作"你听过这些词"的展示），选了词之后只给**同类**的。
func _候选表() -> Array:
	var 全体: Array = 引擎.候选(幕)
	var 结果: Array = []
	if 选中词 == "":
		for 条 in 全体:
			var 人: Dictionary = 条
			if bool(人["在故事里"]):
				continue
			结果.append({
					"词": str(人["词"]), "类": str(人["类"]),
					"能换": false, "理由": "先点故事里的一个词。",
				})
		return 结果

	var 类要: String = 故事.取词类(数据, 选中词)
	for 条 in 全体:
		var 人2: Dictionary = 条
		if str(人2["类"]) != 类要:
			continue
		if str(人2["词"]) == 选中词:
			continue
		var 判: Dictionary = 引擎.可以换(选中词, str(人2["词"]), 幕)
		结果.append({
			"词": str(人2["词"]), "类": str(人2["类"]),
			"能换": bool(判["ok"]), "理由": str(判["理由"]),
		})
	return 结果


# ============================================================ 取结算
func 取结算() -> Dictionary:
	var 进: Dictionary = 引擎.任务进度()
	var 达成: bool = bool(进["达成"])
	var 结: Dictionary = 锚定结果
	var 任务数据: Dictionary = 数据.get("任务", {})
	return {
		"故事": 引擎.取故事行(),
		"行": 引擎.取故事文本(),
		"任务": 进,
		"达成": 达成,
		"台词": str(结.get("台词", 任务数据.get(
			"结局台词" if 达成 else "未达成台词", ""))),
		"因果链": 引擎.因果链.duplicate(true),
		"词改变": 引擎.替换记录.duplicate(true),
		"矛盾": 引擎.查矛盾(),
		"其他版本": 校验其他达成(),
		"重放": 取重放(),
	}


# ============================================================ 其他合理达成方式（v3 §12 优先加强 4）
## 把 数据["其他达成"] 里每一条**真的跑一遍**，跑不通就标不成立。
## 这样结算里展示的另一条路一定是真话，不是写上去骗人的。
func 校验其他达成() -> Array:
	var 结果: Array = []
	for 条 in 数据.get("其他达成", []):
		if not (条 is Dictionary):
			continue
		var 路: Dictionary = 条
		var 试: Dictionary = _跑一条路(路)
		结果.append({
			"说明": str(路.get("说明", "")),
			"成立": bool(试["成立"]),
			"理由": str(试["理由"]),
			"底本": (路.get("底本", []) as Array).duplicate(),
			"替换": (路.get("替换", []) as Array).duplicate(true),
			"行": 试["行"],
		})
	return 结果


func _跑一条路(路: Dictionary) -> Dictionary:
	var 试: 引擎类 = 引擎类.new(数据)
	var 底本: Array = 路.get("底本", [])
	var 替换: Array = 路.get("替换", [])
	for i in mini(底本.size(), 总幕数()):
		var 号: int = i + 1
		试.定幕(号)
		var 人: String = str(底本[i])
		var 找: Dictionary = 故事.取说法({"说法": 试.取说法(号)}, 人)
		if 找.is_empty():
			return {"成立": false, "理由": "第 %d 幕没有「%s」的说法" % [号, 人], "行": []}
		试.追加句子(号, 人, 找.get("词", []))
		for r in 替换:
			var 条: Dictionary = r
			if int(条.get("幕", 0)) == 号:
				var 果: Dictionary = 试.换词(str(条["旧"]), str(条["新"]), 号)
				if not bool(果["ok"]):
					return {
						"成立": false,
						"理由": "第 %d 幕换不动：%s" % [号, str(果["理由"])],
						"行": 试.取故事文本(),
					}
	var 进: Dictionary = 试.任务进度()
	return {
		"成立": bool(进["达成"]),
		"理由": "" if bool(进["达成"]) else "这条路达不成任务",
		"行": 试.取故事文本(),
	}
