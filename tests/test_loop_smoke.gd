extends RefCounted
## Task 8 全流程冒烟套件：选关屏建出（卡数==合法关卡数、拒载红字报原因）→
## 进图 → 测试内直接 emit finished → 落账（内存假件 storage 注入）→ result 呈现。
## 另盖：violations 非空局不入档无新纪录、破 PB 覆盖、再战/回选关信号、选关屏 PB 显示。

const HARNESS_PATH := "res://tests/harness.gd"
const MAIN_PATH := "res://scripts/main.gd"
const SELECT_VIEW_PATH := "res://scripts/select_view.gd"
const RESULT_VIEW_PATH := "res://scripts/result_view.gd"
const LEVEL_CONTRACT_PATH := "res://scripts/level_contract.gd"
const SCOREBOOK_PATH := "res://scripts/scorebook.gd"
const LEVEL_PATH := "res://data/levels/jump_001.json"
const PROBE_DIR := "user://loop_probe_levels"


## 内联内存假件（test_scorebook 同款）：与 file_storage.gd 同签名的鸭子接口。
class MemStorage:
	extends RefCounted
	var store: Dictionary = {}

	func load_text(path: String) -> String:
		return store.get(path, "")

	func save_text(path: String, text: String) -> bool:
		store[path] = text
		return true

	func exists(path: String) -> bool:
		return store.has(path)


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var main_script: GDScript = load(MAIN_PATH)
	var select_script: GDScript = load(SELECT_VIEW_PATH)
	var result_script: GDScript = load(RESULT_VIEW_PATH)
	harness.assert_true(main_script != null, "main.gd 加载", failures)
	harness.assert_true(select_script != null, "select_view.gd 加载", failures)
	harness.assert_true(result_script != null, "result_view.gd 加载", failures)
	if main_script == null or select_script == null or result_script == null:
		return
	var scorebook: GDScript = load(SCOREBOOK_PATH)
	var contract: GDScript = load(LEVEL_CONTRACT_PATH)

	_test_select_screen(harness, select_script, contract, failures)
	_test_rejection_line(harness, select_script, contract, failures)
	_test_full_loop(harness, main_script, contract, scorebook, failures)


