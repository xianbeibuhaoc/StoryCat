## 引擎 —— 这个游戏的规则。**和故事无关。**
##
## ============================================================
## 它只管六件事，一个字的剧情都没有：
##
##   ① 攒故事        —— 每一幕选一个说法进来，句子按顺序排
##   ② 换词          —— 全局替换，而且**只能换成同一类的词**
##   ③ 求变体        —— "故事现在这样，这一幕该变成什么样"
##   ④ 查矛盾        —— 互斥表，纯查表，零 NLP
##   ⑤ 判任务        —— 拆成一条条可显示的进度
##   ⑥ 快照 / 重放    —— 撤销和"可复现"都靠它
##
## ★★ 六条硬纪律（自检会查）：
##
##   1. 这个文件里**不许出现任何故事专有名词**（"欢迎回来""校门口"一个都不许）。
##      换故事 = 换一份数据，引擎一行不动（v3 §11）。
##   2. **零随机**。不许出现 randi / randf / shuffle —— v3 §6 要求故事"可复现"。
##   3. 不碰界面。不 import 场景，不 get_node。
##   4. 变体**从前往后第一条命中的生效**，命中结果**缓存在本幕上**，本幕之内不再重算。
##      → 所以"你在第 N 幕改的词，第 N+1 幕见效"，和 v3 §5 的循环一致。
##   5. 替换是**已经发生的历史**，不会被后面的幕撤销 —— 变体条件里的 "换过" 看的是记录。
##   6. 句子里的词**永远不删**，只换。
class_name 引擎
extends RefCounted

const 无 = -1

## 故事数据。只读。
var 数据: Dictionary = {}

## 攒出来的故事：[{ "幕":int, "讲者":String, "词":[String…] }, …]
var 句子: Array = []

## 你动过的手：[{ "幕":int, "旧":String, "新":String, "类":String, "处":int }, …]
var 替换记录: Array = []

## 因果链：[{ "幕":int, "因为":[String…], "所以":String, "变体":int }, …]
var 因果链: Array = []

## 本幕命中的变体缓存：幕号 -> { "索引":int, "因为":[…], "所以":… }
var 本幕命中: Dictionary = {}

## 调试用：强制任务达成。
var 强制达成: bool = false

var _快照: Dictionary = {}


func _init(数据_ : Dictionary = {}) -> void:
	if not 数据_.is_empty():
		载入(数据_)


# ============================================================ 装填 / 重置
func 载入(数据_: Dictionary) -> void:
	数据 = 数据_
	重置()


func 重置() -> void:
	句子.clear()
	替换记录.clear()
	因果链.clear()
	本幕命中.clear()
	强制达成 = false
	_快照.clear()


# ============================================================ ① 攒故事
## 把某一幕某个人的说法放进故事。返回新句子的序号；失败返回 -1。
func 追加句子(幕号: int, 讲者id: String, 词表: Array) -> int:
	var 行: Array = []
	for 词 in 词表:
		var w: String = str(词)
		if w != "":
			行.append(w)
	if 行.is_empty():
		return -1
	句子.append({"幕": 幕号, "讲者": 讲者id, "词": 行})
	return 句子.size() - 1


## 撤掉最后放进来的那句（改主意换底本的时候用）。
func 撤回最后一句() -> void:
	if not 句子.is_empty():
		句子.pop_back()


func 句数() -> int:
	return 句子.size()


# ============================================================ ② 换词
func 在故事里(词: String) -> bool:
	for 句 in 句子:
		if 词 in (句["词"] as Array):
			return true
	return false


## 故事里现在有的所有词，按出场顺序去重。
func 故事里的词() -> Array:
	var 结果: Array = []
	for 句 in 句子:
		for 词 in (句["词"] as Array):
			var w: String = str(词)
			if w != "" and not w in 结果:
				结果.append(w)
	return 结果


## 到第 N 幕为止，四个人**说过的**词（去重，按出现顺序）。
## 这就是"你听过的词" —— 默认的候选池（主题.候选来源 == "听过的"）。
func 听过的词(幕号: int) -> Array:
	var 结果: Array = []
	for 号 in range(1, clampi(幕号, 1, 故事.取总幕数(数据)) + 1):
		var 幕: Dictionary = 故事.取幕(数据, 号)
		for 条 in 幕.get("说法", []):
			for 词 in (条 as Dictionary).get("词", []):
				var w: String = str(词)
				if w != "" and not w in 结果:
					结果.append(w)
	return 结果


