extends RefCounted
## 测试断言工具（静态函数）：失败只把 label 记进 failures，不中断套件；
## count 静态计数器供 runner 统计检查数（每套件开始前由 runner 清零）。

static var count: int = 0


static func assert_true(cond: bool, label: String, failures: Array[String]) -> void:
	count += 1
	if not cond:
		failures.append(label)


static func assert_eq(got: Variant, want: Variant, label: String, failures: Array[String]) -> void:
	count += 1
	if got != want:
		failures.append("%s（got=%s want=%s）" % [label, got, want])


static func assert_near(got: float, want: float, eps: float, label: String, failures: Array[String]) -> void:
	count += 1
	if absf(got - want) > eps:
		failures.append("%s（got=%f want=%f eps=%f）" % [label, got, want, eps])
