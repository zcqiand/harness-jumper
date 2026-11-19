extends RefCounted
## 粒子对象池套件（落地尘土粒子复用，ch10 对象池教学）：池构造/acquire 耗尽
## （free 空 → -1，调用方静默丢弃本粒尘）/release 回池/双释放幂等。

const HARNESS_PATH := "res://tests/harness.gd"
const POOL_PATH := "res://scripts/particles_pool.gd"


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var pool_script: GDScript = load(POOL_PATH)
	if pool_script == null:
		harness.assert_true(false, "particles_pool.gd 加载失败", failures)
		return

	_test_new_pool(harness, pool_script, failures)
	_test_new_pool_zero(harness, pool_script, failures)
	_test_acquire_exhausts(harness, pool_script, failures)
	_test_acquire_marks_in_use(harness, pool_script, failures)
	_test_release_then_reacquire(harness, pool_script, failures)
	_test_double_release_idempotent(harness, pool_script, failures)
	_test_release_unknown_id(harness, pool_script, failures)


func _test_new_pool(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	var pool: Dictionary = pool_script.new_pool(3)
	harness.assert_eq(pool["free"], [0, 1, 2], "new_pool(3) free=[0,1,2]", failures)
	harness.assert_true((pool["in_use"] as Dictionary).is_empty(), "new_pool in_use 空", failures)


func _test_new_pool_zero(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	var pool: Dictionary = pool_script.new_pool(0)
	harness.assert_eq((pool["free"] as Array).size(), 0, "new_pool(0) free 空", failures)


func _test_acquire_exhausts(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	# capacity=2：发到 capacity-1 后下一发 -1（调用方静默丢弃本粒尘）
	var pool: Dictionary = pool_script.new_pool(2)
	harness.assert_eq(pool_script.acquire(pool), 0, "第 1 发 id=0", failures)
	harness.assert_eq(pool_script.acquire(pool), 1, "第 2 发 id=1（capacity-1）", failures)
	harness.assert_eq(pool_script.acquire(pool), -1, "池空 acquire → -1", failures)


func _test_acquire_marks_in_use(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	var pool: Dictionary = pool_script.new_pool(2)
	pool_script.acquire(pool)
	var in_use: Dictionary = pool["in_use"]
	harness.assert_true(in_use.has(0), "acquire 后 id 入 in_use", failures)


func _test_release_then_reacquire(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	# release 后可再 acquire 同 id（复用，不新造粒子）
	var pool: Dictionary = pool_script.new_pool(1)
	var first: int = pool_script.acquire(pool)
	pool_script.release(pool, first)
	harness.assert_eq(pool_script.acquire(pool), first, "release 后再 acquire 同 id", failures)


func _test_double_release_idempotent(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	# 双释放幂等：free 不重复入队
	var pool: Dictionary = pool_script.new_pool(2)
	pool_script.acquire(pool)
	pool_script.acquire(pool)
	pool_script.release(pool, 0)
	pool_script.release(pool, 0)
	harness.assert_eq(pool["free"], [0], "双释放 free 不重复入队", failures)
	var in_use: Dictionary = pool["in_use"]
	harness.assert_true(not in_use.has(0), "双释放后 id 不在 in_use", failures)


func _test_release_unknown_id(harness: GDScript, pool_script: GDScript, failures: Array[String]) -> void:
	# 释放从未 acquire 的 id：不进 free（守卫在 in_use 判定上）
	var pool: Dictionary = pool_script.new_pool(2)
	pool_script.release(pool, 5)
	harness.assert_eq(pool["free"], [0, 1], "释放未知 id 不进 free", failures)
