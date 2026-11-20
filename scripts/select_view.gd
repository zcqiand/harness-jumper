extends Control
## 选关屏（Task 8）：扫描关卡目录逐个过认证闸，合法关卡出卡
## （名字+主题色块+certified ✓ 徽章+PB 时间），点击进图；
## 拒载关卡在列表尾部红字一行报原因，不崩（契约校验 fail-fast，UI 面宽容）。
## storage 鸭子接口注入读 PB（缺省可传 FileStorage 实例，测试传内存假件）。

signal level_selected(level: Dictionary)

const SCOREBOOK := preload("res://scripts/scorebook.gd")
const LEVEL_CONTRACT := preload("res://scripts/level_contract.gd")
const THEMES := preload("res://scripts/themes.gd")
const REACHABILITY := preload("res://scripts/reachability.gd")

const DEFAULT_LEVELS_DIR := "res://data/levels"
## 卡片行距与首行 y。
const CARD_STEP := 76.0
const CARD_TOP := 230.0
## 拒载红字行距。
const REJECT_STEP := 24.0

var _valid_levels: Array[Dictionary] = []
var _rejections: Array[String] = []
var _labels: Array[String] = []


## 建整屏：扫描 levels_dir 下 *.json（按名排序），合法出卡、拒载红字。
## levels_dir 可注入（headless 冒烟用 user:// 临时目录验拒载路径）。
func setup(storage, levels_dir: String = DEFAULT_LEVELS_DIR) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var book: Dictionary = SCOREBOOK.load_book(storage)
	var best: Dictionary = book.get("best", {})

	_label(Vector2(60.0, 110.0), "harness-jumper", 36, Color.WHITE)
	_label(Vector2(60.0, 170.0), "物理契约即关卡：可达性认证 + 运行时断言双闸", 18, Color.WHITE)

	var paths := _scan_level_paths(levels_dir)
	for i in paths.size():
		var path: String = paths[i]
		var level: Dictionary = LEVEL_CONTRACT.load_level(path)
		if not level.is_empty():
			_card(i, level, best)
		else:
			_rejections.append("%s × 拒载（认证闸：%s）" % [path.get_file(), _reject_reason(path)])

	# 拒载关卡：列表尾部红字一行报原因（加载侧已 push_error，这里补 UI 面）。
	var reject_top := CARD_TOP + CARD_STEP * _valid_levels.size() + 12.0
	for j in _rejections.size():
		_label(Vector2(60.0, reject_top + REJECT_STEP * j), _rejections[j], 16,
			Color(0.95, 0.35, 0.35))

	var hint := "点击关卡卡开始 · Space 玩第一关"
	if _valid_levels.is_empty():
		hint = "没有可用关卡（全部被认证闸拒载）"
	_label(Vector2(60.0, 440.0), hint, 18, Color.WHITE)


## 合法关卡卡数（冒烟断言口）。
# @entry M01.F01.I01
# @entry M01.F01.I02
# @entry M01.F01.I03
# @entry M01.F02.I01
func card_count() -> int:
	return _valid_levels.size()


## 拒载原因行（冒烟断言口）。
func rejection_texts() -> Array[String]:
	return _rejections.duplicate()


## 屏上全部文本（冒烟断言口：PB 显示等）。
func texts() -> Array[String]:
	return _labels.duplicate()


## 键盘路由用：第一个合法关卡（无则空字典）。
func first_level() -> Dictionary:
	if _valid_levels.is_empty():
		return {}
	return _valid_levels[0]


## ——内部——

func _scan_level_paths(levels_dir: String) -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(levels_dir)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			paths.append("%s/%s" % [levels_dir, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


## 拒载原因诊断（只在 load_level 已拒后调用，为 UI 红字补具体错误枚举）：
## 复用 contract 的 validate/normalize/certify 公开面，不另写校验。
func _reject_reason(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "file-unreadable"
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return LEVEL_CONTRACT.ERROR_NOT_OBJECT
	var data: Dictionary = parsed
	var error := LEVEL_CONTRACT.validate(data)
	if error != "":
		return error
	var cert: Dictionary = REACHABILITY.certify(LEVEL_CONTRACT.normalize(data))
	if not bool(cert["ok"]):
		return LEVEL_CONTRACT.ERROR_UNREACHABLE % int(cert["unreachable"])
	return "unknown"


func _card(index: int, level: Dictionary, best: Dictionary) -> void:
	_valid_levels.append(level)
	var palette: Dictionary = THEMES.palette(level["theme"])
	var pb_text := "无记录"
	var entry: Variant = best.get(level["id"], null)
	if entry is Dictionary:
		pb_text = "PB %d ms" % int(entry.get("time_ms", 0))
	var card := Button.new()
	card.position = Vector2(60.0, CARD_TOP + CARD_STEP * index)
	card.size = Vector2(520.0, 60.0)
	card.text = "%d. %s · %s · certified ✓ · %s" % [index + 1, level["name"], level["theme"], pb_text]
	card.pressed.connect(_emit_selected.bind(level))
	add_child(card)
	_labels.append(card.text)
	# 主题色块（palette.platform）叠在卡左侧。
	var swatch := ColorRect.new()
	swatch.position = Vector2(70.0, CARD_TOP + CARD_STEP * index + 14.0)
	swatch.size = Vector2(32.0, 32.0)
	swatch.color = palette["platform"]
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(swatch)


func _emit_selected(level: Dictionary) -> void:
	level_selected.emit(level)


func _label(pos: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	_labels.append(text)
	return label
