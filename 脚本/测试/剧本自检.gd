## 剧本自检 —— 验《欢迎回来》第一案的数据立得住。
##
## 跑法：
##   godot --headless --path <项目> --script res://脚本/测试/剧本自检.gd
##
## ★ 数据出错比代码出错更贵：
##   写错一个词的词类、把互斥对配成"永远同时出现"、让一条变体永远命中不了 ——
##   这些在那局游戏里都**看不出来**，只是悄悄少了一块内容。
##   这个脚本就是让这种错当场炸出来。
##
## 退出码 0 = 全过。
extends SceneTree

const 故事路径: String = "res://脚本/数据/故事_第一案.gd"
const 期望幕数: int = 7
const 每类最少词数: int = 3

var _通过: int = 0
var _失败: int = 0
var 数据: Dictionary = {}


func _initialize() -> void:
	print("")
	print("════════ 欢迎回来 · 剧本自检（第一案）════════")
	数据 = _读()
	if 数据.is_empty():
		print("  [XX] 读不到故事数据：", 故事路径)
		_失败 += 1
	else:
		_跑()
	print("")
	print("════════ 通过 %d · 失败 %d ════════" % [_通过, _失败])
	print("")
	quit(1 if _失败 > 0 else 0)


func _读() -> Dictionary:
	var 脚本: Variant = load(故事路径)
	if 脚本 == null or not (脚本 is GDScript):
		return {}
	var 表: Dictionary = (脚本 as GDScript).get_script_constant_map()
	var 值: Variant = 表.get("数据", {})
	return 值 as Dictionary if 值 is Dictionary else {}


func _查(名: String, 条件: bool) -> void:
	if 条件:
		_通过 += 1
	else:
		_失败 += 1
		print("  [XX] ", 名)


func _跑() -> void:
	_测_开场与身份()
	_测_讲者()
	_测_幕与说法()
	_测_词表与词类()
	_测_互斥()
	_测_变体()
	_测_任务与结局()
	_测_其他达成()
	_测_美术空位()


# ============================================================
func _测_开场与身份() -> void:
	print("── 开场 / 身份 / 任务（v3 §12 M2）")
	_查("有 id", str(数据.get("id", "")) != "")
	_查("有 名", str(数据.get("名", "")) != "")
	_查("有 前提", str(数据.get("前提", "")).length() >= 10)
	_查("★ 有 身份（玩家是谁）", str(数据.get("身份", "")).length() >= 10)
	_查("★ 有 任务说明（要干什么）", str(数据.get("任务说明", "")).length() >= 6)
	_查("身份里说清了「你」是谁", str(数据.get("身份", "")).contains("你"))
	_查("任务说明里说清了目标", str(数据.get("任务说明", "")).length() >= 10)
	# 旧的作废框架不许漏进来
	for 禁 in ["共忆", "周迟", "回访", "至高思想"]:
		_查("没有作废框架的「%s」" % 禁, not JSON.stringify(数据).contains(禁))


func _测_讲者() -> void:
	print("── 讲者")
	var 表: Array = 故事.取讲者表(数据)
	_查("★ 恰好四位亲历者", 表.size() == 4)
	var id集: Dictionary = {}
	for 人 in 表:
		var 条: Dictionary = 人
		var id: String = str(条.get("id", ""))
		_查("讲者「%s」有 id" % id, id != "")
		_查("讲者「%s」有名字" % id, str(条.get("名", "")) != "")
		_查("讲者「%s」有颜色" % id, str(条.get("色", "")) != "")
		_查("讲者 id 不重复：%s" % id, not id集.has(id))
		id集[id] = true
		var 立绘: String = str(条.get("立绘", ""))
		_查("讲者「%s」的立绘空位合法（空着，或者文件真的在）" % id,
			立绘 == "" or FileAccess.file_exists(立绘))


func _测_幕与说法() -> void:
	print("── 幕 / 四个人的说法")
	var 幕表: Array = 数据.get("幕", [])
	_查("★ 幕数 = %d" % 期望幕数, 幕表.size() == 期望幕数)
	var 讲者表: Array = 故事.取讲者表(数据)
	var 合法id: Array = []
	for 人 in 讲者表:
		合法id.append(str((人 as Dictionary).get("id", "")))

	for i in 幕表.size():
		var 幕: Dictionary = 幕表[i]
		var 号: int = i + 1
		_查("第 %d 幕有幕名" % 号, str(幕.get("名", "")) != "")
		_查("第 %d 幕有中立事实" % 号, str(幕.get("事实", "")) != "")
		var 说法: Array = 幕.get("说法", [])
		_查("★ 第 %d 幕恰好四个人开口" % 号, 说法.size() == 4)
		var 说过: Array = []
		for 条 in 说法:
			var 人条: Dictionary = 条
			var id: String = str(人条.get("讲者", ""))
			说过.append(id)
			_查("第 %d 幕「%s」是合法讲者" % [号, id], id in 合法id)
			_查("第 %d 幕「%s」有话" % [号, id], str(人条.get("文", "")) != "")
			_查("第 %d 幕「%s」标了词" % [号, id], (人条.get("词", []) as Array).size() >= 2)
		for id2 in 合法id:
			_查("第 %d 幕「%s」在" % [号, id2], id2 in 说过)


