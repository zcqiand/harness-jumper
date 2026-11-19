extends RefCounted
## 运动学纯函数套件：常量/初始态/跳跃/积分/水平移动/落地判定/峰值高度，数值全钉。
## 积分公式钉：dt=1/60、gravity=980、初 vy=0 落 60 帧位移 = 0.5*980*1.0^2（t=1s 位移公式），
## 该断言倒逼 step() 用对恒定加速度精确的半步积分（可变 dt 会破坏此恒等式）。

const HARNESS_PATH := "res://tests/harness.gd"
const KINEMATICS_PATH := "res://scripts/kinematics.gd"

const DT := 1.0 / 60.0
const GRAVITY := 980.0
const MOVE_SPEED := 220.0
const MOVE_ACCEL := 2400.0


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var kin: GDScript = load(KINEMATICS_PATH)
	if kin == null:
		harness.assert_true(false, "kinematics.gd 加载失败", failures)
		return

	_test_constants(harness, kin, failures)
	_test_new_state(harness, kin, failures)
	_test_apply_jump(harness, kin, failures)
	_test_step_free_fall(harness, kin, failures)
	_test_step_horizontal(harness, kin, failures)
	_test_step_ground_decel(harness, kin, failures)
	_test_step_air_keep(harness, kin, failures)
	_test_step_pure(harness, kin, failures)
	_test_find_landing(harness, kin, failures)
	_test_land(harness, kin, failures)
	_test_peak_height(harness, kin, failures)


func _params() -> Dictionary:
	return {"gravity": GRAVITY, "move_speed": MOVE_SPEED, "move_accel": MOVE_ACCEL}


