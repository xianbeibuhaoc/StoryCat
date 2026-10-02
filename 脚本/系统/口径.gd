## 口径 —— 引擎。
##
## ★ 一条根本规则，**不告诉玩家**：
##
##     你说出口的话，比他们说的重。
##     你说过的词，下一幕别人会跟着说 —— 它的证人数涨，它就掉得慢了。
##
##   于是：孤证可以被你说成事实。事实也可以被你冷落而死掉。
##   **你能造真，也能造假。游戏不判你。**
##
## 另外三条也是藏着的：
##   ① 一个词有几个人说过 → 决定它掉多快（1 人最先没，4 人几乎不掉）
##   ② 一个词变哑，同句的别的词被拖累 —— 一回合内连锁雪崩
##   ③ 同一个词在所有句子里是同一个词 —— 换掉它，好几句话一起变
##
## 与旧引擎（记忆.gd）的区别，只有两点，但情绪完全不同：
##   · 衰减到 0 的词**不消失**，只是降格成"哑"（划掉）。故事上留一个洞，不是丢一句话。
##   · 替换是**全局**的：改一处 = 改一片。这是"改词改意思"的玩法本体。
##
## 故事无关。换故事 = 换一份句表。
class_name 口径
extends RefCounted

# ============================================================ 档位
## 一个词的四种状态。由清晰度决定，**由视觉表达，不给数字**。
const 档_哑 := 0      ## 没人再提了 —— 划掉
const 档_传闻 := 1    ## 只有一个人这么说 —— 灰、加引号
const 档_存疑 := 2    ## 有人这么说 —— 淡黄
const 档_事实 := 3    ## 好几个人都这么说 —— 亮

const 阈值_事实 := 0.62
const 阈值_存疑 := 0.30

# ============================================================ 可调手感
var 每回合衰减: float = 0.11
## ★ 核心规则：掉多快取决于**有几个人记得它**。人越少越脆。
var 结实倍率: Dictionary = {1: 2.40, 2: 1.60, 3: 1.10, 4: 0.75}
var 级联拖累: float = 0.14
var 单回合最多被拖累: int = 2
var 连锁上限: int = 5
var 免疫回合数: int = 1

## 一个词**第一次进故事**时有多结实 —— 由它有几个证人决定。
## ★ 你用一个孤证词改写历史，改出来的那段历史，一开始就带"存疑"的底色。
const 入场清晰度: Dictionary = {1: 0.58, 2: 0.78, 3: 0.92, 4: 1.0}

## 说出口之后，那个词回到多少：`入场清晰度[证人数] + 说出口加成`，封顶 1.0。
##
##   1.0  = 直接回满。爽，但"你一个人说"和"四个人都跟着说"就没区别了 ——
##          探针实测：这样打，每回合救最脆的那个就能**零失手**（缝合度 0.845、划掉 0 个），
##          全局替换彻底变成废招，整个游戏没有取舍。
##
##   0.30 = 你只能把一个词**托起来一截**。它想真的站稳，得靠别人也跟着说。
##          ★ 这才是这个游戏想说的那句话的三步走：
##            **快没了 → 你说 → 有人接 → 它成了事实。**
##          一个只有你一个人说的词，永远托不到"事实"那一档。
var 说出口加成: float = 0.30

# ============================================================ 状态
## 故事 = 一串句子；每句 = 一串词。哑掉的词**留在原位**，不置空。
var 句子: Array = []
## 故事的原始版本。结算时用来对照"你在哪儿动了手"。
var 原句: Array = []
## 词 -> 清晰度（0 = 哑）
var 清晰度: Dictionary = {}
## 词 -> 有几个人说过它（1–4）。**动态**：你背书之后别人会跟着说，这个数会涨。
var 证人数: Dictionary = {}
## 词 -> {讲者id: true}
var 谁说过: Dictionary = {}
## 词 -> true：你说出口过。词块的视觉上会带一条金线。
var 背书标记: Dictionary = {}
## 词 -> true：进过故事（只有进过的，哑了才值得报出来）
var 进过故事: Dictionary = {}
## 你动过的手：[{幕, 旧, 新, 处}, ...]
var 替换记录: Array = []
## 账本：什么词、第几幕、进的故事。给结算念故事用。
var 进场顺序: Array = []

