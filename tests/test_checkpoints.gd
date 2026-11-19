extends RefCounted
## 检查点时序套件：按序激活状态机 + 坠落重生点，钉值全按 plan Task 5。
## Review Focus：乱序不激活（跳序=违例+1，目标位保持未激活，next 不动）。
## 「最近激活检查点」=按激活顺序最新激活位（时序语义，spec 裁定 4：检查点按序激活、
## 最近者即坠落重生点）；respawn_point 的 points=[x, y] 契约数组，转 Vector2 由模块做。

const HARNESS_PATH := "res://tests/harness.gd"
const CHECKPOINTS_PATH := "res://scripts/checkpoints.gd"

const SPAWN := Vector2(40.0, 400.0)


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var cps: GDScript = load(CHECKPOINTS_PATH)
	if cps == null:
		harness.assert_true(false, "checkpoints.gd 加载失败", failures)
		return

	_test_new_state(harness, cps, failures)
	_test_in_order(harness, cps, failures)
	_test_out_of_order(harness, cps, failures)
	_test_pure(harness, cps, failures)
	_test_respawn(harness, cps, failures)


## points 按 level_contract.normalize 产物形状（checkpoints 是 [x, y] 数组的数组）。
func _points() -> Array:
	return [[260.0, 300.0], [440.0, 220.0], [560.0, 180.0]]


func _test_new_state(harness: GDScript, cps: GDScript, failures: Array[String]) -> void:
	var state: Dictionary = cps.new_state(3)
	harness.assert_eq(int(state["next"]), 0, "new_state next=0", failures)
	harness.assert_eq(int(state["violations"]), 0, "new_state violations=0", failures)
	var activated: Array = state["activated"]
	harness.assert_eq(activated.size(), 3, "new_state activated count=3", failures)
	var all_false := true
	for flag in activated:
		if flag:
			all_false = false
	harness.assert_true(all_false, "new_state activated all false", failures)


func _test_in_order(harness: GDScript, cps: GDScript, failures: Array[String]) -> void:
	# plan Step 1 钉值：触发 0→1→2 全激活，violations=0
	var state: Dictionary = cps.new_state(3)
	state = cps.trigger(state, 0)
	state = cps.trigger(state, 1)
	state = cps.trigger(state, 2)
	var activated: Array = state["activated"]
	harness.assert_true(activated[0] and activated[1] and activated[2],
		"in-order 0-1-2 all activated", failures)
	harness.assert_eq(int(state["next"]), 3, "in-order next=3", failures)
	harness.assert_eq(int(state["violations"]), 0, "in-order violations=0", failures)


func _test_out_of_order(harness: GDScript, cps: GDScript, failures: Array[String]) -> void:
	# plan Step 1 钉值：跳过 0 直触 1 → violations=1 且 1 未激活
	var state: Dictionary = cps.new_state(3)
	state = cps.trigger(state, 1)
	harness.assert_eq(int(state["violations"]), 1,
		"out-of-order violation counted", failures)
	harness.assert_true(not (state["activated"] as Array)[1],
		"out-of-order index 1 not activated", failures)
	harness.assert_eq(int(state["next"]), 0,
		"out-of-order next unchanged", failures)
	# 乱序不锁死流程：违例后按序触 0 仍激活，违例计数保留（成绩不认可但可继续玩）
	var recovered: Dictionary = cps.trigger(state, 0)
	harness.assert_true((recovered["activated"] as Array)[0],
		"in-order after violation activates", failures)
	harness.assert_eq(int(recovered["violations"]), 1,
		"violation count persists", failures)


func _test_pure(harness: GDScript, cps: GDScript, failures: Array[String]) -> void:
	# 纯函数：trigger 不改传入 state（kinematics 同款纪律）
	var state: Dictionary = cps.new_state(2)
	cps.trigger(state, 0)
	harness.assert_eq(int(state["violations"]), 0,
		"trigger does not mutate input violations", failures)
	harness.assert_true(not (state["activated"] as Array)[0],
		"trigger does not mutate input activated", failures)


func _test_respawn(harness: GDScript, cps: GDScript, failures: Array[String]) -> void:
	var points: Array = _points()
	# plan Step 1 钉值：激活 0,1 后重生 = points[1]
	var state: Dictionary = cps.new_state(3)
	state = cps.trigger(state, 0)
	state = cps.trigger(state, 1)
	harness.assert_eq(cps.respawn_point(state, points, SPAWN), Vector2(440.0, 220.0),
		"respawn latest activated = points[1]", failures)
	# 只激活 0 → points[0]
	var only_first: Dictionary = cps.trigger(cps.new_state(3), 0)
	harness.assert_eq(cps.respawn_point(only_first, points, SPAWN), Vector2(260.0, 300.0),
		"respawn only cp0 = points[0]", failures)
	# plan Step 1 钉值：空状态（无激活）→ spawn
	harness.assert_eq(cps.respawn_point(cps.new_state(3), points, SPAWN), SPAWN,
		"respawn none -> spawn", failures)