## 这一幕能拿来替换的候选词。
## 返回 [{ "词","类","在故事里":bool, "听过了":bool }, …]
func 候选(幕号: int) -> Array:
	var 池: Array = []
	if 主题.候选来源 == "全部":
		池 = 故事.全部词(数据)
	else:
		池 = 听过的词(幕号)

	var 结果: Array = []
	for w in 池:
		var 词: String = str(w)
		if not 故事.有词(数据, 词):
			continue
		结果.append({
			"词": 词,
			"类": 故事.取词类(数据, 词),
			"在故事里": 在故事里(词),
			"听过了": 词 in 听过的词(幕号),
		})
	return 结果


## 能不能换。返回 {"ok":bool, "理由":String}
func 可以换(旧: String, 新: String, 幕号: int = 0) -> Dictionary:
	if 旧 == "" or 新 == "":
		return {"ok": false, "理由": "还没选到词。"}
	if 旧 == 新:
		return {"ok": false, "理由": "还是同一个词。"}
	if not 故事.有词(数据, 旧):
		return {"ok": false, "理由": "「%s」是这句话的骨架，换不了。" % 旧}
	if not 在故事里(旧):
		return {"ok": false, "理由": "「%s」不在故事里，没得换。" % 旧}
	if not 故事.有词(数据, 新):
		return {"ok": false, "理由": "「%s」不是这个故事里的词。" % 新}

	var 类旧: String = 故事.取词类(数据, 旧)
	var 类新: String = 故事.取词类(数据, 新)
	if 类旧 != 类新:
		return {
			"ok": false,
			"理由": "只能换成同一类的词：「%s」是%s，「%s」是%s。" % [旧, 类旧, 新, 类新],
		}
	if 主题.候选来源 == "听过的" and not 新 in 听过的词(幕号):
		return {"ok": false, "理由": "「%s」还没人提过 —— 你还不知道有这个词。" % 新}
	return {"ok": true, "理由": ""}


## 全局替换：故事里所有含「旧」的句子一起变。
## 返回 {"ok":bool, "处":int, "理由":String}
func 换词(旧: String, 新: String, 幕号: int = 0) -> Dictionary:
	var 判: Dictionary = 可以换(旧, 新, 幕号)
	if not bool(判["ok"]):
		return {"ok": false, "处": 0, "理由": str(判["理由"])}

	var 处: int = 0
	for 句 in 句子:
		var 词表: Array = 句["词"]
		for i in 词表.size():
			if str(词表[i]) == 旧:
				词表[i] = 新
				处 += 1
	if 处 == 0:
		return {"ok": false, "处": 0, "理由": "故事里没有「%s」。" % 旧}

	替换记录.append({
		"幕": 幕号, "旧": 旧, "新": 新, "类": 故事.取词类(数据, 旧), "处": 处,
	})
	return {"ok": true, "处": 处, "理由": ""}


# ============================================================ ③ 求变体
## ★ 进入某一幕时调一次。算出这一幕被你的改写改成了什么样，并**缓存**。
##   返回 { "索引":int(-1=没有变体命中), "因为":[…], "所以":String }
func 定幕(幕号: int) -> Dictionary:
	var 键: String = str(幕号)
	if 本幕命中.has(键):
		return 本幕命中[键]

	var 幕: Dictionary = 故事.取幕(数据, 幕号)
	var 变体表: Array = 幕.get("变体", [])
	var 结果: Dictionary = {"索引": 无, "因为": [], "所以": ""}
	for i in 变体表.size():
		var 变: Dictionary = 变体表[i]
		var 因为: Array = []
		if _判条件(变.get("当", {}), 因为):
			结果 = {"索引": i, "因为": 因为, "所以": str(变.get("反应", ""))}
			本幕命中[键] = 结果
			if not 因为.is_empty() or str(变.get("反应", "")) != "":
				因果链.append({
					"幕": 幕号, "因为": 因为.duplicate(),
					"所以": str(变.get("反应", "")), "变体": i,
				})
			return 结果

	本幕命中[键] = 结果
	return 结果


