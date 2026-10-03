## 试跑剧本 —— 不开游戏，按一条真实打法走完七幕，把结算念出来。
##
## 跑法：
##   godot --headless --path <项目> --script res://脚本/测试/试跑剧本.gd
##
## ★ 这个是**给写剧本的人用的**，不是自检：
##   自检验的是"对不对"，这个看的是"读起来像不像话"。
##   写完一个新故事，先跑这个，把因果链和念出来的故事读一遍。
##
## 想试别的打法：改下面 `走法` 那张表（每幕选谁、要不要换一个词）。
extends SceneTree

const 故事路径: String = "res://脚本/数据/故事_第一案.gd"

## 一条"人会这么玩"的路：第 1 幕改地点，第 2 幕把人换成他妈，第 3 幕留下那句话。
const 走法: Array = [
	{"人": "tong", "换": ["在巷口", "在校门口"]},
	{"人": "ma", "换": ["他", "他妈"]},
	{"人": "tong", "换": []},
	{"人": "tong", "换": []},
	{"人": "tong", "换": []},
	{"人": "k", "换": []},
	{"人": "ma", "换": []},
]


func _initialize() -> void:
	var 脚本: Variant = load(故事路径)
	if 脚本 == null or not (脚本 is GDScript):
		print("读不到故事：", 故事路径)
		quit(1)
		return
	var 表: Dictionary = (脚本 as GDScript).get_script_constant_map()
	var 数据: Dictionary = 表.get("数据", {})

	var 局: 对局 = 对局.new(数据)
	print("")
	print("════════ 试跑：", str(数据.get("名", "")), " ════════")
	print("身份：", str(数据.get("身份", "")).replace("\n", " "))
	print("任务：", str(数据.get("任务说明", "")))
	print("")

	for i in mini(走法.size(), 局.总幕数()):
		var 步: Dictionary = 走法[i]
		var 选: Dictionary = 局.选底本(str(步["人"]))
		if not bool(选["ok"]):
			print("  [第 %d 幕] 选底本失败：%s" % [局.幕, str(选["提示"])])
		var 换: Array = 步["换"]
		if not 换.is_empty():
			局.选词(str(换[0]))
			var 果: Dictionary = 局.换词(str(换[0]), str(换[1]))
			if not bool(果["ok"]):
				print("  [第 %d 幕] 换词失败：%s" % [局.幕, str(果["提示"])])
		局.下一幕()

	var 结: Dictionary = 局.取结算()

	print("── 念出来的故事 ──")
	for 行 in 结["行"]:
		print("   ", str(行))

	print("")
	print("── 因果链（改写的后果）──")
	for 一 in 结["因果链"]:
		var 条: Dictionary = 一
		print("   第 %d 幕　因为%s" % [int(条["幕"]), "，".join(条["因为"] as Array)])
		print("            所以：%s" % str(条["所以"]))

	print("")
	print("── 你动过的手 ──")
	for 一 in 结["词改变"]:
		var 条2: Dictionary = 一
		print("   第 %d 幕　「%s」→「%s」（%s，%d 处）" % [
			int(条2["幕"]), str(条2["旧"]), str(条2["新"]), str(条2["类"]), int(条2["处"])])

	print("")
	print("任务达成：", 结["达成"])
	print("结局台词：", str(结["台词"]))

	print("")
	print("── 同一件事的其他走法 ──")
	for 一 in 结["其他版本"]:
		var 条3: Dictionary = 一
		print("   %s　%s" % [
			"✔ 成立" if bool(条3["成立"]) else "✘ 不成立：" + str(条3["理由"]),
			str(条3["说明"]),
		])
		if bool(条3["成立"]):
			for 行2 in (条3["行"] as Array):
				print("        " + str(行2))

	print("")
	print("════════ 试跑结束 ════════")
	quit()
