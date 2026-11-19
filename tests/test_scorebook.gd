extends RefCounted
## 成绩册套件：读侧守卫（坏档一律空册，不抛错）+ PB 单槽（不快不记）+ 写失败守卫。
## storage 用内联内存假件 MemStorage（同签名三方法 load_text/save_text/exists），
## 测试不碰真 user://；save_text 失败由 fail_writes 开关模拟写侧守卫。

const HARNESS_PATH := "res://tests/harness.gd"
const SCOREBOOK_PATH := "res://scripts/scorebook.gd"
const STORAGE_PATH := "res://scripts/file_storage.gd"


## 内联内存假件：与 file_storage.gd 同签名的鸭子接口，store 字典即"磁盘"。
class MemStorage:
	extends RefCounted
	var store: Dictionary = {}
	var fail_writes: bool = false

	func load_text(path: String) -> String:
		return store.get(path, "")

	func save_text(path: String, text: String) -> bool:
		if fail_writes:
			return false
		store[path] = text
		return true

	func exists(path: String) -> bool:
		return store.has(path)


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var scorebook: GDScript = load(SCOREBOOK_PATH)
	if scorebook == null:
		harness.assert_true(false, "scorebook.gd 加载失败", failures)
		return

	_test_save_path(harness, scorebook, failures)
	_test_load_missing(harness, scorebook, failures)
	_test_load_bad_json(harness, scorebook, failures)
	_test_load_not_object(harness, scorebook, failures)
	_test_load_best_not_dict(harness, scorebook, failures)
	_test_load_missing_best_key(harness, scorebook, failures)
	_test_load_bad_entry_dropped(harness, scorebook, failures)
	_test_load_valid(harness, scorebook, failures)
	_test_record_rejected(harness, scorebook, failures)
	_test_record_new_level(harness, scorebook, failures)
	_test_record_faster_overrides(harness, scorebook, failures)
	_test_record_slower_keeps(harness, scorebook, failures)
	_test_record_tie_keeps(harness, scorebook, failures)
	_test_record_pure(harness, scorebook, failures)
	_test_save_book_roundtrip(harness, scorebook, failures)
	_test_save_book_write_failure(harness, scorebook, failures)
	_test_file_storage(harness, failures)


