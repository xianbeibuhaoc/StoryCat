## 剧本自检 —— 验证《口径》第一案的数据立得住，并模拟整局跑通。
##
## 跑法：
##   Godot_v4.4-stable_win64_console.exe --headless --path . --script res://脚本/测试/剧本自检.gd
##
## 数据出错比代码出错更贵：写错一个词的互斥配对，那一局就永远触发不了矛盾，
## 而你不会知道。这个脚本就是为了让这种错当场炸出来。
extends SceneTree

const 引擎 := preload("res://脚本/系统/口径.gd")

var _通过: int = 0
var _失败: int = 0


func _ok(名: String, 条件: bool, 补充: String = "") -> void:
	if 条件:
		_通过 += 1
		print("  [OK] ", 名)
	else:
		_失败 += 1
		print("  [XX] ", 名, "　← 实际：", 补充)


func _组(名: String) -> void:
	print("")
	print("── ", 名)


func _initialize() -> void:
	print("")
	print("════════ 口径 · 剧本自检（第一案「那个人」）════════")

	_测_结构()
	_测_赌注()
	_测_互斥()
	_测_回响()
	_看_手牌()
	_测_对局_救了那句()
	_测_对局_没救那句()

	print("")
	print("════════ 通过 %d · 失败 %d ════════" % [_通过, _失败])
	print("")
	quit(1 if _失败 > 0 else 0)


# ============================================================ 1. 结构
func _测_结构() -> void:
	_组("① 每一幕：四个人都开口了，而且都带着词")

	var 幕数: int = 口径词表.幕表.size()
	_ok("一共七幕", 幕数 == 7, str(幕数))

	var 缺: Array = []
	for i in 幕数:
		var 幕: Dictionary = 口径词表.取幕(i + 1)
		if str(幕.get("名", "")) == "":
			缺.append("第%d幕缺幕名" % (i + 1))
		if str(幕.get("事实", "")) == "":
			缺.append("第%d幕缺「事实」" % (i + 1))
		for 人 in 口径词表.讲述者:
			var id: String = str(人.get("id", ""))
			var 条: Dictionary = 幕.get(id, {})
			if str(条.get("文", "")) == "":
				缺.append("第%d幕 %s 没台词" % [i + 1, id])
			if (条.get("词", []) as Array).is_empty():
				缺.append("第%d幕 %s 没标词" % [i + 1, id])
	_ok("四个人七幕全齐", 缺.is_empty(), str(缺))

	# 手牌去重后不该有重复串
	for i in 幕数:
		var 手: Array = 口径词表.手牌(i + 1)
		var 去重: Array = []
		for w in 手:
			if not w in 去重:
				去重.append(w)
		_ok("第%d幕手牌无重复（%d 张）" % [i + 1, 手.size()], 手.size() == 去重.size(), str(手))


# ============================================================ 2. 赌注
func _测_赌注() -> void:
	_组("② 赌注成立：「欢迎回来」必须是孤证，而且必须只有一处")

	var 出现幕: Array = []
	var 说的人: Array = []
	for i in 口径词表.幕表.size():
		var 谁: Array = 口径词表.谁说过(i + 1, 口径词表.结尾词)
		if not 谁.is_empty():
			出现幕.append(i + 1)
			说的人.append_array(谁)

	_ok("「%s」在剧本里出现过" % 口径词表.结尾词, not 出现幕.is_empty(), str(出现幕))
	_ok("★ 只有一个人说过它 —— 孤证成立", 说的人.size() <= 1, str(说的人))
	_ok("★ 它只在第 3 幕出现一次（最脆的那句话）", 出现幕 == [3], str(出现幕))
	print("      → 它由「%s」说出，1 个证人。" % (说的人[0] if not 说的人.is_empty() else "?"))

	# 跨幕复用的词 —— 全局替换的演示点
	var 跨幕: Array = []
	var 计数: Dictionary = {}
	for i in 口径词表.幕表.size():
		for w in 口径词表.手牌(i + 1):
			计数[w] = int(计数.get(w, 0)) + 1
	for w in 计数:
		if int(计数[w]) > 1:
			跨幕.append("%s×%d" % [w, 计数[w]])
	_ok("有词跨幕复用（换一处、改一片）", not 跨幕.is_empty(), str(跨幕))
	print("      → 跨幕词：", "、".join(跨幕))


