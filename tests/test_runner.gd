extends SceneTree
## headless 测试入口（exit code 是唯一真相）：
##   Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_runner.gd
## 自动发现 res://tests/test_*.gd（排除 runner 自身），逐个执行 run(failures)；
## 全绿打印 ALL PASS 并 quit(0)，否则逐行 FAIL: <label> 后 quit(1)。

const TESTS_DIR := "res://tests"
const SELF_PATH := "res://tests/test_runner.gd"
const HARNESS_PATH := "res://tests/harness.gd"


func _init() -> void:
	var failures: Array[String] = []
	var harness: GDScript = load(HARNESS_PATH)
	var suites := 0
	var checks := 0
	for path in _discover():
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures.append("测试脚本加载失败：%s" % path)
			continue
		suites += 1
		harness.count = 0
		var instance: RefCounted = script.new()
		var suite_failures := failures.size()
		instance.run(failures)
		checks += harness.count
		print("[suite] %s — %d checks, %d failed" % [
			path, harness.count, failures.size() - suite_failures,
		])
		if harness.count == 0:
			# 套件记 0 checks=红不是绿：run() 中途脚本崩（如 load() 得 null 后
			# 断言调用 SCRIPT ERROR 中止本套件）会留下 0 checks 0 failed 的
			# 假绿形态；GDScript 无 try/catch，0-checks 哨兵覆盖该洞。
			failures.append("suite %s recorded 0 checks (likely crashed mid-run)" % path)
	if suites == 0:
		# 零套件=红不是绿：发现环节打不开目录或一个 test_*.gd 都没匹配到时，
		# 绝不能落进空 failures 的 ALL PASS 假绿（exit code 是唯一真相）。
		failures.append("no test suites discovered")
	if failures.is_empty():
		print("ALL PASS (%d suites, %d checks)" % [suites, checks])
		quit(0)
	else:
		for failure in failures:
			print("FAIL: %s" % failure)
		print("FAILED (%d suites, %d checks, %d failures)" % [suites, checks, failures.size()])
		quit(1)


## 收集 res://tests/ 下全部 test_*.gd（排除 runner 自身），按名字排序保证输出稳定。
func _discover() -> Array[String]:
	var paths: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		print("FAIL: 测试目录打不开：%s" % TESTS_DIR)
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_") and file_name.ends_with(".gd"):
			var path := "%s/%s" % [TESTS_DIR, file_name]
			if path != SELF_PATH:
				paths.append(path)
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths
