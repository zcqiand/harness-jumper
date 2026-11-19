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
