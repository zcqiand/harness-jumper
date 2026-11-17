extends Node2D
## 主场景脚本（骨架）：加载关卡 JSON 契约并做形状校验。
## ch10 落物理规约断言与碰撞判定；本骨架只证「契约文件可加载、可校验」。

const LEVEL_PATH := "res://data/levels/jump_001.json"


func _ready() -> void:
	var level := load_level(LEVEL_PATH)
	if level.is_empty():
		push_error("关卡加载失败，见上方错误。")
		return
	print(
		"关卡加载成功：%s（%d 块平台，重力 %s，跳跃力 %s）" % [
			level["name"],
			(level["platforms"] as Array).size(),
			level["gravity"],
			level["jump_speed"],
		]
	)


## 读取并解析关卡契约文件；任何一步失败返回空字典（fail-fast，错误经 push_error 上报）。
func load_level(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("关卡文件打不开：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("关卡契约不是 JSON 对象：%s" % path)
		return {}
	var level: Dictionary = parsed
	if not is_valid_level(level):
		push_error("关卡契约形状不合法：%s" % path)
		return {}
	return level


## 关卡规约（骨架版）：必须有 name / gravity / jump_speed / platforms；
## platforms 每项为 [x, y, 宽, 高] 四元组，数值为非负。
func is_valid_level(level: Dictionary) -> bool:
	if not level.has_all(["name", "gravity", "jump_speed", "platforms"]):
		return false
	if not _is_number(level["gravity"]) or not _is_number(level["jump_speed"]):
		return false
	var platforms: Variant = level["platforms"]
	if typeof(platforms) != TYPE_ARRAY:
		return false
	for platform in platforms as Array:
		if typeof(platform) != TYPE_ARRAY or (platform as Array).size() != 4:
			return false
		for value in platform as Array:
			if not _is_number(value) or (value as float) < 0.0:
				return false
	return true


## 数值判定：int 与 float 都算（JSON 解析不保类型）。
func _is_number(value: Variant) -> bool:
	return value is float or value is int
