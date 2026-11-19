extends RefCounted
## 关卡契约层：校验（validate）+ 缺省补全（normalize）+ 加载（load_level）。
## 校验语义边界：spawn/goal 的检查归 bad-spawn / bad-goal（含负值）；
## platforms / checkpoints 的元素检查归 bad-type / negative-value / bad-checkpoints；
## theme 不在色板表 → unknown-theme（palette 的未知→classic 兜底属渲染层宽容，校验层严格）。
## 后续运动学 / 认证器 / 游戏屏只认 normalize 后形状：
## platforms 每项 {x, y, w, h}（float 字典），spawn/goal/checkpoints 是 [x, y] 数组。

const THEMES_SCRIPT := preload("res://scripts/themes.gd")
const REACHABILITY := preload("res://scripts/reachability.gd")

const ERROR_NOT_OBJECT := "not-object"
## 认证闸拒载原因格式（push_error 含 unreachable-<点身份>：
## platform-<idx> / goal / checkpoint-<i>，与 certify.unreachable_point 同族）。
const ERROR_UNREACHABLE := "unreachable-%s"
const ERROR_MISSING_FIELD := "missing-field"
const ERROR_BAD_TYPE := "bad-type"
const ERROR_NEGATIVE_VALUE := "negative-value"
const ERROR_BAD_SPAWN := "bad-spawn"
const ERROR_BAD_GOAL := "bad-goal"
const ERROR_BAD_CHECKPOINTS := "bad-checkpoints"
const ERROR_UNKNOWN_THEME := "unknown-theme"

## 骨架 flat 键语义保留：这四键缺一不可（缺 → missing-field）。
const REQUIRED_KEYS: Array[String] = ["name", "gravity", "jump_speed", "platforms"]


## 关卡规约校验：合法返回 ""，否则返回错误枚举常量。
static func validate(data: Dictionary) -> String:
	if not data.has_all(REQUIRED_KEYS):
		return ERROR_MISSING_FIELD
	if not _is_number(data["gravity"]) or not _is_number(data["jump_speed"]):
		return ERROR_BAD_TYPE
	var platform_error := _validate_platforms(data["platforms"])
	if platform_error != "":
		return platform_error
	for key in ["move_speed", "move_accel"] as Array[String]:
		if data.has(key) and not _is_number(data[key]):
			return ERROR_BAD_TYPE
	var spawn_error := _validate_point(data, "spawn", ERROR_BAD_SPAWN)
	if spawn_error != "":
		return spawn_error
	var goal_error := _validate_point(data, "goal", ERROR_BAD_GOAL)
	if goal_error != "":
		return goal_error
	if data.has("checkpoints"):
		var checkpoints: Variant = data["checkpoints"]
		if typeof(checkpoints) != TYPE_ARRAY:
			return ERROR_BAD_CHECKPOINTS
		for point in checkpoints as Array:
			if not _is_point(point) or (point as Array)[0] < 0.0 or (point as Array)[1] < 0.0:
				return ERROR_BAD_CHECKPOINTS
	if data.has("theme") and not THEMES_SCRIPT.THEMES.has(data["theme"]):
		return ERROR_UNKNOWN_THEME
	return ""


## 缺省补全 + 形状归一（不改传入字典，返回新字典）：
## move_speed=220.0 / move_accel=2400.0 / theme="classic" / spawn=[40.0, 400.0] /
## goal=null / checkpoints=[]；platforms 四元组数组转 {x, y, w, h} float 字典数组。
static func normalize(data: Dictionary) -> Dictionary:
	var level := data.duplicate(true)
	if not level.has("move_speed"):
		level["move_speed"] = 220.0
	if not level.has("move_accel"):
		level["move_accel"] = 2400.0
	if not level.has("theme"):
		level["theme"] = "classic"
	if not level.has("spawn"):
		level["spawn"] = [40.0, 400.0]
	if not level.has("goal"):
		level["goal"] = null
	if not level.has("checkpoints"):
		level["checkpoints"] = []
	var platforms: Array = []
	for platform in level["platforms"] as Array:
		var quad: Array = platform
		platforms.append({
			"x": float(quad[0]),
			"y": float(quad[1]),
			"w": float(quad[2]),
			"h": float(quad[3]),
		})
	level["platforms"] = platforms
	return level


## 读取并解析关卡契约文件（骨架同款 fail-fast）：任何一步失败（打不开/非 JSON
## 对象/校验不过/可达性认证不过）push_error 后返回空字典；合法时返回 normalize
## 后契约并附 "id"（文件名去扩展名）。
static func load_level(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail_payload("关卡文件打不开：%s" % path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail_payload("关卡契约不是 JSON 对象（%s）：%s" % [ERROR_NOT_OBJECT, path])
	var data: Dictionary = parsed
	var error := validate(data)
	if error != "":
		return _fail_payload("关卡契约不合法（%s）：%s" % [error, path])
	var level := normalize(data)
	# 认证闸：不可达关卡当场拒载并报第一个够不到的点身份（平台/终点旗/检查点）。
	var cert: Dictionary = REACHABILITY.certify(level)
	if not cert["ok"]:
		return _fail_payload(ERROR_UNREACHABLE % String(cert["unreachable_point"]))
	level["id"] = path.get_file().get_basename()
	return level


## platforms 检查：每项须 [x, y, 宽, 高] 四元组，数值非负。
static func _validate_platforms(platforms: Variant) -> String:
	if typeof(platforms) != TYPE_ARRAY:
		return ERROR_BAD_TYPE
	for platform in platforms as Array:
		if typeof(platform) != TYPE_ARRAY or (platform as Array).size() != 4:
			return ERROR_BAD_TYPE
		for value in platform as Array:
			if not _is_number(value):
				return ERROR_BAD_TYPE
			if (value as float) < 0.0:
				return ERROR_NEGATIVE_VALUE
	return ""


## 单点键（spawn/goal）检查：可缺省；存在时须 [x, y] 数值对且非负。
static func _validate_point(data: Dictionary, key: String, error: String) -> String:
	if not data.has(key):
		return ""
	var point: Variant = data[key]
	if not _is_point(point) or (point as Array)[0] < 0.0 or (point as Array)[1] < 0.0:
		return error
	return ""


## [x, y] 数值对判定。
static func _is_point(point: Variant) -> bool:
	return typeof(point) == TYPE_ARRAY and (point as Array).size() == 2 \
		and _is_number((point as Array)[0]) and _is_number((point as Array)[1])


## 数值判定：int 与 float 都算（JSON 解析不保类型）。
static func _is_number(value: Variant) -> bool:
	return value is float or value is int


## fail-fast 出口：错误经 push_error 上报，返回空字典（骨架同款）。
static func _fail_payload(reason: String) -> Dictionary:
	push_error(reason)
	return {}
