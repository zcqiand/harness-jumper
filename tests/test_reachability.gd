extends RefCounted
## 可达性判定器套件：BFS 认证正例/负例/坠落边 + load_level 认证闸接线。
## 顺手账（Task 2 评审留账）：load_level 的 fail-fast（坏 JSON→{}）与 id 附着断言。

const HARNESS_PATH := "res://tests/harness.gd"
const CONTRACT_PATH := "res://scripts/level_contract.gd"
const REACHABILITY_PATH := "res://scripts/reachability.gd"
const LEVEL_PATH := "res://data/levels/jump_001.json"
const WORK_DIR := "res://_work"

## 负例：两平台关——默认参数（gravity=980/jump_speed=-420）峰值 ~90px，
## 够不到 B 的 300px 高差（A 顶 400 → B 顶 100）。
const UNREACHABLE_LEVEL := {
	"name": "gap-too-high",
	"gravity": 980.0,
	"jump_speed": -420.0,
	"spawn": [40, 400],
	"platforms": [
		[0, 400, 200, 40],
		[500, 100, 100, 20],
	],
}

## 坠落边正例：从 A 右缘走出坠落到 B（无跳跃也可达）。
const FALL_LEVEL := {
	"name": "fall-reach",
	"gravity": 980.0,
	"jump_speed": -420.0,
	"spawn": [40, 200],
	"platforms": [
		[0, 200, 200, 40],
		[150, 400, 200, 40],
	],
}


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var contract: GDScript = load(CONTRACT_PATH)
	var reachability: GDScript = load(REACHABILITY_PATH)

	# 钉值哨兵：认证器常量（brief 全文钉值，改动即红）
	harness.assert_near(reachability.SIM_TIME_LIMIT, 3.0, 0.0001, "SIM_TIME_LIMIT pinned", failures)
	harness.assert_near(reachability.DEATH_MARGIN, 800.0, 0.0001, "DEATH_MARGIN pinned", failures)
	harness.assert_near(reachability.EDGE_SAMPLE_STEP, 24.0, 0.0001, "EDGE_SAMPLE_STEP pinned", failures)

	# 正例①：jump_001（文件直读 normalize 后）全平台可达，触发点也全可达
	var file := FileAccess.open(LEVEL_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var jump_001: Dictionary = contract.normalize(data)
	var cert: Dictionary = reachability.certify(jump_001)
	harness.assert_eq(cert["ok"], true, "jump_001 certifies reachable", failures)
	harness.assert_eq(cert["unreachable"], -1, "jump_001 unreachable=-1", failures)
	harness.assert_eq(cert["unreachable_point"], "", "jump_001 reports no unreachable point", failures)

	# 负例②：300px 高差不可达，报第一个够不到的平台序号
	var bad_cert: Dictionary = reachability.certify(contract.normalize(UNREACHABLE_LEVEL))
	harness.assert_eq(bad_cert["ok"], false, "unreachable level certifies not ok", failures)
	harness.assert_eq(bad_cert["unreachable"], 1, "unreachable reports platform 1", failures)

	# 正例③：坠落边——从 A 右缘走出坠到 B，无跳跃也 ok
	var fall_cert: Dictionary = reachability.certify(contract.normalize(FALL_LEVEL))
	harness.assert_eq(fall_cert["ok"], true, "fall edge reaches platform B", failures)
	harness.assert_eq(fall_cert["unreachable"], -1, "fall edge unreachable=-1", failures)

	# 认证闸接线④：不可达契约 load_level → {} 拒载，原因含 unreachable-platform-1
	var reject_path := "%s/t4-unreachable-fixture.json" % WORK_DIR
	var out := FileAccess.open(reject_path, FileAccess.WRITE)
	out.store_string(JSON.stringify(UNREACHABLE_LEVEL))
	out.close()
	var rejected: Dictionary = contract.load_level(reject_path)
	harness.assert_true(rejected.is_empty(), "unreachable level load_level -> {}", failures)
	harness.assert_eq(
		contract.ERROR_UNREACHABLE % "platform-1", "unreachable-platform-1",
		"reject reason names platform index", failures,
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(reject_path))

	# 认证闸接线⑤（终审修复波次 Important #1）：平台全可达但 goal 悬空的变体
	# load_level → {} 拒载，拒载文案随点身份同步报 unreachable-goal。
	var goal_dangle: Dictionary = FALL_LEVEL.duplicate(true)
	goal_dangle["goal"] = [600.0, 50.0]  # 距两平台顶面撑脚区间均远超触发半径
	var goal_cert: Dictionary = reachability.certify(contract.normalize(goal_dangle))
	harness.assert_eq(goal_cert["ok"], false, "dangling goal certifies not ok", failures)
	harness.assert_eq(goal_cert["unreachable_point"], "goal", "dangling goal reported as goal", failures)
	var goal_reject_path := "%s/t4-dangling-goal-fixture.json" % WORK_DIR
	var goal_out := FileAccess.open(goal_reject_path, FileAccess.WRITE)
	goal_out.store_string(JSON.stringify(goal_dangle))
	goal_out.close()
	var goal_rejected: Dictionary = contract.load_level(goal_reject_path)
	harness.assert_true(goal_rejected.is_empty(), "dangling goal level load_level -> {}", failures)
	harness.assert_eq(
		contract.ERROR_UNREACHABLE % "goal", "unreachable-goal",
		"reject reason syncs with point identity", failures,
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(goal_reject_path))

	# 顺手账（Task 2 留账）：合法契约 load_level 附 id（文件名去扩展名）
	var loaded: Dictionary = contract.load_level(LEVEL_PATH)
	harness.assert_eq(loaded["id"], "jump_001", "load_level attaches id from filename", failures)

	# 顺手账：坏 JSON 文件 fail-fast → {}
	var bad_path := "%s/t4-bad-json-fixture.json" % WORK_DIR
	var bad_out := FileAccess.open(bad_path, FileAccess.WRITE)
	bad_out.store_string("{not json")
	bad_out.close()
	var bad_loaded: Dictionary = contract.load_level(bad_path)
	harness.assert_true(bad_loaded.is_empty(), "bad JSON load_level -> {}", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bad_path))