func _test_save_path(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	harness.assert_eq(scorebook.SAVE_PATH, "user://scorebook.json", "SAVE_PATH 钉值", failures)


func _test_load_missing(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	# 档不存在（load_text=""）→ 空册
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, {"best": {}}, "缺档 → 空册", failures)


func _test_load_bad_json(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	storage.store[scorebook.SAVE_PATH] = "not json{"
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, {"best": {}}, "坏 JSON → 空册", failures)


func _test_load_not_object(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	# 合法 JSON 但顶层不是对象（数组）→ 空册
	var storage: MemStorage = MemStorage.new()
	storage.store[scorebook.SAVE_PATH] = "[1,2,3]"
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, {"best": {}}, "非 Dictionary 顶屋 → 空册", failures)


func _test_load_best_not_dict(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	storage.store[scorebook.SAVE_PATH] = '{"best": 3}'
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, {"best": {}}, "best 非字典 → 空册", failures)


func _test_load_missing_best_key(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	storage.store[scorebook.SAVE_PATH] = '{"other": 1}'
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, {"best": {}}, "缺 best 键 → 空册", failures)


func _test_load_bad_entry_dropped(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	# 条目级坏形守卫（T6 挂账）：best 内 value 非 Dictionary（手改档 int 而非 dict）
	# 当缺失丢弃——否则 record_result 对 int 调 .get 崩。
	var storage: MemStorage = MemStorage.new()
	storage.store[scorebook.SAVE_PATH] = '{"best": {"jump_001": 999}}'
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, {"best": {}}, "best 条目非字典 → 条目丢弃", failures)
	var recorded: Dictionary = scorebook.record_result(book, "jump_001", 1500, true)
	harness.assert_eq(int(recorded["best"]["jump_001"]["time_ms"]), 1500, "坏条目丢弃后可正常入册", failures)
	storage.store[scorebook.SAVE_PATH] = '{"best": {"jump_001": {"time_ms": 1200, "saved_at": "x"}, "jump_002": 42}}'
	var mixed: Dictionary = scorebook.load_book(storage)
	harness.assert_true(mixed["best"].has("jump_001"), "好坏混合档：好条目保留", failures)
	harness.assert_true(not mixed["best"].has("jump_002"), "好坏混合档：坏条目丢弃", failures)


func _test_load_valid(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	# time_ms 写 1234.0（float）：JSON.parse_string 把一切数字升为 float，
	# 好档读回的形状即 float 形——钉此事实，record_result 侧 int() 收敛。
	var expected: Dictionary = {
		"best": {"jump_001": {"time_ms": 1234.0, "saved_at": "2026-01-01T08:00:00"}},
	}
	storage.store[scorebook.SAVE_PATH] = JSON.stringify(expected)
	var book: Dictionary = scorebook.load_book(storage)
	harness.assert_eq(book, expected, "好档原样读回", failures)


func _test_record_rejected(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	# assertions_ok=false → 成绩不认可，原样返回
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	var result: Dictionary = scorebook.record_result(book, "jump_001", 1500, false)
	harness.assert_eq(result, {"best": {}}, "assertions_ok=false 不记", failures)


func _test_record_new_level(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	var result: Dictionary = scorebook.record_result(book, "jump_001", 1500, true)
	var best: Dictionary = result["best"]
	harness.assert_true(best.has("jump_001"), "新关卡入册", failures)
	harness.assert_eq(int(best["jump_001"]["time_ms"]), 1500, "新关卡 time_ms", failures)
	harness.assert_true(
		best["jump_001"]["saved_at"] is String and not (best["jump_001"]["saved_at"] as String).is_empty(),
		"saved_at 非空字符串", failures,
	)


func _test_record_faster_overrides(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	book = scorebook.record_result(book, "jump_001", 1500, true)
	var faster: Dictionary = scorebook.record_result(book, "jump_001", 1200, true)
	harness.assert_eq(int(faster["best"]["jump_001"]["time_ms"]), 1200, "快于 PB 覆盖", failures)


func _test_record_slower_keeps(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	book = scorebook.record_result(book, "jump_001", 1500, true)
	var slower: Dictionary = scorebook.record_result(book, "jump_001", 2000, true)
	harness.assert_eq(slower, book, "慢于 PB 原样", failures)


func _test_record_tie_keeps(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	book = scorebook.record_result(book, "jump_001", 1500, true)
	var tie: Dictionary = scorebook.record_result(book, "jump_001", 1500, true)
	harness.assert_eq(tie, book, "平局原样", failures)


func _test_record_pure(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	# 纯函数：record_result 不 mutate 传入 book
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = scorebook.load_book(storage)
	book = scorebook.record_result(book, "jump_001", 1500, true)
	var before: Dictionary = book.duplicate(true)
	scorebook.record_result(book, "jump_001", 1000, true)
	harness.assert_eq(book, before, "record_result 不改传入 book", failures)


func _test_save_book_roundtrip(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	var storage: MemStorage = MemStorage.new()
	var book: Dictionary = {"best": {"jump_001": {"time_ms": 1234, "saved_at": "2026-01-01T08:00:00"}}}
	harness.assert_true(scorebook.save_book(book, storage), "save_book 成功 true", failures)
	harness.assert_true(storage.exists(scorebook.SAVE_PATH), "假件磁盘有档", failures)
	var loaded: Dictionary = scorebook.load_book(storage)
	# JSON 数字面升 float：读回 time_ms=1234.0，语义等值（record_result int() 收敛）
	harness.assert_eq(int(loaded["best"]["jump_001"]["time_ms"]), 1234, "写后读回 time_ms 等值", failures)
	harness.assert_eq(loaded["best"]["jump_001"]["saved_at"], "2026-01-01T08:00:00", "写后读回 saved_at", failures)
	harness.assert_true(loaded["best"].has("jump_001"), "写后读回关卡键在册", failures)


func _test_save_book_write_failure(harness: GDScript, scorebook: GDScript, failures: Array[String]) -> void:
	# 写侧守卫：storage.save_text 失败 → save_book false（静默降级不抛错）
	var storage: MemStorage = MemStorage.new()
	storage.fail_writes = true
	var book: Dictionary = {"best": {}}
	harness.assert_true(
		not scorebook.save_book(book, storage), "写失败 → save_book false", failures,
	)


func _test_file_storage(harness: GDScript, failures: Array[String]) -> void:
	# 运行时实现的只读面 + 写失败守卫（真 user:// 写路径不测，内存假件覆盖签名面）
	var storage: GDScript = load(STORAGE_PATH)
	if storage == null:
		harness.assert_true(false, "file_storage.gd 加载失败", failures)
		return
	var impl: RefCounted = storage.new()
	harness.assert_true(impl.exists("res://project.godot"), "exists 命中 res://project.godot", failures)
	harness.assert_true(
		not impl.exists("res://no_such_file_probe.txt"), "exists 不存在 → false", failures,
	)
	harness.assert_true(
		not (impl.load_text("res://project.godot") as String).is_empty(),
		"load_text 读到非空文本", failures,
	)
	harness.assert_eq(impl.load_text("res://no_such_file_probe.txt"), "", "load_text 不存在 → 空串", failures)
	harness.assert_true(
		not impl.save_text("res://no_such_dir_probe/x.txt", "x"),
		"save_text 目录不存在 → false（写失败守卫）", failures,
	)