var _免疫: Dictionary = {}
var _哑了: Dictionary = {}
var _旧词: Dictionary = {}
## 上一个回合说出口、而且在场（这一幕有人提过）的词 —— 只有这些下一幕才会有人接。
var _待传: Dictionary = {}


func _init() -> void:
	pass


# ============================================================ 装填
func 载入(句表: Array = []) -> void:
	句子 = []
	原句 = []
	清晰度.clear()
	证人数.clear()
	谁说过.clear()
	背书标记.clear()
	进过故事.clear()
	替换记录.clear()
	进场顺序.clear()
	_免疫.clear()
	_哑了.clear()
	_旧词.clear()
	_待传.clear()
	if not 句表.is_empty():
		for 句 in 句表:
			_推句(句)


func _推句(词表: Array) -> Array:
	var 新句: Array = []
	var 备份: Array = []
	var 新词: Array = []
	for 词 in 词表:
		var w: String = str(词)
		新句.append(w)
		备份.append(w)
		if not 清晰度.has(w):
			# 首次出现：它带着自己那份证词的分量进来
			清晰度[w] = float(入场清晰度.get(取证人数(w), 0.78))
			进过故事[w] = true
			进场顺序.append(w)
			新词.append(w)
	句子.append(新句)
	原句.append(备份)
	return 新词


## 往里加一句新的话（一幕一句，攒成故事）。
func 追加句子(词表: Array) -> Array:
	return _推句(词表)


## 撤掉最后加进去的那一句（选错讲者、想改选的时候用）。
## 词的清晰度不动 —— 那些词你毕竟听过了。
func 撤回最后一句() -> void:
	if 句子.is_empty():
		return
	句子.pop_back()
	原句.pop_back()


# ============================================================ 谁说过
## 记录"这一幕这个人说过这些词"。证人数由此算出来 —— **包括他的否认**。
## ★ 老K 说"什么欢迎回来，没这回事"，系统照样算他说过"欢迎回来"。
##   否认也是一种复述。他越否认，那件事越结实。
func 记账(讲者id: String, 词表: Array) -> void:
	for 词 in 词表:
		var w: String = str(词)
		if not 谁说过.has(w):
			谁说过[w] = {}
		(谁说过[w] as Dictionary)[讲者id] = true
		证人数[w] = (谁说过[w] as Dictionary).size()


## 用在回响句上：他接了一句带 {词} 的话 = 他也说了这个词。
func 他也说了(讲者id: String, 词: String) -> void:
	记账(讲者id, [词])


func 取证人数(词: String) -> int:
	return clampi(int(证人数.get(词, 1)), 1, 4)


func 取衰减(词: String) -> float:
	return 每回合衰减 * float(结实倍率.get(取证人数(词), 1.0))


# ============================================================ 时间流逝
## 走一回合：全部淡一点 → 该哑的哑 → 拖累同句 → 又有人到 0 → 再哑……
##
## ⚠️ 连锁在**同一回合内**跑完。一个词哑了带塌同句，塌下去的那个又哑，再带塌它那一片。
##
## 返回本回合**新哑**的词。
func 流逝() -> Array:
	for 词 in 清晰度.keys():
		var w: String = str(词)
		var 免: int = int(_免疫.get(w, 0))
		if 免 > 0:
			_免疫[w] = 免 - 1
			continue
		if float(清晰度[w]) <= 0.0:
			continue
		清晰度[w] = maxf(0.0, float(清晰度[w]) - 取衰减(w))

	var 新哑: Array = []
	var 拖累次数: Dictionary = {}

	for _轮 in 连锁上限:
		var 这一轮: Array = []
		for 词 in 清晰度.keys():
			var w: String = str(词)
			if float(清晰度[w]) > 0.0 or _哑了.has(w):
				continue
			if not 在故事里(w):
				continue
			这一轮.append(w)
		if 这一轮.is_empty():
			break

		for 词 in 这一轮:
			_哑了[词] = true
			新哑.append(词)
			for 句 in 句子:
				if not 词 in 句:
					continue
				# 同句现场的词被拖累
				for 其他 in 句:
					var o: String = str(其他)
					if o == "" or o == 词 or not 清晰度.has(o):
						continue
					if _哑了.has(o):
						continue
					if int(拖累次数.get(o, 0)) >= 单回合最多被拖累:
						continue
					清晰度[o] = maxf(0.0, float(清晰度[o]) - 级联拖累)
					拖累次数[o] = int(拖累次数.get(o, 0)) + 1

	# 传播只持续一幕：读完就该清掉，免得一个词被反复"接力"
	_待传.clear()
	return 新哑


