extends Node2D
## 主场景：三态路由 select → game → result → select。
## select 列关卡（jump 起局，认证闸拒载则停在选关并报错）；game 挂 game_view
## 收 finished 广播；result 展示结算（violations 非空=成绩不入档预告，落账归 Task 8）。
## Esc=放弃回选关不计档（只在 game 态生效；select 态无档可放）。

const GAME_VIEW := preload("res://scripts/game_view.gd")
const LEVEL_CONTRACT := preload("res://scripts/level_contract.gd")

const LEVEL_PATHS: Array[String] = ["res://data/levels/jump_001.json"]

enum Screen { SELECT, GAME, RESULT }

var _screen: Screen = Screen.SELECT
var _level_index := 0
var _game: Node2D = null
var _last_result: Dictionary = {}
var _select_ui: Control = null
var _result_ui: Control = null


func _ready() -> void:
	_show_select()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		if _screen == Screen.GAME:
			_abort_game()  # 放弃：回选关不计档
		elif _screen == Screen.RESULT:
			_show_select()
	elif event.is_action_pressed("jump"):
		if _screen == Screen.SELECT:
			_start_game()
		elif _screen == Screen.RESULT:
			_show_select()


## ——状态迁移——

func _show_select() -> void:
	_screen = Screen.SELECT
	_clear_ui()
	_select_ui = Control.new()
	_select_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_select_ui)
	_ui_text(_select_ui, Vector2(60.0, 110.0), "harness-jumper", 36)
	_ui_text(_select_ui, Vector2(60.0, 170.0), "物理契约即关卡：可达性认证 + 运行时断言双闸")
	for i in LEVEL_PATHS.size():
		var level := LEVEL_CONTRACT.load_level(LEVEL_PATHS[i])
		var row := "× 拒载（认证闸）"
		if not level.is_empty():
			row = "%d. %s [%s · certified ✓]" % [i + 1, level["name"], level["theme"]]
		_ui_text(_select_ui, Vector2(60.0, 230.0 + 28.0 * i), row)
	_ui_text(_select_ui, Vector2(60.0, 320.0), "Space 开始 · Esc 退出选关无效")


func _start_game() -> void:
	var level := LEVEL_CONTRACT.load_level(LEVEL_PATHS[_level_index])
	if level.is_empty():
		push_error("关卡拒载（认证闸未过），见上方错误。")
		return
	_clear_ui()
	_screen = Screen.GAME
	_game = GAME_VIEW.new()
	_game.setup(level)
	_game.finished.connect(_on_game_finished)
	add_child(_game)


func _on_game_finished(result: Dictionary) -> void:
	_last_result = result
	if _game != null:
		_game.queue_free()
		_game = null
	_show_result()


## 放弃：拆游戏屏回选关，成绩不结算不落账。
func _abort_game() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	_last_result = {}
	_show_select()


func _show_result() -> void:
	_screen = Screen.RESULT
	_clear_ui()
	_result_ui = Control.new()
	_result_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_result_ui)
	var violations: Array = _last_result.get("violations", [])
	var verdict := "成绩有效，可入档"
	if not violations.is_empty():
		verdict = "断言违例 %s —— 成绩不入档" % [", ".join(violations)]
	_ui_text(_result_ui, Vector2(60.0, 110.0), "通关！", 36)
	_ui_text(_result_ui, Vector2(60.0, 170.0), "时间 %d ms · 坠落 %d 次 · 峰值%s" % [
		int(_last_result.get("time_ms", 0)),
		int(_last_result.get("deaths", 0)),
		"合规" if bool(_last_result.get("peaks_ok", false)) else "越界",
	])
	_ui_text(_result_ui, Vector2(60.0, 200.0), verdict)
	_ui_text(_result_ui, Vector2(60.0, 260.0), "Space/Esc 回选关")


## ——UI 件——

func _clear_ui() -> void:
	if _select_ui != null:
		_select_ui.queue_free()
		_select_ui = null
	if _result_ui != null:
		_result_ui.queue_free()
		_result_ui = null


func _ui_text(parent: Control, pos: Vector2, text: String, font_size := 18) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label
