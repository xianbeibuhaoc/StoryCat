## 记忆引擎 —— 裸系统的心脏。
##
## 规则四条，**都不告诉玩家**：
##   ① 没人说的词会淡，淡到 0 就掉
##   ② 一个词掉的时候，同句的别的词被拖累（级联）
##   ③ 同一个词在多句里是同一个词 —— 它掉了，好几句话一起空
##   ④ 你每回合只能说一个词：要么复述还在的，要么把掉了的填回去
##
## 故事无关。换故事 = 换一份句表。
class_name 记忆
extends RefCounted

# ---------------- 可调手感（直接在 裸系统.gd 里改，或改这里的默认值） ----------------
## 每回合所有词掉多少
var 每回合衰减: float = 0.13
## 一个词掉的时候，同句别的词被拖累多少
var 级联拖累: float = 0.16
## 你说一个词时，同句别的词跟着回多少血
var 整句回血: float = 0.14
## 一个词一回合最多被拖累几次（防止一波全灭）
var 单回合最多被拖累: int = 2
## 连锁最多跑几轮
var 连锁上限: int = 5

## ★ 核心规则：一个词掉多快，取决于**有几个人记得它**。
##   数字 = 证人数（1–4）。人越少越脆。
##   这条不告诉玩家 —— 他自己会发现"有些词怎么救都救不住"。
var 结实倍率: Dictionary = {1: 1.60, 2: 1.20, 3: 0.90, 4: 0.65}

## 你说过的词，接下来几回合不掉耐久。
## 1 = 说完这一回合它是满的，下一回合才开始掉。（不然"我刚救了它"看起来像没生效）
var 免疫回合数: int = 1

# ---------------- 状态 ----------------
## 词 -> 清晰度（0 = 掉了）
var 清晰度: Dictionary = {}
## 词 -> 有几个人记得它（1–4）
var 证人数: Dictionary = {}
## ★ 词 -> 还免疫几回合。
##   你刚说过的词，下回合不掉耐久 —— 不然"我刚救了它"这个动作看起来像没生效。
var _免疫: Dictionary = {}
## 每句 = 一串词；"" 表示空格
var 句子: Array = []
## 原始句表，用来算"复原了几格"
var 原句: Array = []
## 一共空掉了多少格
var 已遗忘: int = 0


func 载入(句表: Array, 证人表: Dictionary = {}) -> void:
	句子 = []
	原句 = []
	清晰度.clear()
	已遗忘 = 0
	证人数 = 证人表.duplicate()
	_免疫.clear()

	for 句 in 句表:
		var 新句: Array = []
		var 备份: Array = []
		for 词 in 句:
			新句.append(str(词))
			备份.append(str(词))
			清晰度[str(词)] = 1.0
		句子.append(新句)
		原句.append(备份)


## 这个词有几个证人（1–4）。没标的按 2 算。
func 取证人数(词: String) -> int:
	return clampi(int(证人数.get(词, 2)), 1, 4)


## 这个词每回合掉多少 —— 证人越少掉越快。
func 取衰减(词: String) -> float:
	var n: int = 取证人数(词)
	return 每回合衰减 * float(结实倍率.get(n, 1.0))


