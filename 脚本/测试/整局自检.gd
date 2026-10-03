## 整局自检 —— 不开界面，把一局真的打完。
##
## 跑法：
##   godot --headless --path <项目> --script res://脚本/测试/整局自检.gd
##
## 这个脚本管三件事：
##   ① 流程层有没有把引擎用对（七幕推进 / 草稿 / 锚定 / 结算）
##   ② ★ 可复现：同一份重放记录跑两遍，结果必须逐字相同（v3 §6）
##   ③ 主场景真的能起来（界面 / 交互 / 美术 / 调试四层接得上，不报错）
##
## 退出码 0 = 全过。
extends SceneTree

const 故事路径: String = "res://脚本/数据/故事_第一案.gd"
const 主场景: String = "res://场景/主.tscn"

var _通过: int = 0
var _失败: int = 0
var 数据: Dictionary = {}


func _initialize() -> void:
	print("")
	print("════════ 欢迎回来 · 整局自检 ════════")
	数据 = _读故事()
	if 数据.is_empty():
		print("  [XX] 读不到故事数据")
		_失败 += 1
	else:
		await _跑()
	print("")
	print("════════ 通过 %d · 失败 %d ════════" % [_通过, _失败])
	print("")
	quit(1 if _失败 > 0 else 0)


func _读故事() -> Dictionary:
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


func _新局() -> 对局:
	return 对局.new(数据)


# ============================================================
func _跑() -> void:
	_测_七幕跑通()
	_测_达成与未达成()
	_测_草稿与每幕限制()
	_测_重放可复现()
	_测_调试接口()
	await _测_主场景()


func _测_七幕跑通() -> void:
	print("── 七幕跑通（M1）")
	# ★ 正确用法：先 new() 空局、先接信号，再 载入()。
	#   （对局.new(数据) 会在构造时就发第 1 幕的信号，那时候还没人听得见。）
	var 局: 对局 = 对局.new()
	# ⚠️ GDScript 的 lambda 是**按值捕获**的：捕获一个 int 改它，外面看不见。
	#    所以计数用数组（引用类型）接。
	var 计: Array = [0]
	局.换幕.connect(func(_a, _b, _c): 计[0] = int(计[0]) + 1)
	局.载入(数据)

	var 总: int = 局.总幕数()
	_查("总幕数 ≥ 1", 总 >= 1)
	_查("开局在第 1 幕", 局.幕 == 1)
	_查("开局没完", not 局.完了)
	_查("载入就发了第 1 幕的信号", int(计[0]) == 1)

	var 步: int = 0
	while not 局.完了 and 步 < 40:
		步 += 1
		var 状态: Dictionary = 局.取状态()
		var 讲者: Array = 状态["讲者"]
		var 底本: String = str((讲者[(步 - 1) % 讲者.size()] as Dictionary)["id"])
		var 选: Dictionary = 局.选底本(底本)
		_查("第 %d 幕能选底本" % 局.幕, bool(选["ok"]))
		_查("第 %d 幕句数 = 幕号" % 局.幕, 局.引擎.句数() == 局.幕)
		局.下一幕()

	_查("★ 走到完了", 局.完了)
	_查("步数 = 幕数", 步 == 总)
	_查("故事句数 = 幕数", 局.引擎.句数() == 总)
	_查("每幕都发过换幕信号", int(计[0]) == 总)
	_查("底本表长度 = 幕数", 局.底本表.size() == 总)

	var 结: Dictionary = 局.取结算()
	_查("结算有 行", (结["行"] as Array).size() == 总)
	_查("结算有 任务", not (结["任务"] as Dictionary).is_empty())
	_查("结算有 台词", str(结["台词"]) != "")
	_查("结算有 因果链", 结.has("因果链"))
	_查("结算有 词改变", 结.has("词改变"))
	_查("结算有 其他版本", 结.has("其他版本"))
	_查("结算有 重放", not (结["重放"] as Dictionary).is_empty())
	_查("结算有 达成 布尔", 结["达成"] is bool)
	_查("每句都带讲者名", str((结["故事"] as Array)[0]["讲者名"]) != "")


