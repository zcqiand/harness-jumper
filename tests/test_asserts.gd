extends RefCounted
## 运行时断言套件：峰值界/落点区间 bool 判定 + 违例收集器，钉值全按 plan Task 5。
## 落点区间与 kinematics.find_landing 同款（±PLAYER_HALF_W 撑脚余量）。钉值裁定存证：
## plan Step 1 示例「x=650→false」与接口钉「±PLAYER_HALF_W 区间」算术冲突（右界
## 0+640+12=652，650 在区间内）；冲突以接口钉为准——spec 裁定 13「落点判定以碰撞盒
## 底边中心落在平台顶面 x 区间内为准」+ check_landing 与 find_landing 同款区间不分叉。
## 故负例取 653（区间外），并显式钉 650→true 把裁定写进测试。

const HARNESS_PATH := "res://tests/harness.gd"
const ASSERTS_PATH := "res://scripts/runtime_asserts.gd"

const GRAVITY := 980.0
const JUMP_SPEED := -420.0


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var asserts: GDScript = load(ASSERTS_PATH)
	if asserts == null:
		harness.assert_true(false, "runtime_asserts.gd 加载失败", failures)
		return

	_test_tolerance(harness, asserts, failures)
	_test_check_peak(harness, asserts, failures)
	_test_check_landing(harness, asserts, failures)
	_test_new_violations(harness, asserts, failures)


## level 字典按 level_contract.normalize 产物构造（check_peak 只消费 gravity/jump_speed）。
func _level() -> Dictionary:
	return {"gravity": GRAVITY, "jump_speed": JUMP_SPEED}


func _test_tolerance(harness: GDScript, asserts: GDScript, failures: Array[String]) -> void:
	harness.assert_eq(asserts.PEAK_TOLERANCE, 2.0, "PEAK_TOLERANCE = 2", failures)


func _test_check_peak(harness: GDScript, asserts: GDScript, failures: Array[String]) -> void:
	# 峰界 = peak_height(-420, 980) + 2 = 90 + 2 = 92
	# 正例（plan Step 1 钉值）：89.9 ≤ 92 → true
	harness.assert_true(asserts.check_peak(89.9, _level()),
		"check_peak 89.9 within cap", failures)
	# 负例（plan Step 1 钉值）：95.0 超 90+2 → false
	harness.assert_true(not asserts.check_peak(95.0, _level()),
		"check_peak 95.0 over cap", failures)
	# 边界：恰在峰界 92.0 → true（≤ 含等号语义）
	harness.assert_true(asserts.check_peak(92.0, _level()),
		"check_peak cap 92.0 inclusive", failures)
	# 符号语义：jump_speed 正负同峰界（peak_height 平方吞符号）
	var positive: Dictionary = {"gravity": GRAVITY, "jump_speed": 420.0}
	harness.assert_eq(
		asserts.check_peak(89.9, positive), asserts.check_peak(89.9, _level()),
		"check_peak sign-independent", failures,
	)


func _test_check_landing(harness: GDScript, asserts: GDScript, failures: Array[String]) -> void:
	# 平台按 plan Step 1 钉值构造（顶面 [0, 640]，±PLAYER_HALF_W=12 → 区间 [-12, 652]）
	var platform: Dictionary = {"x": 0.0, "y": 400.0, "w": 640.0}
	# 正例（plan Step 1 钉值）：630 ∈ [-12, 652] → true
	harness.assert_true(asserts.check_landing(630.0, platform),
		"check_landing 630 on platform", failures)
	# 区间端点：652 = 右缘+撑脚余量 → true（find_landing 同款含端点）
	harness.assert_true(asserts.check_landing(652.0, platform),
		"check_landing right edge 652 inclusive", failures)
	# 存证钉：plan 示例值 650 按同款区间公式在撑脚余量内 → true（裁定见套件头注）
	harness.assert_true(asserts.check_landing(650.0, platform),
		"check_landing 650 within foot margin (ruling)", failures)
	# 负例：653 出撑脚余量 → false
	harness.assert_true(not asserts.check_landing(653.0, platform),
		"check_landing 653 off platform", failures)
	# 左端点：-12 含端点 → true；-13 → false
	harness.assert_true(asserts.check_landing(-12.0, platform),
		"check_landing left edge -12 inclusive", failures)
	harness.assert_true(not asserts.check_landing(-13.0, platform),
		"check_landing -13 off left edge", failures)


func _test_new_violations(harness: GDScript, asserts: GDScript, failures: Array[String]) -> void:
	# 空违例表；违例标签 "peak-exceeded"/"landing-off-platform" 由调用方 append
	var violations: Array[String] = asserts.new_violations()
	harness.assert_eq(violations.size(), 0, "new_violations empty", failures)
	harness.assert_true(violations.is_typed(), "new_violations typed array", failures)
