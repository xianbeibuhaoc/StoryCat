## 策略探针 —— 用数据回答"这游戏到底在玩什么"。
##
## 跑法：
##   Godot_v4.4-stable_win64_console.exe --headless --path . --script res://脚本/测试/策略探针.gd
##
## 它跑的是和界面同一套引擎 + 同一个 安排回响 规则，所以结论可以直接用。
##
## 两件事要查清：
##   ① **"每回合救最脆的那个"是不是支配策略** —— 如果是，这游戏就没有取舍。
##   ② **"换词"是不是被"说出口"完全压住了** —— 如果是，玩家永远不该换词。
##      以及顺便扫一遍衰减系数，看平衡点落在哪儿。
extends SceneTree

const 引擎 := preload("res://脚本/系统/口径.gd")

const 每策略局数 := 300

const 策略表: Array = [
	"① 从不出手",
	"② 乱来（随机）",
	"③ 只救最脆的（不挑场合）",
	"④ 只换词：挑证人数最高的",
	"⑤ 计划型：第3幕救那句 + 其余救最脆的",
	"⑥ 计划型 + 换词合并同义",
]

## 衰减系数扫描 —— 0.11 是当前值
const 衰减表: Array = [0.11, 0.14, 0.17]

## 说出口是否直接回满（true = 旧手感，false = 由证人数决定）
const 加成表: Array = [1.0, 0.5, 0.3, 0.17, 0.0]


func _initialize() -> void:
	print("")
	print("════════ 口径 · 策略探针（每格 %d 局）════════" % 每策略局数)

	print("")
	print("【表一】当前默认（说出口加成 0.30，衰减 0.11）")
	_跑一批(0.30, 0.11)

	print("")
	print("【表二】硬核变体：加成 0（一个只有你说过的词，永远到不了「事实」档）")
	_跑一批(0.0, 0.11)

	print("")
	print("【表三】换判断 + 衰减系数一起扫（只跑最优解 ③ 和 ⑤）")
	print("")
	print("加成  衰减    打法                          那句活   缝合度  划掉  事实  打架")
	print("────  ──────  ────────────────────────────  ──────  ──────  ────  ────  ────")
	for 满 in 加成表:
		for d in 衰减表:
			for 名 in ["③ 只救最脆的", "⑤ 计划型：第3幕救那句"]:
				var r: Dictionary = _跑一个(str(名), float(d), float(满))
				print("%-5s  %.2f    %-30s  %5.1f%%   %.3f  %4.1f  %4.1f  %4.2f" % [
					"%.2f" % float(满), float(d), str(名),
					float(r["结尾活"]) / float(每策略局数) * 100.0,
					float(r["缝合度"]), float(r["哑词"]), float(r["事实词"]), float(r["打架"]),
				])
		print("")

	print("注：「那句」= 「%s」。只有同桌在第 3 幕说过一次 ——" % 口径词表.结尾词)
	print("    只有那一回合它才「在场」（有人提过）。错过那一幕，")
	print("    你再说它也只剩你一个人记得。")
	print("")
	quit(0)


# ============================================================ 跑一批
func _跑一批(回满: float, 衰减: float) -> void:
	print("")
	print("策略                            那句活  那句哑  没写进   缝合度  划掉  事实  打架  出手")
	print("──────────────────────────────  ──────  ──────  ──────  ──────  ────  ────  ────  ────")
	for 策略 in 策略表:
		var r: Dictionary = _跑一个(str(策略), 衰减, 回满)
		var n: float = float(每策略局数)
		print("%-30s  %5.1f%%  %5.1f%%  %5.1f%%   %.3f  %4.1f  %4.1f  %4.2f  %4.1f" % [
			str(策略),
			float(r["结尾活"]) / n * 100.0,
			float(r["结尾哑"]) / n * 100.0,
			float(r["结尾没写"]) / n * 100.0,
			float(r["缝合度"]), float(r["哑词"]), float(r["事实词"]),
			float(r["打架"]), float(r["用了动作"]),
		])


func _跑一个(策略: String, 衰减: float, 回满: float) -> Dictionary:
	var 累: Dictionary = {
		"结尾活": 0, "结尾哑": 0, "结尾没写": 0,
		"缝合度": 0.0, "哑词": 0.0, "事实词": 0.0, "打架": 0.0, "用了动作": 0.0,
	}
	for i in 每策略局数:
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 7919 + 13
		var r: Dictionary = _走一局(策略, 衰减, 回满, rng)

		if not bool(r["结尾在"]):
			累["结尾没写"] = int(累["结尾没写"]) + 1
		elif int(r["结尾档"]) == 口径.档_哑:
			累["结尾哑"] = int(累["结尾哑"]) + 1
		else:
			累["结尾活"] = int(累["结尾活"]) + 1

		for k in ["缝合度", "哑词数", "事实词数", "打架数", "用了动作"]:
			var 键: String = str(k).replace("数", "")
			累[键] = float(累.get(键, 0.0)) + float(r[k])

	var n: float = float(每策略局数)
	for k in ["缝合度", "哑词", "事实词", "打架", "用了动作"]:
		累[k] = float(累[k]) / n
	return 累