## 选关屏：现仓扫描——卡数==合法关卡数，无拒载行。
func _test_select_screen(harness: GDScript, select_script: GDScript, contract: GDScript,
		failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var select: Control = select_script.new()
	select.setup(storage)
	harness.assert_eq(select.card_count(), _valid_level_count(contract),
		"选关卡数==合法关卡数", failures)
	harness.assert_eq(select.rejection_texts().size(), 0, "现仓无拒载关卡", failures)
	select.free()


## 拒载路径：user:// 临时目录塞一个缺 platforms 的坏关卡 → 尾部红字一行报原因不崩。
func _test_rejection_line(harness: GDScript, select_script: GDScript, contract: GDScript,
		failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var err := DirAccess.make_dir_recursive_absolute(PROBE_DIR)
	harness.assert_true(err == Error.OK, "探针目录建出", failures)
	var bad := FileAccess.open(PROBE_DIR + "/bad.json", FileAccess.WRITE)
	if bad == null:
		harness.assert_true(false, "坏关卡文件写不出", failures)
		return
	bad.store_string('{"name": "bad"}')
	bad.close()
	var good_text := FileAccess.get_file_as_string(LEVEL_PATH)
	var good := FileAccess.open(PROBE_DIR + "/good.json", FileAccess.WRITE)
	if good == null:
		harness.assert_true(false, "好关卡文件写不出", failures)
		return
	good.store_string(good_text)
	good.close()

	var select: Control = select_script.new()
	select.setup(storage, PROBE_DIR)
	harness.assert_eq(select.card_count(), 1, "临时目录合法卡数==1", failures)
	var rejections: Array[String] = select.rejection_texts()
	harness.assert_eq(rejections.size(), 1, "拒载关卡红字一行", failures)
	if rejections.size() == 1:
		harness.assert_true((rejections[0] as String).contains("missing-field"),
			"拒载红字报原因（missing-field）", failures)
	select.free()

	DirAccess.remove_absolute(PROBE_DIR + "/bad.json")
	DirAccess.remove_absolute(PROBE_DIR + "/good.json")
	DirAccess.remove_absolute(PROBE_DIR)


## 完整循环：选关→进图→emit finished→落账→result→再战→违例局→回选关 PB 显示。
func _test_full_loop(harness: GDScript, main_script: GDScript, contract: GDScript,
		scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var main_node: Node2D = main_script.new()
	main_node.storage = storage
	main_node._ready()
	harness.assert_true(main_node._select_view != null, "main 启动进选关屏", failures)
	harness.assert_eq(main_node._screen, main_node.Screen.SELECT, "初始态 SELECT", failures)

	var level: Dictionary = contract.load_level(LEVEL_PATH)
	if level.is_empty():
		harness.assert_true(false, "jump_001 装载失败", failures)
		return
	main_node._select_view.level_selected.emit(level)
	harness.assert_eq(main_node._screen, main_node.Screen.GAME, "选卡后进 GAME", failures)
	harness.assert_true(main_node._game != null, "game_view 已挂载", failures)

	# 直通 goal（brief Step 3：测试内直接 emit finished）→ 落账 → result 呈现。
	main_node._game.finished.emit({"time_ms": 1500, "deaths": 0, "violations": [], "peaks_ok": true})
	harness.assert_eq(main_node._screen, main_node.Screen.RESULT, "finished 后进 RESULT", failures)
	harness.assert_eq(_book_time(scorebook, storage, "jump_001"), 1500, "干净局落账 1500", failures)
	var texts: Array[String] = main_node._result_view.texts()
	harness.assert_true(_has_containing(texts, "认证全绿"), "violations 空→认证全绿徽章", failures)
	harness.assert_true(_has_containing(texts, "新纪录"), "首局新纪录高亮", failures)
	harness.assert_true(_has_containing(texts, "再战"), "再战按钮建出", failures)
	harness.assert_true(_has_containing(texts, "回选关"), "回选关按钮建出", failures)

	# 再战：更快成绩 → 覆盖 PB。
	main_node._result_view.rematch.emit()
	harness.assert_eq(main_node._screen, main_node.Screen.GAME, "再战回 GAME", failures)
	# 注意：finished 后 main 拆屏置 _game=null，每局 emit 前须取当局引用
	# （取 Nil 上的 finished 是脚本错，会静默掐断本套件尾部=假绿形态）。
	var game2: Node2D = main_node._game
	game2.finished.emit({"time_ms": 1200, "deaths": 1, "violations": [], "peaks_ok": true})
	harness.assert_eq(_book_time(scorebook, storage, "jump_001"), 1200, "更快成绩覆盖 PB", failures)
	texts = main_node._result_view.texts()
	harness.assert_true(_has_containing(texts, "新纪录"), "破格局仍新纪录", failures)

	# 违例局：不入档、无新纪录、逐条红字+不入档提示。
	main_node._result_view.rematch.emit()
	harness.assert_eq(main_node._screen, main_node.Screen.GAME, "违例局进 GAME", failures)
	var game3: Node2D = main_node._game
	game3.finished.emit({"time_ms": 900, "deaths": 0,
		"violations": ["peak-exceeded", "landing-off-platform"], "peaks_ok": false})
	harness.assert_eq(_book_time(scorebook, storage, "jump_001"), 1200, "违例局不入档", failures)
	texts = main_node._result_view.texts()
	harness.assert_true(_has_containing(texts, "peak-exceeded"), "违例逐条红字①", failures)
	harness.assert_true(_has_containing(texts, "landing-off-platform"), "违例逐条红字②", failures)
	harness.assert_true(_has_containing(texts, "本局成绩不入档"), "不入档提示", failures)
	harness.assert_true(not _has_containing(texts, "新纪录"), "违例局无新纪录", failures)

	# 回选关：PB 时间随册刷新显示。
	main_node._result_view.back_to_select.emit()
	harness.assert_eq(main_node._screen, main_node.Screen.SELECT, "回选关", failures)
	harness.assert_true(_has_containing(main_node._select_view.texts(), "1200"),
		"选关屏 PB 时间显示", failures)

	# Esc 放弃路径：game 中放弃 → 回选关，成绩不结算不落档。
	main_node._select_view.level_selected.emit(contract.load_level(LEVEL_PATH))
	harness.assert_eq(main_node._screen, main_node.Screen.GAME, "放弃路径进 GAME", failures)
	main_node._abort_game()
	harness.assert_eq(main_node._screen, main_node.Screen.SELECT, "放弃回选关", failures)
	harness.assert_eq(_book_time(scorebook, storage, "jump_001"), 1200, "放弃局不计档", failures)
	main_node.free()


## ——工具——

func _valid_level_count(contract: GDScript) -> int:
	var dir := DirAccess.open("res://data/levels")
	if dir == null:
		return -1
	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json") \
				and not contract.load_level("res://data/levels/%s" % file_name).is_empty():
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


func _book_time(scorebook: GDScript, storage: MemStorage, level_id: String) -> int:
	var book: Dictionary = scorebook.load_book(storage)
	var best: Dictionary = book.get("best", {})
	var entry: Variant = best.get(level_id, null)
	if entry is Dictionary:
		return int(entry.get("time_ms", -1))
	return -1


func _has_containing(texts: Array[String], needle: String) -> bool:
	for text in texts:
		if text.contains(needle):
			return true
	return false