func _测_达成与未达成() -> void:
	print("── 达成 / 未达成")
	# ① 强制达成 → 走锚定
	var 局A: 对局 = _新局()
	局A.强制达成(true)
	var 锚: Array = []
	局A.锚定.connect(func(_r): 锚.append(1))
	while not 局A.完了:
		var 讲: Array = 局A.取状态()["讲者"]
		局A.选底本(str((讲[0] as Dictionary)["id"]))
		局A.下一幕()
	_查("★ 强制达成 → 发了锚定信号", 锚.size() == 1)
	_查("强制达成的结算说达成", bool(局A.取结算()["达成"]))
	_查("锚定结果里有台词", str(局A.锚定结果.get("台词", "")) != "")

	# ② 完全不改 → 走未达成或达成（两种都合法，只要信号对得上）
	var 局B: 对局 = _新局()
	var 未达: Array = []
	var 达: Array = []
	局B.未达成.connect(func(_r): 未达.append(1))
	局B.锚定.connect(func(_r): 达.append(1))
	while not 局B.完了:
		var 讲2: Array = 局B.取状态()["讲者"]
		局B.选底本(str((讲2[3] as Dictionary)["id"]))
		局B.下一幕()
	var 结B: Dictionary = 局B.取结算()
	_查("★ 收束时二选一发了信号", 未达.size() + 达.size() == 1)
	_查("信号与结算的 达成 一致", (达.size() == 1) == bool(结B["达成"]))
	_查("台词取到了", str(结B["台词"]) != "")

	# ③ 抽掉任务词 → 一定未达成
	var 局C: 对局 = _新局()
	var 关键: Array = (数据.get("任务", {}) as Dictionary).get("达成", {}).get("含", [])
	if not 关键.is_empty():
		while not 局C.完了:
			var 讲3: Array = 局C.取状态()["讲者"]
			# 挑一个说法最少、最不可能带关键字的
			局C.选底本(str((讲3[1] as Dictionary)["id"]))
			局C.下一幕()
		var 有全部: bool = true
		for w in 关键:
			if not 局C.引擎.在故事里(str(w)):
				有全部 = false
		_查("★ 缺了关键任务词的局 → 未达成", (not 有全部) == (not bool(局C.取结算()["达成"])))


func _测_草稿与每幕限制() -> void:
	print("── 草稿 / 每幕一次 / 撤销")
	var 局: 对局 = _新局()
	var 讲者: Array = 局.取状态()["讲者"]
	局.选底本(str((讲者[0] as Dictionary)["id"]))

	# 找一个"故事里能换的词"
	var 状态: Dictionary = 局.取状态()
	var 换成功: bool = false
	var 旧词: String = ""
	var 新词: String = ""
	if (状态["故事"] as Array).size() > 0:
		var 词表: Array = (状态["故事"] as Array)[0]["词"]
		for 词条 in 词表:
			局.选词(str((词条 as Dictionary)["词"]))
			var 候: Array = 局.取状态()["候选"]
			for 条 in 候:
				if bool((条 as Dictionary)["能换"]):
					旧词 = str((词条 as Dictionary)["词"])
					新词 = str((条 as Dictionary)["词"])
					换成功 = bool(局.换词(旧词, 新词)["ok"])
					break
			if 换成功:
				break

	_查("★ 第 1 幕就能换一个同类词（候选池够用）", 换成功)
	if 换成功:
		_查("换过之后标记了草稿", 局.草稿有)
		_查("替换记录 +1", 局.引擎.替换记录.size() == 1)
		_查("词真的换了", 局.引擎.在故事里(新词) and not 局.引擎.在故事里(旧词))

		# 每幕一次的限制
		var 再换: Dictionary = 局.换词(新词, 旧词)
		_查("★ 每幕只能改一次（主题.每幕替换次数=1）",
			not bool(再换["ok"]) or 主题.每幕替换次数 != 1)

		# 撤销
		var 撤: Dictionary = 局.撤销()
		_查("撤销成功", bool(撤["ok"]))
		_查("★ 撤销后词回来了", 局.引擎.在故事里(旧词))
		_查("撤销后记录清空", 局.引擎.替换记录.is_empty())
		_查("撤销后草稿标记没了", not 局.草稿有)
		_查("撤销后又能改了", bool(局.换词(旧词, 新词)["ok"]))

	# 撤销没得撤的时候
	局 = _新局()
	_查("没动过手时撤销被拒", not bool(局.撤销()["ok"]))

	# 没选底本时的拒绝
	局 = _新局()
	_查("选一个不在故事里的词被拒", not bool(局.选词("这个字不在故事里")["ok"]))
	_查("没选底本时选词被拒", not bool(局.选词(str(_第一个词()))["ok"]) or 局.选中词 == "")
	var 状态2: Dictionary = 局.取状态()
	_查("可以.下一幕 在没选底本时是 false", not bool((状态2["可以"] as Dictionary)["下一幕"]))
	_查("没选底本时下一幕被拒", not bool(局.下一幕()["ok"]))

	# 选底本可以取消
	var 讲者2: Array = 状态2["讲者"]
	局.选底本(str((讲者2[0] as Dictionary)["id"]))
	_查("选了之后句数 = 1", 局.引擎.句数() == 1)
	局.选底本(str((讲者2[0] as Dictionary)["id"]))
	_查("再点一次 = 取消，句数回 0", 局.引擎.句数() == 0)

	# 换说法要能换干净
	局.选底本(str((讲者2[0] as Dictionary)["id"]))
	局.选底本(str((讲者2[1] as Dictionary)["id"]))
	_查("换人之后句数还是 1", 局.引擎.句数() == 1)
	_查("换人之后底本是第二个人", 局.选中底本 == str((讲者2[1] as Dictionary)["id"]))