# ============================================================ 走一局
func _走一局(策略: String, 衰减: float, 回满: float, rng: RandomNumberGenerator) -> Dictionary:
	var e: 口径 = 引擎.new()
	e.每回合衰减 = 衰减
	e.说出口加成 = 回满
	var 传的词: Array = []
	var 动作数: int = 0

	for i in 口径词表.幕表.size():
		var 幕号: int = i + 1
		var 本幕: Dictionary = 口径词表.取幕(幕号)
		var 手牌: Array = 口径词表.手牌(幕号)

		for 人 in 口径词表.讲述者:
			var id: String = str(人["id"])
			e.记账(id, 本幕.get(id, {}).get("词", []))
		e.安排回响(本幕, 口径词表.讲述者, 传的词)

		e.追加句子(本幕.get(_选人(策略, rng), {}).get("词", []))

		if _做动作(e, 策略, 幕号, 手牌, rng):
			动作数 += 1

		传的词 = e.待传的词()
		e.流逝()

	var 数: Dictionary = e.统计()
	return {
		"结尾在": e.在故事里(口径词表.结尾词),
		"结尾档": e.取档(口径词表.结尾词),
		"缝合度": e.缝合度(),
		"哑词数": int(数["哑"]),
		"事实词数": int(数["事实"]),
		"打架数": e.查矛盾(口径词表.互斥).size(),
		"用了动作": 动作数,
	}


func _选人(策略: String, rng: RandomNumberGenerator) -> String:
	if 策略.begins_with("②"):
		return str(口径词表.讲述者[rng.randi() % 口径词表.讲述者.size()]["id"])
	# 其余打法都固定选同桌 ——「欢迎回来」只在他第 3 幕那句里。
	# 这本身就是一条策略：**选谁的版本进故事，等于选哪些词有机会被救。**
	return "tong"


# ============================================================ 动手
func _做动作(e: 口径, 策略: String, 幕号: int, 手牌: Array, rng: RandomNumberGenerator) -> bool:
	if 策略.begins_with("①"):
		return false

	if 策略.begins_with("②"):
		if rng.randf() < 0.75:
			var 词表: Array = e.故事里的词()
			if 词表.is_empty():
				return false
			var w: String = str(词表[rng.randi() % 词表.size()])
			e.说出口(w, w in 手牌)
			return true
		return false

	if 策略.begins_with("④"):
		return _换词(e, 手牌, false)

	# ⑤⑥：先把那句最脆的话救住 —— 但必须在它**在场**的第 3 幕
	if not e.是背书的(口径词表.结尾词):
		if 幕号 == 3:
			e.说出口(口径词表.结尾词, true)
			return true

	# ⑥ 优先用"换词合并"；其余用"说出口"
	if 策略.begins_with("⑥"):
		if _换词(e, 手牌, true):
			return true

	var w: String = _最该救(e)
	if w == "" or e.是背书的(w):
		return false
	e.说出口(w, w in 手牌)
	return true


## 救谁：还活着、快没了的；同句里快死的邻居越多越优先（防雪崩）。
func _最该救(e: 口径) -> String:
	var 最好: String = ""
	var 最好分: float = 1e9
	for 词 in e.故事里的词():
		var w: String = str(词)
		if e.是背书的(w):
			continue
		if e.取档(w) == 口径.档_哑:
			continue                      # 已经划掉的不救：出手要花在还来得及的地方
		var 分: float = e.取清晰(w)
		for 句 in e.句子:
			if not w in 句:
				continue
			var 同病: int = 0
			for 其 in 句:
				var o: String = str(其)
				if o != w and e.取清晰(o) < 0.34:
					同病 += 1
			分 -= 0.10 * float(同病)   # 同句还有俩快死的 → 先救它，不然一起塌
		if 分 < 最好分:
			最好分 = 分
			最好 = w
	return 最好


## 换词。
##   只合并 = true  → 只换成一个**已经在故事里、且更结实**的词（合并同义，少一个会死的词）
##   只合并 = false → 允许引入手牌里的新词（可能是个孤证，反而把历史改虚）
func _换词(e: 口径, 手牌: Array, 只合并: bool) -> bool:
	var 目标: String = ""
	var 目标分: float = -1e9
	for 词 in e.故事里的词():
		var w: String = str(词)
		if e.是背书的(w):
			continue
		var 处: int = 0
		for 句 in e.句子:
			for x in 句:
				if str(x) == w:
					处 += 1
		var 分: float = (1.0 - e.取清晰(w)) * 2.0 + float(处) * 0.5
		if 分 > 目标分:
			目标分 = 分
			目标 = w
	if 目标 == "":
		return false

	var 新: String = ""
	var 新分: float = -1e9
	for 词 in 手牌:
		var w: String = str(词)
		if w == 目标:
			continue
		if 只合并 and not e.在故事里(w):
			continue                       # 合并只认故事里已有的词
		if not 只合并 and e.在故事里(w):
			continue                       # 引入新说法
		# 合并优先挑结实的；引入新说法优先挑证人数多的
		var 分: float = e.取清晰(w) if 只合并 else float(e.取证人数(w))
		if 分 > 新分:
			新分 = 分
			新 = w
	if 新 == "":
		return false
	return e.换词(目标, 新, 0)