# ============================================================ 3. 互斥
func _测_互斥() -> void:
	_组("③ 互斥词对：每一个词都真的在剧本里存在")

	var 全部: Dictionary = {}
	for i in 口径词表.幕表.size():
		for w in 口径词表.手牌(i + 1):
			全部[str(w)] = true

	var 找不到: Array = []
	for 对 in 口径词表.互斥:
		for w in 对:
			if not 全部.has(str(w)):
				找不到.append(str(w))
	_ok("互斥词对里没有写错的词", 找不到.is_empty(), "剧本里找不到：" + str(找不到))

	# ★ 真正该守的规则：每一对的两个词，必须能从**不同的两幕**分别选进来。
	#   同一幕四个版本互斥，玩家只选一句 —— 同幕配对是死代码，永远触发不了。
	var 死对: Array = []
	var 明细: Array = []
	for 对 in 口径词表.互斥:
		var a: String = str(对[0])
		var b: String = str(对[1])
		var a幕: Array = _出处(a)
		var b幕: Array = _出处(b)
		var 可达: bool = false
		for i in a幕:
			for j in b幕:
				if int(i) != int(j):
					可达 = true
		if 可达:
			明细.append("%s×%s" % [a, b])
		else:
			死对.append("%s×%s（都只在第 %s 幕）" % [a, b, str(a幕)])
	_ok("每一对都能被玩出来（跨幕可达）", 死对.is_empty(),
		"永远触发不了的死对：" + str(死对))
	print("      → 可达的打架组合：", "、".join(明细))


## 一个词在第几幕的手牌里。
func _出处(词: String) -> Array:
	var 结果: Array = []
	for i in 口径词表.幕表.size():
		if 词 in 口径词表.手牌(i + 1):
			结果.append(i + 1)
	return 结果


# ============================================================ 4. 回响
func _测_回响() -> void:
	_组("④ 回响模板：每个人承、顶都有，且都带 {词} 占位")

	var 缺: Array = []
	for 人 in 口径词表.讲述者:
		var id: String = str(人.get("id", ""))
		var 表: Dictionary = 口径词表.回响.get(id, {})
		if 表.is_empty():
			缺.append("%s 没有回响表" % id)
			continue
		for 态 in ["承", "顶"]:
			var 池: Array = 表.get(态, [])
			if 池.is_empty():
				缺.append("%s 缺「%s」" % [id, 态])
			for 句 in 池:
				if not "{词}" in str(句):
					缺.append("%s 的「%s」里没写 {词}" % [id, str(句)])
	_ok("四个人的承/顶都齐", 缺.is_empty(), str(缺))

	# 占位真的会被替换掉
	var 句: String = 口径词表.取回响("k", "欢迎回来", true)
	_ok("取回响会把 {词} 换掉", 句 != "" and "欢迎回来" in 句, 句)


# ============================================================ 5. 手牌（人眼看）
func _看_手牌() -> void:
	_组("⑤ 每一幕的手牌（人眼过一遍：任意两个词对调，句子读得通吗）")
	for i in 口径词表.幕表.size():
		print("")
		print("  第 %d 幕 · %s" % [i + 1, str(口径词表.取幕(i + 1).get("名", ""))])
		print("    %s" % str(口径词表.取幕(i + 1).get("事实", "")))
		for 人 in 口径词表.讲述者:
			var id: String = str(人.get("id", ""))
			var 条: Dictionary = 口径词表.取幕(i + 1).get(id, {})
			print("    [%s] %s" % [str(人.get("名字", id)), str(条.get("文", ""))])
			print("         词：%s" % "／".join(条.get("词", [])))