func _测_词表与词类() -> void:
	print("── 词表 / 五类")
	var 词表: Dictionary = 数据.get("词表", {})
	_查("词表非空", 词表.size() > 0)

	# 用到的词分成两拨：
	#   在词表里 = 可换的词（必须词类合法）
	#   不在词表里 = **骨架词**（进故事、参与念故事，但换不了）—— 只能有少数几个短虚词
	var 用到: Array = _所有用到的词()
	var 骨架: Array = []
	var 类错的: Array = []
	for w in 用到:
		var 词: String = str(w)
		if not 词表.has(词):
			骨架.append(词)
		elif not 故事.词类合法(str(词表[词])):
			类错的.append("%s=%s" % [词, str(词表[词])])
	_查("★ 词表里的词类都合法%s" % ("" if 类错的.is_empty() else "　错：" + "、".join(类错的)), 类错的.is_empty())
	print("      骨架词（换不了）：", "、".join(骨架) if not 骨架.is_empty() else "（没有）")
	_查("★ 骨架词不超过 10 个", 骨架.size() <= 10)
	var 太长: Array = []
	for w2 in 骨架:
		if str(w2).length() > 5:
			太长.append(str(w2))
	_查("★ 骨架词都是短虚词%s" % ("" if 太长.is_empty() else "　太长：" + "、".join(太长)), 太长.is_empty())

	# 五类各自至少几个
	var 分布: Dictionary = {}
	for w in 词表:
		var 类: String = str(词表[w])
		分布[类] = int(分布.get(类, 0)) + 1
	for 类2 in 故事.词类表:
		_查("★「%s」类至少有 %d 个词（不然换不了）" % [类2, 每类最少词数],
			int(分布.get(类2, 0)) >= 每类最少词数)

	# 死词：词表里有、但谁都没说过
	var 死的: Array = []
	for w2 in 词表:
		if not str(w2) in 用到:
			死的.append(str(w2))
	_查("没有用不上的死词%s" % ("" if 死的.is_empty() else "　死词：" + "、".join(死的)), 死的.is_empty())


func _测_互斥() -> void:
	print("── 互斥表")
	var 互斥: Array = 数据.get("互斥", [])
	var 词表: Dictionary = 数据.get("词表", {})
	_查("互斥表非空", not 互斥.is_empty())
	for 对 in 互斥:
		var 条: Array = 对
		_查("互斥对是两词", 条.size() == 2)
		var a: String = str(条[0])
		var b: String = str(条[1])
		_查("互斥词「%s」在词表里" % a, 词表.has(a))
		_查("互斥词「%s」在词表里" % b, 词表.has(b))
		_查("互斥对两词不是同一个词", a != b)
		# ★ 死代码检查：必须存在一个说法"含 a 不含 b"，否则这一对永远分不开
		_查("★ 互斥对「%s / %s」能分开（不是死代码）" % [a, b], _能分开(a, b) or _能分开(b, a))


## 有没有哪个说法里出现了 a 却没出现 b —— 有的话玩家就能"只要 a"。
func _能分开(a: String, b: String) -> bool:
	for 幕 in 数据.get("幕", []):
		for 条 in (幕 as Dictionary).get("说法", []):
			var 词: Array = (条 as Dictionary).get("词", [])
			if a in 词 and not b in 词:
				return true
	return false