func _test_constants(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	harness.assert_near(kin.DT, 1.0 / 60.0, 0.000001, "DT = 1/60", failures)
	harness.assert_eq(kin.PLAYER_HALF_W, 12.0, "PLAYER_HALF_W = 12", failures)
	harness.assert_eq(kin.PLAYER_HEIGHT, 24.0, "PLAYER_HEIGHT = 24", failures)


func _test_new_state(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	var state: Dictionary = kin.new_state(40.0, 400.0)
	harness.assert_near(state["x"], 40.0, 0.001, "new_state x", failures)
	harness.assert_near(state["y"], 400.0, 0.001, "new_state y", failures)
	harness.assert_near(state["vx"], 0.0, 0.001, "new_state vx=0", failures)
	harness.assert_near(state["vy"], 0.0, 0.001, "new_state vy=0", failures)
	harness.assert_true(state["on_ground"], "new_state on_ground", failures)


func _test_apply_jump(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	# 落地态跳跃：vy=-420、离地
	var grounded: Dictionary = kin.new_state(40.0, 400.0)
	var jumped: Dictionary = kin.apply_jump(grounded, -420.0)
	harness.assert_near(jumped["vy"], -420.0, 0.001, "apply_jump vy=-420", failures)
	harness.assert_true(not jumped["on_ground"], "apply_jump leaves ground", failures)

	# 空中再跳：原样返回
	var airborne: Dictionary = kin.new_state(40.0, 400.0)
	airborne["on_ground"] = false
	airborne["vy"] = -100.0
	var rejumped: Dictionary = kin.apply_jump(airborne, -420.0)
	harness.assert_near(rejumped["vy"], -100.0, 0.001, "air re-jump vy unchanged", failures)
	harness.assert_true(not rejumped["on_ground"], "air re-jump still airborne", failures)


func _test_step_free_fall(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	# 自由落体：初 vy=0 落 60 帧（dt=1/60, gravity=980）→ 位移 = 0.5*980*1.0^2
	var state: Dictionary = kin.new_state(40.0, 0.0)
	state["on_ground"] = false
	for frame in range(60):
		state = kin.step(state, _params(), 0.0, DT)
	var delta: float = state["y"] - 0.0
	harness.assert_near(delta, 0.5 * 980.0 * 1.0 * 1.0, 0.01,
		"free fall 60 frames位移=0.5*g*t^2", failures)


func _test_step_horizontal(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	# input_x=1 从 vx=0 走 60 帧：加速 2400/s 早超 220，终 vx=220（钳 move_speed）
	var state: Dictionary = kin.new_state(40.0, 400.0)
	for frame in range(60):
		state = kin.step(state, _params(), 1.0, DT)
	harness.assert_near(state["vx"], MOVE_SPEED, 0.001, "input_x=1 60 frames vx=move_speed", failures)


func _test_step_ground_decel(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	# 地面减速：vx=220、input_x=0、on_ground，半秒（30 帧）内归 0
	var state: Dictionary = kin.new_state(40.0, 400.0)
	state["vx"] = MOVE_SPEED
	for frame in range(30):
		state = kin.step(state, _params(), 0.0, DT)
	harness.assert_eq(state["vx"], 0.0, "ground decel vx=0 within 0.5s", failures)


func _test_step_air_keep(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	# 空中保持：vx=220、input_x=0、on_ground=false，半秒 vx 不变
	var state: Dictionary = kin.new_state(40.0, 400.0)
	state["vx"] = MOVE_SPEED
	state["on_ground"] = false
	for frame in range(30):
		state = kin.step(state, _params(), 0.0, DT)
	harness.assert_near(state["vx"], MOVE_SPEED, 0.001, "air keep vx unchanged", failures)


func _test_step_pure(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	# 纯函数：step 不改传入 state（认证器与运行时共享此模块，互不踩内存）
	var state: Dictionary = kin.new_state(40.0, 400.0)
	state["vx"] = 100.0
	kin.step(state, _params(), 1.0, DT)
	harness.assert_near(state["x"], 40.0, 0.001, "step does not mutate input x", failures)
	harness.assert_near(state["vx"], 100.0, 0.001, "step does not mutate input vx", failures)


func _test_find_landing(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	var platforms: Array = [{"x": 0.0, "y": 400.0, "w": 640.0, "h": 40.0}]

	# 正例：prev.y=399 ≤ top=400 < curr.y=401，下落中，x 在撑脚范围 → 命中 platform 0
	var prev: Dictionary = kin.new_state(100.0, 399.0)
	prev["vy"] = 100.0
	prev["on_ground"] = false
	var curr: Dictionary = kin.new_state(100.0, 401.0)
	curr["vy"] = 159.0
	curr["on_ground"] = false
	var landing: Dictionary = kin.find_landing(prev, curr, platforms)
	harness.assert_eq(landing.get("platform", -1), 0, "find_landing hits platform 0", failures)
	harness.assert_near(landing.get("land_y", -1.0), 400.0, 0.001, "find_landing land_y=top", failures)
	harness.assert_near(landing.get("land_x", -1.0), 100.0, 0.001, "find_landing land_x=curr.x", failures)

	# 反例：上升中穿越（vy<0）→ {}
	var rising_prev: Dictionary = prev.duplicate()
	rising_prev["vy"] = -100.0
	var rising: Dictionary = kin.find_landing(rising_prev, curr, platforms)
	harness.assert_true(rising.is_empty(), "rising through top -> no landing", failures)

	# 反例：x 越界（右缘 640+12=652 之外）→ {}
	var offscreen_curr: Dictionary = curr.duplicate()
	offscreen_curr["x"] = 1000.0
	var outside: Dictionary = kin.find_landing(prev, offscreen_curr, platforms)
	harness.assert_true(outside.is_empty(), "x out of range -> no landing", failures)


func _test_land(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	var state: Dictionary = kin.new_state(100.0, 401.0)
	state["vy"] = 159.0
	state["on_ground"] = false
	var landed: Dictionary = kin.land(state, {"platform": 0, "land_x": 100.0, "land_y": 400.0})
	harness.assert_near(landed["y"], 400.0, 0.001, "land y=land_y", failures)
	harness.assert_near(landed["vy"], 0.0, 0.001, "land vy=0", failures)
	harness.assert_true(landed["on_ground"], "land on_ground=true", failures)


func _test_peak_height(harness: GDScript, kin: GDScript, failures: Array[String]) -> void:
	harness.assert_near(kin.peak_height(420.0, 980.0), 89.9, 0.1,
		"peak_height(420,980)=89.9±0.1", failures)
	# 符号语义：传 -420 同 420 同结果（内部平方）
	harness.assert_eq(
		kin.peak_height(-420.0, 980.0), kin.peak_height(420.0, 980.0),
		"peak_height sign-independent", failures,
	)