# ============================================================ 6. 对局模拟（救了那句）
## 策略：每一幕挑说得最多的那个人的说法，然后把「欢迎回来」说出口。
func _测_对局_救了那句() -> void:
	_组("⑥ 整局模拟 A：每幕选「同桌」的说法，第 3 幕把「欢迎回来」说出口")

	var 结果: Dictionary = _跑一局(true)
	_ok("七幕走完了", int(结果["幕"]) == 7, str(结果["幕"]))
	_ok("★ 最后「%s」还活着" % 口径词表.结尾词,
		int(结果["结尾档"]) != 口径.档_哑, "档位=%d 清晰度=%.2f" % [int(结果["结尾档"]), float(结果["结尾清晰"])])
	_ok("故事念得出来", (结果["行"] as Array).size() == 7, str((结果["行"] as Array).size()))
	print("")
	_打印故事(结果)


# ============================================================ 7. 对局模拟（没救）
func _测_对局_没救那句() -> void:
	_组("⑦ 整局模拟 B：同样选法，但从不说出口 —— 那句会没")

	var 结果: Dictionary = _跑一局(false)
	_ok("★ 最后「%s」哑了" % 口径词表.结尾词,
		int(结果["结尾档"]) == 口径.档_哑,
		"档位=%d 清晰度=%.2f" % [int(结果["结尾档"]), float(结果["结尾清晰"])])
	_ok("★ 但故事没有崩 —— 那句话划掉了，位置还在",
		(结果["行"] as Array).size() == 7, str((结果["行"] as Array).size()))
	print("")
	_打印故事(结果)


func _跑一局(救那句: bool) -> Dictionary:
	var e: 口径 = 引擎.new()
	var 幕数: int = 口径词表.幕表.size()

	for i in 幕数:
		var 幕号: int = i + 1
		# ① 记账：四个人说的话你全听见了（哪怕你只选一句）
		for 人 in 口径词表.讲述者:
			var id: String = str(人.get("id", ""))
			var 条: Dictionary = 口径词表.取幕(幕号).get(id, {})
			e.记账(id, 条.get("词", []))

		# ② 选一个人的说法进故事
		e.追加句子(口径词表.取幕(幕号).get("tong", {}).get("词", []))

		# ③ 说出口
		if 救那句 and 幕号 == 3:
			e.说出口(口径词表.结尾词)
			# 下一幕别人跟着说 —— 这是引擎外的规则，模拟时手写
			e.他也说了("k", 口径词表.结尾词)
			e.他也说了("ma", 口径词表.结尾词)

		e.流逝()

	return {
		"幕": 幕数,
		"行": e.取故事文本(),
		"结尾档": e.取档(口径词表.结尾词),
		"结尾清晰": e.取清晰(口径词表.结尾词),
		"缝合度": e.缝合度(),
		"统计": e.统计(),
		"矛盾": e.查矛盾(口径词表.互斥),
		"引擎": e,
	}


func _打印故事(结果: Dictionary) -> void:
	print("      ┌─ 念出来的故事 ─────────────")
	for 行 in 结果["行"]:
		print("      │ ", str(行))
	print("      ├────────────────────────────")
	print("      │ 缝合度 %.2f　分档 %s" % [float(结果["缝合度"]), str(结果["统计"])])
	var 矛: Array = 结果["矛盾"]
	if 矛.is_empty():
		print("      │ 没有矛盾")
	else:
		print("      │ 矛盾 ", str(矛))
	if int(结果["结尾档"]) == 口径.档_哑:
		print("      │ 最后一句：「%s」—— 没了。" % 口径词表.结尾词)
	else:
		print("      │ 最后一句：「%s。」" % 口径词表.结尾词)
	print("      └────────────────────────────")
