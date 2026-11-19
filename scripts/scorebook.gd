extends RefCounted
## 成绩册（纯逻辑）：读侧守卫 + PB 单槽。存档形状
## {"best": {level_id: {"time_ms": int, "saved_at": String}}}。
##
## 读侧守卫纪律（家族同款）：坏档（JSON 解析失败/顶层非对象/缺 best 键/best 非字典）
## 一律回退空册 {"best": {}}，不抛错——坏档只丢历史成绩，不挡本局开玩。
## 条目级坏形（best 内 value 非 Dictionary，如手改档 int）当缺失丢弃，档其余部分保留。
## record_result 纯：不改传入 book，duplicate 后改、返回新字典；只有更快才换
## PB 单槽，平局/更慢原样。写侧 save_book 失败随 storage 返回 false（静默降级）。
## storage 是鸭子接口（load_text/save_text 同签名即可），运行时注入 file_storage.gd
## 实例，测试注入内存假件。

const SAVE_PATH := "user://scorebook.json"


## 读册：storage.load_text 拿文本，逐层守卫，任何坏形 → 空册。
static func load_book(storage) -> Dictionary:
	var text: String = storage.load_text(SAVE_PATH)
	if text.is_empty():
		return {"best": {}}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return {"best": {}}
	var book: Dictionary = parsed
	if not (book.get("best", null) is Dictionary):
		return {"best": {}}
	# 条目级守卫（T6 挂账收口）：best 内 value 非 Dictionary（手改档 int 而非 dict）
	# 当缺失丢弃——不丢弃会让 record_result 对 int 调 .get 崩。
	var clean_best: Dictionary = {}
	for level_id in book["best"] as Dictionary:
		var entry: Variant = book["best"][level_id]
		if entry is Dictionary:
			clean_best[level_id] = entry
	book["best"] = clean_best
	return book


## 记成绩：assertions_ok=false → 原样返回（成绩不认可）；
## 关卡无 PB 或 time_ms 更快 → 更新单槽并附 saved_at；平局/更慢 → 原样。
static func record_result(book: Dictionary, level_id: String, time_ms: int, assertions_ok: bool) -> Dictionary:
	if not assertions_ok:
		return book
	var best: Dictionary = book.get("best", {})
	if best.has(level_id) and time_ms >= int(best[level_id].get("time_ms", time_ms)):
		return book
	var next: Dictionary = book.duplicate(true)
	if not (next.get("best", null) is Dictionary):
		next["best"] = {}
	next["best"][level_id] = {
		"time_ms": time_ms,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	return next


## 写册：JSON 序列化后交 storage.save_text；写失败（含打不开文件）透传 false。
static func save_book(book: Dictionary, storage) -> bool:
	return storage.save_text(SAVE_PATH, JSON.stringify(book))