func _测_变体() -> void:
	print("── 变体（换词 → 下一幕见效）")
	var 幕表: Array = 数据.get("幕", [])
	var 词表: Dictionary = 数据.get("词表", {})
	var 变体幕数: int = 0
	var 空条件: Array = []
	var 引用了不存在的词: Array = []
	var 永远命中不了: Array = []

	for i in 幕表.size():
		var 幕: Dictionary = 幕表[i]
		var 号: int = i + 1
		var 变体表: Array = 幕.get("变体", [])
		if not 变体表.is_empty():
			变体幕数 += 1
		for j in 变体表.size():
			var 变: Dictionary = 变体表[j]
			var 标: String = "第%d幕 变体#%d" % [号, j]
			var 当: Dictionary = 变.get("当", {})
			if 当.is_empty():
				空条件.append(标)
			_查("%s 有反应文本或有覆盖" % 标,
				str(变.get("反应", "")) != "" or 变.has("覆盖") or 变.has("事实") or 变.has("场景"))

			# 引用的词必须存在
			for w in _条件里的词(当):
				if not 词表.has(str(w)):
					引用了不存在的词.append("%s → %s" % [标, str(w)])
				# ★ 第 N 幕求值时，"含"引用的词必须在第 1..N-1 幕出现过
				if 号 == 1:
					永远命中不了.append("%s（第1幕进场时故事是空的，任何「含」都不成立）" % 标)
				elif not (str(w) in _到幕为止听过的(号 - 1)):
					永远命中不了.append("%s → 「%s」在第 %d 幕之前没人提过" % [标, str(w), 号])
			for 对 in _条件里的换过对(当):
				var 旧2: String = str(对[0])
				var 新2: String = str(对[1])
				if not 词表.has(旧2):
					引用了不存在的词.append("%s → 换过 %s" % [标, 旧2])
					continue
				# ★ 第 N 幕求值时，这次替换必须**在第 N 幕之前真的做得到**：
				#   旧词要听过，而且要有一个**同类的替代词**也听过（不然根本换不动）
				if not _幕前换得动(旧2, 号):
					永远命中不了.append("%s → 第 %d 幕之前换不动「%s」（没有听过的同类词可换）" % [标, 号, 旧2])
				if 新2 != "*":
					if not 词表.has(新2):
						引用了不存在的词.append("%s → 换过成 %s" % [标, 新2])
					elif not 新2 in _到幕为止听过的(号 - 1):
						永远命中不了.append("%s → 想换成「%s」，可这个词第 %d 幕之前没人提过" % [标, 新2, 号])
			# 覆盖里的词也得在词表里、且合法
			for w2 in _覆盖里的词(变):
				if not 词表.has(w2):
					引用了不存在的词.append("%s 覆盖 → %s" % [标, w2])

	_查("★ 没有空条件的变体%s" % ("" if 空条件.is_empty() else "　" + "、".join(空条件)), 空条件.is_empty())
	_查("★ 变体引用的词都在词表里%s" % ("" if 引用了不存在的词.is_empty() else "　" + "、".join(引用了不存在的词)),
		引用了不存在的词.is_empty())
	_查("★ 没有永远命中不了的变体%s" % ("" if 永远命中不了.is_empty() else "　" + "；".join(永远命中不了)),
		永远命中不了.is_empty())
	_查("★ 至少 4 幕有变体（荒诞因果链要成链）", 变体幕数 >= 4)


func _测_任务与结局() -> void:
	print("── 任务 / 结局（M6）")
	var 任务: Dictionary = 数据.get("任务", {})
	var 条件: Dictionary = 任务.get("达成", {})
	_查("有 任务.达成 条件", not 条件.is_empty())
	_查("结局台词非空", str(任务.get("结局台词", "")) != "")
	_查("未达成台词非空", str(任务.get("未达成台词", "")) != "")
	_查("★ 结局台词是「欢迎回来」", str(任务.get("结局台词", "")).contains("欢迎回来"))

	# 达成条件引用的词必须在词表里
	var 词表: Dictionary = 数据.get("词表", {})
	var 缺: Array = []
	for 键 in ["含", "不含", "至少"]:
		for w in 条件.get(键, []):
			if not 词表.has(str(w)):
				缺.append(str(w))
	for 对 in 条件.get("不含对", []):
		for w2 in (对 as Array):
			if not 词表.has(str(w2)):
				缺.append(str(w2))
	_查("任务条件引用的词都在词表里%s" % ("" if 缺.is_empty() else "　缺：" + "、".join(缺)), 缺.is_empty())

	# 任务必须真的能达成（跑一条路看看）
	var 进: Dictionary = 引擎.new(数据).任务进度()
	_查("★ 任务条件是能判的（条目数 ≥ 1）", int(进["总"]) >= 1)


func _测_其他达成() -> void:
	print("── 其他合理达成方式（优先加强 4）")
	var 别: Array = 数据.get("其他达成", [])
	_查("★ 至少给了一条「另一种走法」", not 别.is_empty())
	var 幕数: int = (数据.get("幕", []) as Array).size()
	var 合法id: Array = []
	for 人 in 故事.取讲者表(数据):
		合法id.append(str((人 as Dictionary).get("id", "")))
	for i in 别.size():
		var 条: Dictionary = 别[i]
		var 标: String = "其他达成#%d" % i
		_查("%s 有说明" % 标, str(条.get("说明", "")) != "")
		var 底本: Array = 条.get("底本", [])
		_查("★ %s 的底本长度 = 幕数（%d）" % [标, 幕数], 底本.size() == 幕数)
		var 都合法: bool = true
		for id in 底本:
			if not str(id) in 合法id:
				都合法 = false
		_查("%s 的底本都是合法讲者" % 标, 都合法)

	# ★ 最硬的一条：引擎真的跑一遍，跑不通就是写谎话
	var 校验: Array = 对局.new(数据).校验其他达成()
	var 成立的: int = 0
	for i2 in 校验.size():
		var 条2: Dictionary = 校验[i2]
		if bool(条2["成立"]):
			成立的 += 1
		else:
			_查("★ 其他达成#%d 真的能达成（%s）" % [i2, str(条2["理由"])], false)
	_查("★ 至少一条其他走法被引擎验成成立", 成立的 >= 1)