## 变体条件求值。满足时把"为什么"追加进 因为。
## ★ 同一条里写了多个键 = **全部要满足**（AND）。所以 {"含":[…], "不含":[…]} 是"既要又要"。
func _判条件(条: Dictionary, 因为: Array) -> bool:
	if 条.is_empty():
		return false
	var 有键: bool = false

	if 条.has("含"):
		有键 = true
		for w in 条["含"]:
			if not 在故事里(str(w)):
				return false
		for w in 条["含"]:
			因为.append("故事里现在有「%s」" % str(w))

	if 条.has("不含"):
		有键 = true
		for w in 条["不含"]:
			if 在故事里(str(w)):
				return false
		for w in 条["不含"]:
			因为.append("「%s」不在故事里" % str(w))

	if 条.has("换过"):
		有键 = true
		var 命中: Array = []
		for 对 in 条["换过"]:
			if not (对 is Array) or (对 as Array).size() < 2:
				continue
			var 旧: String = str(对[0])
			var 新: String = str(对[1])
			for r in 替换记录:
				var 条2: Dictionary = r
				if str(条2["旧"]) == 旧 and (新 == "*" or str(条2["新"]) == 新):
					命中.append("你把「%s」换成了「%s」" % [旧, str(条2["新"])])
		if 命中.is_empty():
			return false
		因为.append_array(命中)

	if 条.has("任"):
		有键 = true
		var 子中: bool = false
		for 子 in 条["任"]:
			if not (子 is Dictionary):
				continue
			var 子因为: Array = []
			if _判条件(子, 子因为):
				因为.append_array(子因为)
				子中 = true
				break
		if not 子中:
			return false

	return 有键


func 取变体(幕号: int) -> Dictionary:
	var 幕: Dictionary = 故事.取幕(数据, 幕号)
	var 变体表: Array = 幕.get("变体", [])
	var 索引: int = int(定幕(幕号).get("索引", 无))
	if 索引 < 0 or 索引 >= 变体表.size():
		return {}
	return 变体表[索引]


## 这一幕最终的中立事实（变体可能覆盖过）。
func 取事实(幕号: int) -> String:
	var 幕: Dictionary = 故事.取幕(数据, 幕号)
	var 变: Dictionary = 取变体(幕号)
	return str(变.get("事实", 幕.get("事实", "")))


## 这一幕最终的场景（变体可能覆盖过）。【美术空位】
func 取场景(幕号: int) -> Dictionary:
	var 幕: Dictionary = 故事.取幕(数据, 幕号)
	var 基础: Dictionary = (幕.get("场景", {}) as Dictionary).duplicate(true)
	var 变: Dictionary = 取变体(幕号)
	if 变.has("场景"):
		for 键 in (变["场景"] as Dictionary):
			基础[键] = (变["场景"] as Dictionary)[键]
	return 基础


## 这一幕四个人最终说的话（变体可能覆盖过某人）。
func 取说法(幕号: int) -> Array:
	var 幕: Dictionary = 故事.取幕(数据, 幕号)
	var 变: Dictionary = 取变体(幕号)
	var 覆盖: Dictionary = 变.get("覆盖", {})
	var 结果: Array = []
	for 条 in 幕.get("说法", []):
		var 人: Dictionary = (条 as Dictionary).duplicate(true)
		var id: String = str(人.get("讲者", ""))
		if 覆盖.has(id):
			var 补: Dictionary = 覆盖[id]
			if 补.has("文"):
				人["文"] = 补["文"]
			if 补.has("词"):
				人["词"] = 补["词"]
		结果.append(人)
	return 结果


# ============================================================ ④ 查矛盾
## 互斥表里"两词同时在故事里"的对。返回 [[a, b], …]
func 查矛盾() -> Array:
	var 在: Dictionary = {}
	for 词 in 故事里的词():
		在[str(词)] = true
	var 结果: Array = []
	for 对 in 数据.get("互斥", []):
		if not (对 is Array) or (对 as Array).size() < 2:
			continue
		var a: String = str(对[0])
		var b: String = str(对[1])
		if 在.has(a) and 在.has(b):
			结果.append([a, b])
	return 结果


