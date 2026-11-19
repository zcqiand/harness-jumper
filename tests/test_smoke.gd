extends RefCounted
## 冒烟套件：证明 runner 能发现 res://tests/test_*.gd 并收进执行。
## 约定：每个测试套件 extends RefCounted 且有 run(failures) -> void；
## 基建脚本一律 load() 按路径取（--script 模式下 class_name 全局注册不可靠）。

const HARNESS_PATH := "res://tests/harness.gd"


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	harness.assert_true(true, "smoke passes", failures)
	harness.assert_near(1.0 + 0.5, 1.5, 0.001, "near works", failures)
