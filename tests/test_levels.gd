extends RefCounted
## 关卡集全认证门槛套件：扫描 res://data/levels/*.json，
## 每关 validate==""（契约合法）且 certify.ok==true（全平台可达）——
## 关卡集全认证是关卡集的发布门槛，加关不跑本套件不许发布。
## 另断言关卡集在册（三关齐全）与 moon_001 物理差异指纹：
## gravity==160（对比 classic 980）在册；moon 布局喂 classic 参数必须不可达——
## 「classic 玩不了、moon 玩得了」是本关的 showcase 承诺，双向都要钉住。

const HARNESS_PATH := "res://tests/harness.gd"
const CONTRACT_PATH := "res://scripts/level_contract.gd"
const LEVELS_DIR := "res://data/levels"
const EXPECTED_IDS: Array[String] = ["jump_001", "jump_002", "moon_001"]

## classic 基准参数（jump_001 同款）：moon 布局反证喂这组。
const CLASSIC_PARAMS := {
	"gravity": 980.0, "jump_speed": -450.0, "move_speed": 220.0, "move_accel": 2400.0,
}


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var contract: GDScript = load(CONTRACT_PATH)

	var ids: Array[String] = []
	var dir := DirAccess.open(LEVELS_DIR)
	harness.assert_true(dir != null, "levels dir opens", failures)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var id := file_name.get_basename()
			ids.append(id)
			_check_level(contract, harness, id, "%s/%s" % [LEVELS_DIR, file_name], failures)
		file_name = dir.get_next()
	dir.list_dir_end()

	# 关卡集在册：三关齐全（缺关即红，扩关不误伤）
	for expected in EXPECTED_IDS:
		harness.assert_true(
			ids.has(expected), "level set contains %s" % expected, failures,
		)

	# moon_001 物理差异指纹：moon 参数在册 + 布局换 classic 参数不可达
	var moon_path := "%s/moon_001.json" % LEVELS_DIR
	var moon_file := FileAccess.open(moon_path, FileAccess.READ)
	harness.assert_true(moon_file != null, "moon_001.json opens", failures)
	if moon_file != null:
		var moon_data: Variant = JSON.parse_string(moon_file.get_as_text())
		if moon_data is Dictionary:
			var data: Dictionary = moon_data
			harness.assert_near(float(data["gravity"]), 160.0, 0.001, "moon_001 gravity=160", failures)
			harness.assert_near(float(data["jump_speed"]), -260.0, 0.001, "moon_001 jump_speed=-260", failures)
			harness.assert_eq(data["theme"], "moon", "moon_001 theme=moon", failures)
			var classic_variant: Dictionary = data.duplicate(true)
			for key in CLASSIC_PARAMS:
				classic_variant[key] = CLASSIC_PARAMS[key]
			var classic_cert: Dictionary = contract.REACHABILITY.certify(contract.normalize(classic_variant))
			harness.assert_eq(
				classic_cert["ok"], false,
				"moon_001 layout under classic params is unreachable (showcase)",
				failures,
			)

	# 认证第二段（终审修复波次 Important #1，红先）：goal/checkpoint 触发点可达性闸——
	# 平台 BFS 全可达但 goal 悬在半空（不在任何可达平台顶面的触发半径内）的关卡，
	# 修复前照样过闸拿 certified ✓ 却永不可通关；修复后 certify 拒证并报点身份。
	var base_file := FileAccess.open("%s/jump_001.json" % LEVELS_DIR, FileAccess.READ)
	harness.assert_true(base_file != null, "jump_001.json opens (gate variant base)", failures)
	if base_file != null:
		var base_data: Variant = JSON.parse_string(base_file.get_as_text())
		if base_data is Dictionary:
			var base: Dictionary = base_data
			# goal 悬空变体：goal [300, 260] 距最近可达平台顶面（P1 顶 y=300，
			# x 撑脚区间 [188, 332]）垂直 40px > 触发半径 24px → 不可触发。
			var goal_dangling: Dictionary = base.duplicate(true)
			goal_dangling["goal"] = [300.0, 260.0]
			var goal_cert: Dictionary = contract.REACHABILITY.certify(contract.normalize(goal_dangling))
			harness.assert_eq(goal_cert["ok"], false, "dangling goal fails certify gate", failures)
			harness.assert_eq(goal_cert["unreachable_point"], "goal",
				"dangling goal reported as goal", failures)
			# checkpoint 悬空变体：cp1 [630, 470] 距地面顶面 y=400 垂直 70px > 半径
			# （cp0 原位仍在 P1 顶面）→ 报 "checkpoint-1"。
			var cp_dangling: Dictionary = base.duplicate(true)
			cp_dangling["checkpoints"] = [[260.0, 300.0], [630.0, 470.0]]
			var cp_cert: Dictionary = contract.REACHABILITY.certify(contract.normalize(cp_dangling))
			harness.assert_eq(cp_cert["ok"], false, "dangling checkpoint fails certify gate", failures)
			harness.assert_eq(cp_cert["unreachable_point"], "checkpoint-1",
				"dangling checkpoint reported by index", failures)


## 单关门槛：契约合法 + 认证可达（读文件任一步失败记红不中断）。
func _check_level(contract: GDScript, harness: GDScript, id: String, path: String, \
		failures: Array[String]) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	harness.assert_true(file != null, "%s opens" % id, failures)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	harness.assert_true(data is Dictionary, "%s parses to JSON object" % id, failures)
	if not (data is Dictionary):
		return
	var typed: Dictionary = data
	harness.assert_eq(contract.validate(typed), "", "%s validates" % id, failures)
	var cert: Dictionary = contract.REACHABILITY.certify(contract.normalize(typed))
	harness.assert_eq(cert["ok"], true, "%s certifies reachable" % id, failures)
