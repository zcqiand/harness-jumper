extends RefCounted
## 关卡契约套件：校验枚举 / normalize 缺省补全 / themes 真源。
## 骨架原始契约内联硬编码（与 data/levels/jump_001.json 升级前的 platforms 一致），
## 保证「骨架契约不破坏」：老 flat 形状必须仍然合法。

const HARNESS_PATH := "res://tests/harness.gd"
const CONTRACT_PATH := "res://scripts/level_contract.gd"
const THEMES_PATH := "res://scripts/themes.gd"

## 骨架原始 jump_001 内容（升级前快照）。
const SKELETON_LEVEL := {
	"name": "sample-steps",
	"gravity": 980.0,
	"jump_speed": -420.0,
	"platforms": [
		[0, 400, 640, 40],
		[200, 300, 120, 20],
		[380, 220, 120, 20],
		[540, 140, 100, 20],
	],
}


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var contract: GDScript = load(CONTRACT_PATH)

	# 骨架契约不破坏：原始 flat 契约必须合法
	harness.assert_eq(
		contract.validate(SKELETON_LEVEL), "",
		"skeleton flat contract validates", failures,
	)

	# 各错误枚举各一例
	var missing := SKELETON_LEVEL.duplicate(true)
	missing.erase("gravity")
	harness.assert_eq(
		contract.validate(missing), contract.ERROR_MISSING_FIELD,
		"missing gravity -> missing-field", failures,
	)

	var bad_type := SKELETON_LEVEL.duplicate(true)
	bad_type["platforms"] = [[0, 400]]
	harness.assert_eq(
		contract.validate(bad_type), contract.ERROR_BAD_TYPE,
		"2-tuple platform -> bad-type", failures,
	)

	var negative := SKELETON_LEVEL.duplicate(true)
	negative["platforms"] = [[0, -1, 10, 10]]
	harness.assert_eq(
		contract.validate(negative), contract.ERROR_NEGATIVE_VALUE,
		"negative platform y -> negative-value", failures,
	)

	var bad_spawn := SKELETON_LEVEL.duplicate(true)
	bad_spawn["spawn"] = [-40, 400]
	harness.assert_eq(
		contract.validate(bad_spawn), contract.ERROR_BAD_SPAWN,
		"negative spawn x -> bad-spawn", failures,
	)

	var bad_checkpoints := SKELETON_LEVEL.duplicate(true)
	bad_checkpoints["checkpoints"] = "not-an-array"
	harness.assert_eq(
		contract.validate(bad_checkpoints), contract.ERROR_BAD_CHECKPOINTS,
		"checkpoints non-array -> bad-checkpoints", failures,
	)

	var unknown_theme := SKELETON_LEVEL.duplicate(true)
	unknown_theme["theme"] = "noir"
	harness.assert_eq(
		contract.validate(unknown_theme), contract.ERROR_UNKNOWN_THEME,
		"unknown theme -> unknown-theme", failures,
	)

	# normalize：骨架 flat 输入补缺省
	var normalized: Dictionary = contract.normalize(SKELETON_LEVEL)
	harness.assert_near(normalized["move_speed"], 220.0, 0.001, "default move_speed", failures)
	harness.assert_near(normalized["move_accel"], 2400.0, 0.001, "default move_accel", failures)
	var first_platform: Dictionary = (normalized["platforms"] as Array)[0]
	harness.assert_near(first_platform["x"], 0.0, 0.001, "platform 0 x", failures)
	harness.assert_near(first_platform["y"], 400.0, 0.001, "platform 0 y", failures)
	harness.assert_near(first_platform["w"], 640.0, 0.001, "platform 0 w", failures)
	harness.assert_near(first_platform["h"], 40.0, 0.001, "platform 0 h", failures)

	# normalize：显式键不被缺省覆盖
	var explicit := SKELETON_LEVEL.duplicate(true)
	explicit["move_speed"] = 300
	explicit["move_accel"] = 3600
	explicit["theme"] = "moon"
	explicit["spawn"] = [10, 20]
	explicit["checkpoints"] = [[100, 200]]
	var explicit_norm: Dictionary = contract.normalize(explicit)
	harness.assert_near(explicit_norm["move_speed"], 300.0, 0.001, "explicit move_speed kept", failures)
	harness.assert_near(explicit_norm["move_accel"], 3600.0, 0.001, "explicit move_accel kept", failures)
	harness.assert_eq(explicit_norm["theme"], "moon", "explicit theme kept", failures)
	var spawn_point: Array = explicit_norm["spawn"]
	harness.assert_near(spawn_point[0], 10.0, 0.001, "explicit spawn x kept", failures)
	harness.assert_near(spawn_point[1], 20.0, 0.001, "explicit spawn y kept", failures)
	harness.assert_eq((explicit_norm["checkpoints"] as Array).size(), 1, "explicit checkpoints kept", failures)

	# themes 真源：三主题各 4 键 + palette 未知 theme 兜底 classic
	var themes: GDScript = load(THEMES_PATH)
	for theme_name in ["classic", "moon", "candy"] as Array[String]:
		var palette: Dictionary = themes.palette(theme_name)
		harness.assert_true(
			palette.has_all(["bg", "platform", "player", "accent"]),
			"%s palette has bg/platform/player/accent" % theme_name,
			failures,
		)
	harness.assert_eq(
		themes.palette("noir"), themes.palette("classic"),
		"unknown theme palette falls back to classic", failures,
	)
