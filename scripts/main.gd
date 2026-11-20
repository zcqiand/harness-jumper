extends Node2D
## 主场景：三态路由 select → game → result → select（Task 8 三态完整化）。
## select 挂 select_view（扫描关卡目录出卡+拒载红字），game 挂 game_view 收
## finished 广播，result 挂 result_view 展示结算。
## 落账判定只认 finished.violations（game_view 折算后的权威清单）：空才
## record_result+save_book，非空局不落账不报新纪录。
## Esc=放弃回选关不计档（game 态）/回选关（result 态）。
## storage 鸭子接口（load_text/save_text）可注入（headless 冒烟传内存假件），
## null 时 _ready 建 FileStorage（真 user:// 持久档）。

const GAME_VIEW := preload("res://scripts/game_view.gd")
const SELECT_VIEW := preload("res://scripts/select_view.gd")
const RESULT_VIEW := preload("res://scripts/result_view.gd")
const FILE_STORAGE := preload("res://scripts/file_storage.gd")
const SCOREBOOK := preload("res://scripts/scorebook.gd")
const THEMES := preload("res://scripts/themes.gd")

enum Screen { SELECT, GAME, RESULT }

## 测试注入口：与 file_storage.gd 同签名的鸭子接口；null → FileStorage。
var storage: RefCounted = null

var _screen: Screen = Screen.SELECT
var _book_storage = null
var _active_level: Dictionary = {}
var _game: Node2D = null
var _select_view: Control = null
var _result_view: Control = null


func _ready() -> void:
	_book_storage = storage if storage != null else FILE_STORAGE.new()
	_show_select()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back"):
		if _screen == Screen.GAME:
			_abort_game()  # 放弃：回选关不计档
		elif _screen == Screen.RESULT:
			_show_select()
	elif event.is_action_pressed("jump"):
		if _screen == Screen.SELECT:
			_start_level(_select_view.first_level())
		elif _screen == Screen.RESULT:
			_show_select()


## ——状态迁移——
# @impl M02.F04.I01
# @entry M02.F04.I02

func _show_select() -> void:
	_screen = Screen.SELECT
	_clear_ui()
	_select_view = SELECT_VIEW.new()
	_select_view.setup(_book_storage)
	_select_view.level_selected.connect(_start_level)
	add_child(_select_view)


func _start_level(level: Dictionary) -> void:
	if level.is_empty():
		push_error("关卡拒载（认证闸未过），见选关屏红字。")
		return
	_active_level = level
	_clear_ui()
	_screen = Screen.GAME
	_game = GAME_VIEW.new()
	_game.setup(level)
	_game.finished.connect(_on_game_finished)
	add_child(_game)


func _on_game_finished(result: Dictionary) -> void:
	var violations: Array = result.get("violations", [])
	var recorded: bool = violations.is_empty()
	var prev_best: Variant = null
	if recorded:
		var book: Dictionary = SCOREBOOK.load_book(_book_storage)
		var best: Dictionary = book.get("best", {})
		var entry: Variant = best.get(_active_level["id"], null)
		if entry is Dictionary:
			prev_best = entry.get("time_ms", null)
		book = SCOREBOOK.record_result(
			book, _active_level["id"], int(result.get("time_ms", 0)), true)
		# 写失败静默降级（scorebook 纪律）：本局照结算，下局再写。
		SCOREBOOK.save_book(book, _book_storage)
	if _game != null:
		_game.queue_free()
		_game = null
	_show_result(result, prev_best, recorded)


## 放弃：拆游戏屏回选关，成绩不结算不落账。
func _abort_game() -> void:
	if _game != null:
		_game.queue_free()
		_game = null
	_show_select()


func _show_result(result: Dictionary, prev_best: Variant, recorded: bool) -> void:
	_screen = Screen.RESULT
	_clear_ui()
	_result_view = RESULT_VIEW.new()
	var accent: Color = THEMES.palette(_active_level.get("theme", "classic"))["accent"]
	_result_view.setup(result, prev_best, recorded, accent)
	_result_view.rematch.connect(_rematch)
	_result_view.back_to_select.connect(_show_select)
	add_child(_result_view)


## 再战：同一关卡重开一局。
func _rematch() -> void:
	_start_level(_active_level)


## ——UI 件——

func _clear_ui() -> void:
	if _select_view != null:
		_select_view.queue_free()
		_select_view = null
	if _result_view != null:
		_result_view.queue_free()
		_result_view = null