# ============================================================ ★ 动作一：说出口
## 把一个词**说出口**。
##
##   ① 它回满清晰度 —— 从"传闻"当场变回"事实"
##   ② 打上你的金线
##   ③ **只有在场的词，下一幕才有人接** → 证人数涨 → 它就掉得慢了
##
## ★★ 「在场」= 这一幕有人提过它（它在这一幕的手牌里）。
##    这一幕没人提的词，你说了也只是**你一个人记得** —— 它回满，但没人跟着说，
##    于是它照样按孤证的速度往下掉。
##
##    这一条把游戏从"每回合补最破的那个洞"变成了**时机**：
##      · 第 3 幕听到「欢迎回来」就当场说出口 → 四个人都跟着说 → 事实档
##      · 拖到第 6 幕才想起来救 → 只有你一个人说 → 存疑档，而且多半救不回来
##
##    你能造真，也能造假。但**你改不了已经没人提起的事**。
func 说出口(词: String, 在场: bool = true) -> bool:
	if not 清晰度.has(词):
		清晰度[词] = float(入场清晰度.get(取证人数(词), 0.78))
	背书标记[词] = true
	# ★ 托起来一截，不是回满 —— 见 说出口加成 的说明
	清晰度[词] = minf(1.0, float(入场清晰度.get(取证人数(词), 0.78)) + 说出口加成)
	_免疫[词] = 免疫回合数
	_哑了.erase(词)
	_同句回血(词)
	if 在场:
		_待传[词] = true
	else:
		_待传.erase(词)
	return true


## 上一个回合你说出口、而且**在场**的词。外层拿它去安排下一幕的回响。
func 待传的词() -> Array:
	var 结果: Array = []
	for 词 in _待传.keys():
		var w: String = str(词)
		if int(_免疫.get(w, 0)) > 0:
			结果.append(w)
	return 结果


func _同句回血(词: String) -> void:
	for 句 in 句子:
		if not 词 in 句:
			continue
		for 其他 in 句:
			var o: String = str(其他)
			if o != "" and o != 词 and 清晰度.has(o) and not _哑了.has(o):
				清晰度[o] = minf(1.0, float(清晰度[o]) + 0.14)


# ============================================================ ★ 动作二：换一个词（全局）
## 把故事里的「旧词」全换成「新词」——**所有句子一起变**。
##
## 这是整个游戏最强的一个动作，也是"改一个词，改一整段意思"的玩法本体。
## 新词带着**它自己的**结实度进来：
##   你用一句孤证去改写历史，你改出来的那段历史就是站不住的。
func 换词(旧词: String, 新词: String, 幕号: int = 0) -> bool:
	if 旧词 == 新词 or 旧词 == "" or 新词 == "":
		return false
	if not 在故事里(旧词):
		return false

	# ★ 新词带着**它自己的**结实度进来 —— 不跟旧词取长补短。
	#   你用一个孤证改写历史，改出来的那段历史就跟着变成"存疑"的。
	#   这是"造真/造假都要付代价"的地方：改一片历史要押上这个词的可信度。
	var 底: float = float(入场清晰度.get(取证人数(新词), 0.78))
	if not 清晰度.has(新词):
		清晰度[新词] = 底
		进过故事[新词] = true
		进场顺序.append(新词)
	else:
		# 已经掉下去的词拿来改写，也只是把它拉回它本来该有的样子，不多给
		清晰度[新词] = maxf(float(清晰度[新词]), 底)
	_哑了.erase(新词)

	var 换了几处: int = 0
	for 句 in 句子:
		for j in 句.size():
			if str(句[j]) == 旧词:
				句[j] = 新词
				换了几处 += 1
	if 换了几处 == 0:
		return false

	_旧词[旧词] = true
	替换记录.append({"幕": 幕号, "旧": 旧词, "新": 新词, "处": 换了几处})
	return true


