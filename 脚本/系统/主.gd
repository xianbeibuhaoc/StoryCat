## 主 —— **把四层接起来。** 整个游戏只有这一个地方知道全部四层的存在。
##
## ============================================================
##   ┌─ 局（对局.gd）          规则和状态。不认得任何节点
##   ├─ 界面（%界面）          订阅 局，画；报出"玩家碰了什么"
##   ├─ 交互（%交互层）        把"碰了什么"翻译成 局 的语义动作
##   ├─ 美术（美术接口.gd）    把 局的信号变成画面
##   └─ 调试（%调试层）        F1 叠层
##
## ★ 换故事 = 改下面那个 `故事路径`（或者把它接到选关界面上）。
##   引擎、界面、交互、美术**一个字都不用动** —— v3 §11 的硬约束。
##
## ★ 想换交互：把 `%交互层` 节点的脚本换掉就行，这里不用改。
## ★ 想换界面：把 `%界面` 节点的脚本换掉（它只要提供 接上() / 刷新() 和那六个信号）。
## ★ 想把界面整个关掉：取消勾选 界面 节点的 `搭界面` ——
##   ★ 和旧版不同：**对局照常跑，F1 调试照常能用**，因为接线的责任在这里，不在界面里。
## ============================================================
extends Control

## 这一局玩哪个故事。换第二个故事 = 换这一行。
@export_file("*.gd") var 故事路径: String = "res://脚本/数据/故事_第一案.gd"

## 整个游戏的状态就在这一个对象上。外面想动手就动它：`$主.局.下一幕()`
var 局: 对局 = null
var 美术: 美术接口 = null

@onready var 纸: ColorRect = %纸
@onready var 现场层: Control = %现场层
@onready var 界面节点: Control = %界面
@onready var 演出层: Control = %演出层
@onready var 调试层: Control = %调试层
@onready var 交互层: Node = %交互层


func _ready() -> void:
	var 数据: Dictionary = 读故事(故事路径)
	if 数据.is_empty():
		push_error("读不到故事数据：%s —— 故事文件里必须有一个 `const 数据: Dictionary`。" % 故事路径)
		return

	# ① 开局（这一步会进第 1 幕）
	局 = 对局.new(数据)

	# ② 界面：订阅 局，画第一屏
	if 界面节点 != null and 界面节点.has_method("接上"):
		界面节点.接上(局)

	# ③ 美术：所有画面接线都在 美术接口.gd 里
	美术 = 美术接口.new()
	美术.接上(局, 现场层, 演出层)
	美术.当_换幕(局.幕, 局.总幕数(), 局.幕名())    # 补一次开场，免得第一幕没画面

	# ④ 交互：换交互 = 换 %交互层 的脚本
	if 交互层 != null and 交互层.has_method("绑定"):
		交互层.绑定(局, 界面节点)

	# ⑤ 调试叠层（F1）
	if 调试层 != null and 调试层.has_method("接上"):
		调试层.接上(局, 界面节点)


## 从任意一份「有 const 数据 的 .gd」里取出故事。换故事靠这个。
func 读故事(路径: String) -> Dictionary:
	var 脚本: Variant = load(路径)
	if 脚本 == null or not (脚本 is GDScript):
		return {}
	var 表: Dictionary = (脚本 as GDScript).get_script_constant_map()
	if not 表.has("数据"):
		return {}
	var 数据: Variant = 表["数据"]
	return 数据 as Dictionary if 数据 is Dictionary else {}