func _测_重放可复现() -> void:
	print("── ★ 可复现（M4）")
	var 局: 对局 = _新局()
	# 走一条改过词的局
	var 改过: bool = false
	while not 局.完了:
		var 讲者: Array = 局.取状态()["讲者"]
		局.选底本(str((讲者[1] as Dictionary)["id"]))
		if not 改过:
			var 故事: Array = 局.取状态()["故事"]
			if (故事 as Array).size() > 0:
				for 词条 in ((故事 as Array)[-1] as Dictionary)["词"]:
					var 旧: String = str((词条 as Dictionary)["词"])
					局.选词(旧)
					for 条 in 局.取状态()["候选"]:
						if bool((条 as Dictionary)["能换"]):
							改过 = bool(局.换词(旧, str((条 as Dictionary)["词"]))["ok"])
							break
					if 改过:
						break
		局.下一幕()

	var 记录: Dictionary = 局.取重放()
	_查("重放记录有底本", (记录["底本"] as Array).size() == 局.总幕数())
	_查("重放记录带版本号", int(记录["版本"]) >= 1)
	_查("重放记录带故事 id", str(记录["故事"]) != "")
	var 第一次: String = _指纹(局.取结算())

	var 局2: 对局 = _新局()
	var 跑通: bool = 局2.从重放(记录)
	_查("★ 重放能跑到底", 跑通)
	var 第二次: String = _指纹(局2.取结算())
	_查("★ 两次结算逐字相同", 第一次 == 第二次)
	if 第一次 != 第二次:
		print("      第一次：", 第一次)
		print("      第二次：", 第二次)

	# 再跑一遍，还是同一份
	var 局3: 对局 = _新局()
	局3.从重放(记录)
	_查("★ 第三次也逐字相同", _指纹(局3.取结算()) == 第一次)

	# 因果链也要一致
	_查("★ 因果链一致", JSON.stringify(局2.取结算()["因果链"]) == JSON.stringify(局.取结算()["因果链"]))


func _指纹(结: Dictionary) -> String:
	return JSON.stringify({
		"行": 结["行"], "因果链": 结["因果链"],
		"词改变": 结["词改变"], "达成": 结["达成"], "台词": 结["台词"],
	})


func _测_调试接口() -> void:
	print("── 调试接口（R1）")
	var 局: 对局 = _新局()
	_查("取重放不炸", not (局.取重放() as Dictionary).is_empty())

	var 跳: Dictionary = 局.跳幕(4)
	_查("跳幕成功", bool(跳["ok"]))
	_查("★ 跳到第 4 幕", 局.幕 == 4)
	_查("跳幕之后故事是完整的（前 3 幕铺好了）", 局.引擎.句数() == 3)
	_查("跳幕之后还能继续玩", not 局.完了)

	局.强制达成(true)
	_查("强制达成在状态里看得见", bool(局.取状态()["任务"]["达成"]))
	局.强制达成(false)
	_查("关掉强制达成", not bool(局.取状态()["任务"]["达成"]))

	# 跳幕之后重放仍然自洽
	var 记: Dictionary = 局.取重放()
	_查("跳幕后的重放底本长度 = 幕数-1", (记["底本"] as Array).size() == 局.幕 - 1)

	# 跳幕会重来，所以从第 2 幕重新数
	var 局2: 对局 = _新局()
	局2.跳幕(2)
	_查("跳幕 2 → 第 2 幕", 局2.幕 == 2)
	局2.跳幕(1)
	_查("跳回第 1 幕", 局2.幕 == 1)
	_查("跳回第 1 幕后故事是空的", 局2.引擎.句数() == 0)