# ============================================================ 查询
func 在故事里(词: String) -> bool:
	for 句 in 句子:
		if 词 in 句:
			return true
	return false


func 取档(词: String) -> int:
	if not 清晰度.has(词):
		return 档_哑
	var c: float = float(清晰度[词])
	if c <= 0.0:
		return 档_哑
	if c < 阈值_存疑:
		return 档_传闻
	if c < 阈值_事实:
		return 档_存疑
	return 档_事实


func 取清晰(词: String) -> float:
	return float(清晰度.get(词, 0.0))


func 是背书的(词: String) -> bool:
	return 背书标记.has(词)


## 故事里出现过的所有词（按第一次进场的顺序，去重）。
func 故事里的词() -> Array:
	var 结果: Array = []
	for 句 in 句子:
		for 词 in 句:
			var w: String = str(词)
			if w != "" and not w in 结果:
				结果.append(w)
	return 结果


## 快哑的词（还在故事里、清晰度低于阈值）。
func 快哑的词(阈值: float = 0.34) -> Array:
	var 结果: Array = []
	for w in 故事里的词():
		var 词: String = str(w)
		if 取档(词) == 档_哑:
			continue
		if float(清晰度.get(词, 0.0)) <= 阈值:
			结果.append(词)
	return 结果


## 已经哑了的词（进过故事、现在划掉了）。
func 哑了的词() -> Array:
	var 结果: Array = []
	for w in 故事里的词():
		var 词: String = str(w)
		if 取档(词) == 档_哑:
			结果.append(词)
	return 结果


func 取替换记录() -> Array:
	return 替换记录.duplicate(true)


# ============================================================ ★ 回响（幕间）
## 上一幕你说出口的词，这一幕会有人接话。
##
## ★ 挑人规则（这条以前埋在界面层里，搬进来是为了让自检和界面跑的是同一个游戏）：
##   优先挑**还没说过这个词**的人 —— 这样证人数才真的涨得上去。
##
## 一个人"承"（接住），一个人"顶"（顶回去）。返回 [{讲者, 词, 顶}]，
## 外层负责把对应的那句话显示出来。
##
## ★★ 而且接话的人**就算说过这个词了** —— 哪怕他说的是「什么『欢迎回来』，没这回事」。
##     否认也是一种复述。他越否认，这个词越结实。
func 安排回响(本幕: Dictionary, 讲述者: Array, 传的词: Array) -> Array:
	var 结果: Array = []
	var 本幕已接: Dictionary = {}
	for 词 in 传的词:
		var w: String = str(词)
		var 候选人: Array = []
		for 人 in 讲述者:
			var id: String = str(人.get("id", ""))
			if 本幕已接.has(id):
				continue
			var 条: Dictionary = 本幕.get(id, {})
			if w in 条.get("词", []):
				continue                      # 他本来就要说这个词，不用接
			if 谁说过.has(w) and (谁说过[w] as Dictionary).has(id):
				continue                      # 他以前说过了，涨不了证人数
			候选人.append(id)
		for i in mini(2, 候选人.size()):
			var id: String = str(候选人[i])
			本幕已接[id] = true
			他也说了(id, w)
			结果.append({"讲者": id, "词": w, "顶": i == 1})
	return 结果