# ============================================================ ⑤ 判任务
## 任务拆成一条条能显示的进度（v3 §12 优先加强 2：让玩家中途知道走向）。
## 返回 {"说明","已满足","总","条目":[…],"差什么":[…],"达成":bool}
func 任务进度() -> Dictionary:
	var 任务: Dictionary = 数据.get("任务", {})
	var 条件: Dictionary = 任务.get("达成", {})
	var 条目: Array = []

	if 条件.has("含"):
		for w in 条件["含"]:
			var 词: String = str(w)
			条目.append({"条件": "「%s」要留在故事里" % 词, "满足": 在故事里(词)})

	if 条件.has("不含"):
		for w in 条件["不含"]:
			var 词2: String = str(w)
			条目.append({"条件": "「%s」不能再出现" % 词2, "满足": not 在故事里(词2)})

	if 条件.has("至少"):
		var 名单: Array = []
		var 有: bool = false
		for w in 条件["至少"]:
			var 词3: String = str(w)
			名单.append("「%s」" % 词3)
			if 在故事里(词3):
				有 = true
		条目.append({"条件": "%s 里至少有一个" % "、".join(名单), "满足": 有})

	if 条件.has("不含对"):
		for 对 in 条件["不含对"]:
			if not (对 is Array) or (对 as Array).size() < 2:
				continue
			var a: String = str(对[0])
			var b: String = str(对[1])
			条目.append({
				"条件": "「%s」和「%s」不能同时成立" % [a, b],
				"满足": not (在故事里(a) and 在故事里(b)),
			})

	var 已满足: int = 0
	var 差什么: Array = []
	for 条 in 条目:
		if bool((条 as Dictionary)["满足"]):
			已满足 += 1
		else:
			差什么.append(str((条 as Dictionary)["条件"]))

	var 达成: bool = 条目.size() > 0 and 差什么.is_empty()
	if 强制达成:
		达成 = true
		差什么.clear()
		if 条目.is_empty():
			条目.append({"条件": "（调试：强制达成）", "满足": true})
		已满足 = 条目.size()

	return {
		"说明": str(数据.get("任务说明", "")),
		"已满足": 已满足,
		"总": 条目.size(),
		"条目": 条目,
		"差什么": 差什么,
		"达成": 达成,
	}


# ============================================================ ⑥ 快照 / 重放
## 全量深拷贝。撤销草稿、调试跳幕都靠它。
func 取快照() -> Dictionary:
	return {
		"句子": 句子.duplicate(true),
		"替换记录": 替换记录.duplicate(true),
		"因果链": 因果链.duplicate(true),
		"本幕命中": 本幕命中.duplicate(true),
		"强制达成": 强制达成,
	}


func 恢复(存: Dictionary) -> void:
	if 存.is_empty():
		return
	句子 = (存["句子"] as Array).duplicate(true)
	替换记录 = (存["替换记录"] as Array).duplicate(true)
	因果链 = (存["因果链"] as Array).duplicate(true)
	本幕命中 = (存["本幕命中"] as Dictionary).duplicate(true)
	强制达成 = bool(存.get("强制达成", false))


## 清掉变体缓存（跳幕 / 重放的时候要清）。
func 清变体缓存() -> void:
	本幕命中.clear()


# ============================================================ 念故事
## 每句 → { "幕", "讲者", "讲者名", "词":[{"词","类","换过"}…] }
func 取故事行() -> Array:
	var 换过的: Dictionary = {}
	for r in 替换记录:
		换过的[str((r as Dictionary)["新"])] = true

	var 结果: Array = []
	for 句 in 句子:
		var 条: Dictionary = 句
		var 行: Array = []
		for 词 in (条["词"] as Array):
			var w: String = str(词)
			行.append({
				"词": w,
				"类": 故事.取词类(数据, w),
				"换过": 换过的.has(w),
				"物件": 故事.取物件(数据, w),
			})
		结果.append({
			"幕": int(条["幕"]),
			"讲者": str(条["讲者"]),
			"讲者名": 故事.取讲者名(数据, str(条["讲者"])),
			"词": 行,
		})
	return 结果


## 念成一行字（自检断"逐字相同"用）。
func 取故事文本() -> Array:
	var 结果: Array = []
	for 句 in 取故事行():
		var 行: String = ""
		for 词条 in (句["词"] as Array):
			行 += str((词条 as Dictionary)["词"])
		结果.append(行)
	return 结果
