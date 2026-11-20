extends Control
## 结算屏（Task 8）：通关时间/坠落/峰值 + 认证徽章（violations 空=「认证全绿 ✓」
## accent 色；非空=逐条红字+「本局成绩不入档」提示）+ PB 破格高亮
## （本次更快才「新纪录」，violations 非空局无新纪录）+ 再战/回选关按钮。

signal rematch
signal back_to_select

const REJECT_RED := Color(0.95, 0.35, 0.35)

var _labels: Array[String] = []


## 建整屏。prev_best_ms=落账前册内 PB（无则 null）；recorded=本局是否已落账
## （violations 空才 true，main 只认 finished.violations 权威清单）；
## accent=关卡主题色（main 经 themes.palette 取）。
func setup(result: Dictionary, prev_best_ms: Variant, recorded: bool, accent: Color) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var violations: Array = result.get("violations", [])
	var time_ms := int(result.get("time_ms", 0))

	_label(Vector2(60.0, 110.0), "通关！", 36, Color.WHITE)
	_label(Vector2(60.0, 170.0), "时间 %d ms · 坠落 %d 次 · 峰值%s" % [
		time_ms,
		int(result.get("deaths", 0)),
		"合规" if bool(result.get("peaks_ok", false)) else "越界",
	], 18, Color.WHITE)

	if violations.is_empty():
		_label(Vector2(60.0, 200.0), "认证全绿 ✓", 18, accent)
	else:
		# 逐条红字 + 不入档提示（成绩册判定只认 violations 空）。
		for i in violations.size():
			_label(Vector2(60.0, 200.0 + 24.0 * i), "× %s" % str(violations[i]), 16, REJECT_RED)
		_label(Vector2(60.0, 200.0 + 24.0 * violations.size()), "本局成绩不入档", 16, REJECT_RED)

	# PB 破格高亮：本次更快才「新纪录」（violations 非空局 recorded=false 恒无新纪录）。
	var record_y := 260.0 if violations.is_empty() else 200.0 + 24.0 * (violations.size() + 1)
	if recorded and (prev_best_ms == null or time_ms < int(prev_best_ms)):
		_label(Vector2(60.0, record_y), "新纪录！%d ms" % time_ms, 20, accent)
	elif recorded and prev_best_ms != null:
		_label(Vector2(60.0, record_y), "PB %d ms" % int(prev_best_ms), 18, Color.WHITE)

	_button("再战", Vector2(60.0, 330.0), Vector2(140.0, 44.0),
		func() -> void: rematch.emit())
	_button("回选关", Vector2(220.0, 330.0), Vector2(140.0, 44.0),
		func() -> void: back_to_select.emit())
	_label(Vector2(60.0, 400.0), "Space/Esc 回选关", 18, Color.WHITE)


## 屏上全部文本（冒烟断言口）。
func texts() -> Array[String]:
	return _labels.duplicate()


## ——内部——
# @entry M03.F01.I01
# @entry M03.F01.I02
# @entry M03.F01.I03
# @entry M03.F02.I02

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


func _button(text: String, pos: Vector2, size: Vector2, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = size
	button.text = text
	button.pressed.connect(on_pressed)
	add_child(button)
	_labels.append(text)
	return button