# ============================================================ 主场景
## 真的把 主.tscn 实例化出来 —— 验四层接得上、不报错。
func _测_主场景() -> void:
	print("── 主场景（界面 / 交互 / 美术 / 调试）")
	var 场景: PackedScene = load(主场景) as PackedScene
	_查("主场景加载得到", 场景 != null)
	if 场景 == null:
		return

	var 实例: Node = 场景.instantiate()
	_查("主场景实例化得到", 实例 != null)
	root.add_child(实例)
	await process_frame
	await process_frame

	var 主脚本: Node = 实例
	var 局: Variant = 主脚本.get("局")
	_查("★ 主场景里建起了 局", 局 != null and 局 is 对局)
	if 局 == null:
		_收场(实例)
		return
	var 局2: 对局 = 局
	_查("主场景里对局已经进到第 1 幕", 局2.幕 == 1)
	_查("主场景里故事数据加载成功", not 局2.数据.is_empty())

	var 界面节点: Node = 实例.get_node_or_null("%界面")
	_查("找得到 %界面", 界面节点 != null)
	if 界面节点 != null:
		_查("界面接上了局", 界面节点.get("局") == 局2)
		_查("界面搭起了控件（有子节点）", 界面节点.get_child_count() > 0)
		for 名 in ["点了讲者", "点了故事词", "点了候选", "点了撤销", "点了下一幕", "点了重来"]:
			_查("界面提供信号 %s" % 名, 界面节点.has_signal(名))

	var 交互层: Node = 实例.get_node_or_null("%交互层")
	_查("找得到 %交互层", 交互层 != null)
	if 交互层 != null:
		_查("交互层是 交互 的实现", 交互层 is 交互)
		_查("交互层拿得到局", 交互层.get("局") == 局2)
		_查("交互层拿得到界面", 交互层.get("界面") == 界面节点)

	var 调试层: Node = 实例.get_node_or_null("%调试层")
	_查("找得到 %调试层", 调试层 != null)
	if 调试层 != null:
		_查("调试层默认是关的", not bool(调试层.call("开着")))
		调试层.call("切换", true)
		_查("调试层能打开", bool(调试层.call("开着")))
		var 打印文本: String = str(调试层.call("取文本"))
		_查("★ 调试面板有内容", 打印文本.length() > 200)
		_查("调试面板显示任务", 打印文本.contains("任务"))
		_查("调试面板显示故事", 打印文本.contains("故事"))
		_查("调试面板显示重放记录", 打印文本.contains("重放记录"))
		调试层.call("切换", false)

	var 美术: Variant = 主脚本.get("美术")
	_查("主场景建起了 美术接口", 美术 != null)
	_查("美术接口挂上了垫底背景", 实例.get_node_or_null("%现场层").get_child_count() >= 1)

	# 走一遍：选底本 → 下一幕（用界面信号那条路，等于模拟玩家点击）
	if 界面节点 != null:
		var 讲者: Array = 局2.取状态()["讲者"]
		界面节点.emit_signal("点了讲者", str((讲者[0] as Dictionary)["id"]))
		await process_frame
		_查("★ 点讲者 → 故事多了一句（界面→交互→对局 这条线通了）", 局2.引擎.句数() == 1)
		界面节点.emit_signal("点了下一幕")
		await process_frame
		_查("★ 点下一幕 → 真的进了第 2 幕", 局2.幕 == 2)

	# 界面关掉之后，规则层照样跑（旧版这里是个坑：关掉界面整个游戏就死了）
	_收场(实例)
	var 实例2: Node = 场景.instantiate()
	var 界面2: Node = 实例2.get_node("%界面")
	界面2.set("搭界面", false)
	root.add_child(实例2)
	await process_frame
	await process_frame
	var 局3: Variant = 实例2.get("局")
	_查("★ 关掉界面之后 局 照样建起来了", 局3 != null)
	if 局3 != null:
		var 讲者3: Array = (局3 as 对局).取状态()["讲者"]
		_查("★ 关掉界面之后照样能玩", bool((局3 as 对局).选底本(str((讲者3[0] as Dictionary)["id"]))["ok"]))
	var 调试3: Node = 实例2.get_node_or_null("%调试层")
	_查("★ 关掉界面之后调试还能用", 调试3 != null and bool(调试3.call("开着")) == false)
	_收场(实例2)


func _收场(实例: Node) -> void:
	root.remove_child(实例)
	实例.queue_free()


## 取第一个讲述者说过的第一个词（给"还没选底本"那几条用）。
func _第一个词() -> String:
	for 人 in 故事.取讲者表(数据):
		var id: String = str((人 as Dictionary)["id"])
		var 幕: Dictionary = 故事.取幕(数据, 1)
		var 说: Dictionary = 故事.取说法(幕, id)
		var 词: Array = 说.get("词", [])
		if not 词.is_empty():
			return str(词[0])
	return ""