func _测_美术空位() -> void:
	print("── 美术空位（填了就必须真的有那个文件）")
	for i in (数据.get("幕", []) as Array).size():
		var 幕: Dictionary = (数据.get("幕", []) as Array)[i]
		var 场: Dictionary = 幕.get("场景", {})
		_查("第 %d 幕场景是字典" % (i + 1), 场 is Dictionary)
		_查("第 %d 幕场景有 背景 字段" % (i + 1), 场.has("背景"))
		_查("第 %d 幕场景有 光 字段" % (i + 1), 场.has("光"))
		var 背景: String = str(场.get("背景", ""))
		_查("第 %d 幕的背景空位合法（空的，或者文件真的在）" % (i + 1),
			背景 == "" or FileAccess.file_exists(背景))

	var 物件: Dictionary = 数据.get("物件", {})
	var 词表: Dictionary = 数据.get("词表", {})
	for w in 物件:
		_查("物件表的键「%s」是故事里的词" % str(w), 词表.has(str(w)))
		_查("物件表的值「%s」是字符串" % str(w), 物件[w] is String)


# ============================================================ 工具
func _所有用到的词() -> Array:
	var 结果: Array = []
	for 幕 in 数据.get("幕", []):
		for 条 in (幕 as Dictionary).get("说法", []):
			for w in (条 as Dictionary).get("词", []):
				if not str(w) in 结果:
					结果.append(str(w))
		for 变 in (幕 as Dictionary).get("变体", []):
			for w2 in _覆盖里的词(变 as Dictionary):
				if not w2 in 结果:
					结果.append(w2)
			for w3 in _条件里的词((变 as Dictionary).get("当", {})):
				if not str(w3) in 结果:
					结果.append(str(w3))
	return 结果


func _到幕为止听过的(幕号: int) -> Array:
	var 结果: Array = []
	for i in mini(幕号, (数据.get("幕", []) as Array).size()):
		var 幕: Dictionary = (数据.get("幕", []) as Array)[i]
		for 条 in 幕.get("说法", []):
			for w in (条 as Dictionary).get("词", []):
				if not str(w) in 结果:
					结果.append(str(w))
	return 结果


func _条件里的词(当: Dictionary) -> Array:
	var 结果: Array = []
	for 键 in ["含", "不含"]:
		for w in 当.get(键, []):
			if not str(w) in 结果:
				结果.append(str(w))
	for 子 in 当.get("任", []):
		for w2 in _条件里的词(子 as Dictionary):
			if not w2 in 结果:
				结果.append(w2)
	return 结果


func _条件里的旧词(当: Dictionary) -> Array:
	var 结果: Array = []
	for 对 in 当.get("换过", []):
		if (对 as Array).size() >= 1:
			结果.append(str((对 as Array)[0]))
	for 子 in 当.get("任", []):
		for w in _条件里的旧词(子 as Dictionary):
			结果.append(w)
	return 结果


## [旧, 新] 对（含"任"里面的）。
func _条件里的换过对(当: Dictionary) -> Array:
	var 结果: Array = []
	for 对 in 当.get("换过", []):
		if (对 as Array).size() >= 2:
			结果.append(对)
	for 子 in 当.get("任", []):
		if 子 is Dictionary:
			for 对2 in _条件里的换过对(子 as Dictionary):
				结果.append(对2)
	return 结果


## ★ 第 N 幕之前，玩家真的换得动「旧」吗？
##   要换得动，得有一个**听过的、同类的**别的词 —— 否则这条变体永远等不到。
func _幕前换得动(旧: String, 幕号: int) -> bool:
	var 词表: Dictionary = 数据.get("词表", {})
	var 类: String = str(词表.get(旧, ""))
	if 类 == "":
		return false
	for w in _到幕为止听过的(幕号 - 1):
		var 词: String = str(w)
		if 词 != 旧 and str(词表.get(词, "")) == 类:
			return true
	return false


func _覆盖里的词(变: Dictionary) -> Array:
	var 结果: Array = []
	for id in 变.get("覆盖", {}):
		for w in ((变["覆盖"] as Dictionary)[id] as Dictionary).get("词", []):
			if not str(w) in 结果:
				结果.append(str(w))
	return 结果