# ============================================================ 时间流逝
## 走一回合：全部淡一点 → 掉 → 拖累同句 → 又有人到 0 → 再掉……
##
## ⚠️ 连锁在**同一回合内**跑完。这是整个系统最戏剧的一处：
##    一个词掉了，带塌同句；塌下去的那个又掉，再带塌它那一片。
##    玩家会眼睁睁看着一次掉落变成一场雪崩。
func 流逝() -> Array:
	# ① 全部淡一点 —— ★ 每个词掉多少不一样，看有几个人记得它
	#    刚被说过的词有免疫，这一回合不掉
	for 词 in 清晰度.keys():
		var w: String = str(词)
		var 免: int = int(_免疫.get(w, 0))
		if 免 > 0:
			_免疫[w] = 免 - 1
			continue
		清晰度[w] = float(清晰度[w]) - 取衰减(w)

	# ② 连锁掉落（每回合每个词最多被拖累几次，免得一波全灭）
	var 全部掉了: Array = []
	var 拖累次数: Dictionary = {}

	for _轮 in 连锁上限:
		var 这一轮: Array = []
		for 词 in 清晰度.keys():
			var w: String = str(词)
			if float(清晰度[w]) > 0.0 or w in 全部掉了:
				continue
			# 已经掉过、现在不在任何句子里的，不算这一轮掉的
			if not _在句子里(w):
				continue
			这一轮.append(w)
		if 这一轮.is_empty():
			break

		for 词 in 这一轮:
			清晰度[词] = 0.0
			全部掉了.append(词)
			for i in 句子.size():
				var 句: Array = 句子[i]
				if not 词 in 句:
					continue
				# 清空它在所有句子里的槽位
				for j in 句.size():
					if str(句[j]) == 词:
						句[j] = ""
						已遗忘 += 1
				# 同句现场的词被拖累
				for 其他 in 句:
					var o: String = str(其他)
					if o == "" or not 清晰度.has(o):
						continue
					if int(拖累次数.get(o, 0)) >= 单回合最多被拖累:
						continue
					清晰度[o] = float(清晰度[o]) - 级联拖累
					拖累次数[o] = int(拖累次数.get(o, 0)) + 1
	return 全部掉了


# ============================================================ 玩家动作
## 复述：把一个还在句子里、但快淡的词再说一遍。
func 复述(词: String) -> bool:
	if not 清晰度.has(词):
		return false
	if float(清晰度[词]) <= 0.0:
		return false
	清晰度[词] = 1.0
	_免疫[词] = 免疫回合数
	_同句回血(词, 词)
	return true


## 填回：把一个掉了的词，填进某个空槽。
func 填回(词: String, 句号: int, 槽号: int) -> bool:
	if 句号 < 0 or 句号 >= 句子.size():
		return false
	var 句: Array = 句子[句号]
	if 槽号 < 0 or 槽号 >= 句.size():
		return false
	if str(句[槽号]) != "":
		return false
	句[槽号] = 词
	清晰度[词] = 1.0
	_免疫[词] = 免疫回合数
	_同句回血(词, 词)
	return true


func _同句回血(词: String, 除了: String) -> void:
	for 句 in 句子:
		if not 词 in 句:
			continue
		for 其他 in 句:
			var o: String = str(其他)
			if o != "" and o != 除了 and 清晰度.has(o):
				清晰度[o] = minf(1.0, float(清晰度[o]) + 整句回血)


# ============================================================ 查询
## 这个词现在还在不在任何句子里。
func _在句子里(词: String) -> bool:
	for 句 in 句子:
		if 词 in 句:
			return true
	return false


## 掉了的词（不在任何句子里，但还在词表里）。
func 掉了的词() -> Array:
	var 结果: Array = []
	for 词 in 清晰度.keys():
		if float(清晰度[词]) <= 0.0:
			结果.append(str(词))
	return 结果


## 还在句子里、清晰度低于这个数的词（快掉了，可以复述）。
func 快掉的词(阈值: float = 0.45) -> Array:
	var 结果: Array = []
	for 句 in 句子:
		for 词 in 句:
			var w: String = str(词)
			if w == "" or not 清晰度.has(w):
				continue
			if float(清晰度[w]) <= 阈值 and not w in 结果:
				结果.append(w)
	return 结果


## 还有几格是原来那个词。
func 复原数() -> int:
	var n: int = 0
	for i in 原句.size():
		var a: Array = 原句[i]
		var b: Array = 句子[i]
		for j in a.size():
			if j < b.size() and str(b[j]) == str(a[j]):
				n += 1
	return n


## 一共几格。
func 总数() -> int:
	var n: int = 0
	for 句 in 原句:
		n += (句 as Array).size()
	return n