# ============================================================ 草稿
## ★ 打草稿用：把整个状态拍一张快照。
##
## 玩家在按「下一幕」之前应该能随便试 —— 改错了、想换个词、想改回原样，
## 都当没发生过。**这个游戏的情绪是"好奇"，不是"怕点错"。**
## 所以这里不省事：状态是全量深拷贝，恢复之后连替换记录都回到原样。
func 快照() -> Dictionary:
	return {
		"句子": 句子.duplicate(true),
		"原句": 原句.duplicate(true),
		"清晰度": 清晰度.duplicate(true),
		"证人数": 证人数.duplicate(true),
		"谁说过": 谁说过.duplicate(true),
		"背书标记": 背书标记.duplicate(true),
		"进过故事": 进过故事.duplicate(true),
		"替换记录": 替换记录.duplicate(true),
		"进场顺序": 进场顺序.duplicate(true),
		"免疫": _免疫.duplicate(true),
		"哑了": _哑了.duplicate(true),
		"旧词": _旧词.duplicate(true),
		"待传": _待传.duplicate(true),
	}


func 恢复(存: Dictionary) -> void:
	if 存.is_empty():
		return
	句子 = (存["句子"] as Array).duplicate(true)
	原句 = (存["原句"] as Array).duplicate(true)
	清晰度 = (存["清晰度"] as Dictionary).duplicate(true)
	证人数 = (存["证人数"] as Dictionary).duplicate(true)
	谁说过 = (存["谁说过"] as Dictionary).duplicate(true)
	背书标记 = (存["背书标记"] as Dictionary).duplicate(true)
	进过故事 = (存["进过故事"] as Dictionary).duplicate(true)
	替换记录 = (存["替换记录"] as Array).duplicate(true)
	进场顺序 = (存["进场顺序"] as Array).duplicate(true)
	_免疫 = (存["免疫"] as Dictionary).duplicate(true)
	_哑了 = (存["哑了"] as Dictionary).duplicate(true)
	_旧词 = (存["旧词"] as Dictionary).duplicate(true)
	_待传 = (存["待传"] as Dictionary).duplicate(true)


# ============================================================ 结算用的统计
func 统计() -> Dictionary:
	var 数: Dictionary = {"事实": 0, "存疑": 0, "传闻": 0, "哑": 0, "总": 0}
	for w in 故事里的词():
		var 词: String = str(w)
		数["总"] = int(数["总"]) + 1
		match 取档(词):
			档_事实: 数["事实"] = int(数["事实"]) + 1
			档_存疑: 数["存疑"] = int(数["存疑"]) + 1
			档_传闻: 数["传闻"] = int(数["传闻"]) + 1
			_: 数["哑"] = int(数["哑"]) + 1
	return 数


## 缝合度 0–1：这个故事有多少是站得住的。
func 缝合度() -> float:
	var 数: Dictionary = 统计()
	var 总: int = int(数["总"])
	if 总 <= 0:
		return 0.0
	var 分: float = (
		float(数["事实"]) * 1.0
		+ float(数["存疑"]) * 0.62
		+ float(数["传闻"]) * 0.30
		+ float(数["哑"]) * 0.0
	)
	return 分 / float(总)


## 故事里同时出现了"不可能同时成立"的两个词 → 一处矛盾。
## 纯查表，零 NLP。互斥词对由策划手写。
func 查矛盾(互斥表: Array) -> Array:
	var 在: Dictionary = {}
	for w in 故事里的词():
		var 词: String = str(w)
		if 取档(词) != 档_哑:
			在[词] = true
	var 结果: Array = []
	for 对 in 互斥表:
		if not (对 is Array) or (对 as Array).size() < 2:
			continue
		var a: String = str(对[0])
		var b: String = str(对[1])
		if a in 在 and b in 在:
			结果.append([a, b])
	return 结果


## 念故事：逐句给出文本，哑掉的词用 〖〗 包起来（念不出来）。
func 取故事文本() -> Array:
	var 结果: Array = []
	for 句 in 句子:
		var 行: String = ""
		for 词 in 句:
			var w: String = str(词)
			if w == "":
				continue
			if 取档(w) == 档_哑:
				行 += "〖%s〗" % w
			elif 取档(w) == 档_传闻:
				行 += "「%s」" % w
			else:
				行 += w
		if 行 != "":
			结果.append(行)
	return 结果
