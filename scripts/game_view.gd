extends Node2D
## 游戏屏：把 Task 2-6 的纯逻辑模块接成可玩的一关——「物理契约即关卡」的运行面。
##
## 确定性铁律（Review Focus 首条）：_physics_process 只以 kinematics.DT 固定步长
## 调 tick()，delta 一律弃用——认证的物理=运行的物理，帧率漂移会破坏半步积分
## 恒等式与确定性回放；本脚本禁 _process。
##
## 输入→tick(input_x, jump_pressed)（内部可测路径，headless 冒烟直接逐帧调用）：
## 水平轴取整钳 {-1,0,1}；跳跃沿 edge（pressed 本帧且 on_ground），v1 单一固定跳；
## 落地 find_landing→land + 尘土池同帧借还 + 峰值/落点双断言（违例 append 进表）；
## 检查点按序触发；坠落出底界 deaths+1 回 respawn_point；触 goal emit finished。
## 成绩落账（record_result）属 Task 8，本屏只广播。

signal finished(result: Dictionary)

const THEMES := preload("res://scripts/themes.gd")
const KINEMATICS := preload("res://scripts/kinematics.gd")
const RUNTIME_ASSERTS := preload("res://scripts/runtime_asserts.gd")
const CHECKPOINTS := preload("res://scripts/checkpoints.gd")
const PARTICLES_POOL := preload("res://scripts/particles_pool.gd")

const VIEW_W := 640.0
const VIEW_H := 480.0
const DT := KINEMATICS.DT
## 坠落底界：低于最低平台面再多留余量即判坠亡。
const FALL_Y := 560.0
## 检查点/终点旗触发半径（px）。
const TOUCH_RADIUS := 24.0
const DUST_CAPACITY := 12
## 未激活检查点标记的灰。
const CP_INACTIVE_COLOR := Color(0.55, 0.55, 0.55, 0.9)

var _level: Dictionary = {}
var _palette: Dictionary = {}
var _state: Dictionary = {}
var _cp_state: Dictionary = {}
var _violations: Array[String] = []
var _deaths := 0
var _accumulated_dt := 0.0
var _timing := false
var _ended := false
## 首帧弃跳跃输入：选关页那一下 Space 不带进游戏（edge 泄漏防护）。
var _grace_ticks := 1
var _airborne := false
var _air_base_y := 0.0
var _air_peak := 0.0
## 脚下支撑面顶 y（最近一次落地的 land_y；静立复核探针用）。
var _ground_top := 0.0

var _player: Node2D
var _platform_nodes: Array[ColorRect] = []
var _cp_markers: Array[ColorRect] = []
var _dust_nodes: Array[ColorRect] = []
var _dust_pool: Dictionary = {}
var _hud_time: Label
var _hud_deaths: Label


## 接 normalize 后契约并搭建整屏（平台/终点旗/检查点标记/玩家/尘土池/HUD/触屏钮）。
func setup(level: Dictionary) -> void:
	_level = level.duplicate(true)
	_palette = THEMES.palette(_level["theme"])
	var spawn: Array = _level["spawn"]
	_state = KINEMATICS.new_state(float(spawn[0]), float(spawn[1]))
	_ground_top = float(spawn[1])
	_cp_state = CHECKPOINTS.new_state((_level["checkpoints"] as Array).size())
	_violations = RUNTIME_ASSERTS.new_violations()
	_build_scene()


## 固定步长推进（唯一物理入口；_physics_process 与冒烟测试都走这里）。
func tick(input_x: int, jump_pressed: bool) -> void:
	if _ended:
		return
	if _grace_ticks > 0:
		_grace_ticks -= 1
		jump_pressed = false
	var axis := clampi(input_x, -1, 1)
	if not _timing and (axis != 0 or jump_pressed):
		_timing = true  # 计时锚：首次输入起表，待命不起表（spec 裁定 14）
	if _timing:
		_accumulated_dt += DT

	if jump_pressed and _state["on_ground"]:
		_state = KINEMATICS.apply_jump(_state, _level["jump_speed"])
		_airborne = true
		_air_base_y = _state["y"]
		_air_peak = 0.0

	var prev := _state
	_state = KINEMATICS.step(_state, _level, float(axis), DT)
	if bool(_state["on_ground"]):
		# 静立支撑复核（落地语义仍单源 find_landing，不另写碰撞）：
		# 静止态首帧 prev.vy=0 不满足下落判据（prev.vy>0），且 y 已沉入顶面下方
		# （prev.y<=top 永不再真）——以顶面同点探针（vy 经一帧重力已积为正）配对
		# 喂入同一 find_landing：命中=仍被支撑，吸回顶面；落空=走下边缘转下坠。
		var probe := {"x": _state["x"], "y": _ground_top, "vy": _state["vy"], "on_ground": false}
		var support := KINEMATICS.find_landing(probe, _state, _level["platforms"])
		if support.is_empty():
			_state["on_ground"] = false
			_airborne = true
			_air_base_y = _ground_top
			_air_peak = 0.0
		else:
			_state = KINEMATICS.land(_state, support)
	else:
		var landing := KINEMATICS.find_landing(prev, _state, _level["platforms"])
		if not landing.is_empty():
			_state = KINEMATICS.land(_state, landing)
			_ground_top = float(landing["land_y"])
			_airborne = false
			_spawn_dust(Vector2(landing["land_x"], landing["land_y"]))
			if not RUNTIME_ASSERTS.check_peak(_air_peak, _level):
				_violations.append("peak-exceeded")
			var platform: Dictionary = _level["platforms"][int(landing["platform"])]
			if not RUNTIME_ASSERTS.check_landing(landing["land_x"], platform):
				_violations.append("landing-off-platform")
	if _airborne:
		_air_peak = maxf(_air_peak, _air_base_y - _state["y"])

	_touch_checkpoints()
	_touch_goal()
	if not _ended:
		_check_fall()
	_sync_view()


func _physics_process(_delta: float) -> void:
	# delta 弃用：运动学只认 kinematics.DT 固定步长（确定性铁律）。
	if _ended:
		return
	var axis := clampf(Input.get_axis("move_left", "move_right"), -1.0, 1.0)
	tick(roundi(axis), Input.is_action_just_pressed("jump"))


## ——冒烟/测试取数口——

func player_state() -> Dictionary:
	return _state


func platform_node_count() -> int:
	return _platform_nodes.size()


func is_resting() -> bool:
	return bool(_state.get("on_ground", false))


## ——场景搭建——

func _build_scene() -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(VIEW_W, VIEW_H)
	background.color = _palette["bg"]
	add_child(background)

	for platform in _level["platforms"] as Array:
		var rect := ColorRect.new()
		rect.position = Vector2(platform["x"], platform["y"])
		rect.size = Vector2(platform["w"], platform["h"])
		rect.color = _palette["platform"]
		add_child(rect)
		_platform_nodes.append(rect)

	var goal: Variant = _level["goal"]
	if goal != null:
		_goal_node(Vector2(float(goal[0]), float(goal[1])))

	var checkpoints: Array = _level["checkpoints"]
	for i in checkpoints.size():
		var marker := ColorRect.new()
		var point: Array = checkpoints[i]
		marker.position = Vector2(float(point[0]) - 6.0, float(point[1]) - 6.0)
		marker.size = Vector2(12.0, 12.0)
		marker.color = CP_INACTIVE_COLOR
		add_child(marker)
		_cp_markers.append(marker)

	_player = Node2D.new()
	var body := ColorRect.new()
	body.position = Vector2(-KINEMATICS.PLAYER_HALF_W, -KINEMATICS.PLAYER_HEIGHT)
	body.size = Vector2(KINEMATICS.PLAYER_HALF_W * 2.0, KINEMATICS.PLAYER_HEIGHT)
	body.color = _palette["player"]
	_player.add_child(body)
	add_child(_player)

	for i in DUST_CAPACITY:
		var dust := ColorRect.new()
		dust.position = Vector2(-100.0, -100.0)
		dust.size = Vector2(6.0, 6.0)
		dust.color = _palette["player"]
		dust.visible = false
		add_child(dust)
		_dust_nodes.append(dust)
	_dust_pool = PARTICLES_POOL.new_pool(DUST_CAPACITY)

	_build_hud()
	_build_touch_controls()
	_sync_view()


func _goal_node(pos: Vector2) -> void:
	var pole := ColorRect.new()
	pole.position = pos + Vector2(-3.0, -30.0)
	pole.size = Vector2(6.0, 30.0)
	pole.color = _palette["accent"]
	add_child(pole)
	var flag := ColorRect.new()
	flag.position = pos + Vector2(3.0, -30.0)
	flag.size = Vector2(16.0, 10.0)
	flag.color = _palette["accent"]
	add_child(flag)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_text(layer, Vector2(12.0, 8.0), "关卡 %s · %s" % [_level["name"], _level["id"]])
	_hud_text(layer, Vector2(12.0, 32.0), "%s · certified ✓" % _level["theme"], _palette["accent"])
	_hud_time = _hud_text(layer, Vector2(12.0, 56.0), "时间 0 ms")
	_hud_deaths = _hud_text(layer, Vector2(12.0, 80.0), "坠落 0")
	_hud_text(layer, Vector2(540.0, 8.0), "Esc 放弃")


func _hud_text(layer: CanvasLayer, pos: Vector2, text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	layer.add_child(label)
	return label


## 触屏钮（拇指区）：左下左右、右下跳；经 action 进 Input 轴/edge，与键盘同路。
func _build_touch_controls() -> void:
	_touch_button("move_left", Vector2(44.0, 444.0), Vector2(36.0, 32.0))
	_touch_button("move_right", Vector2(140.0, 444.0), Vector2(36.0, 32.0))
	_touch_button("jump", Vector2(596.0, 444.0), Vector2(36.0, 32.0))


func _touch_button(action: String, center: Vector2, half: Vector2) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	button.action = action
	button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	var shape := RectangleShape2D.new()
	shape.size = half * 2.0
	button.shape = shape
	button.position = center
	add_child(button)
	return button


## ——逐帧子步骤——

func _touch_checkpoints() -> void:
	var points: Array = _level["checkpoints"]
	var activated: Array = _cp_state["activated"]
	var pos := Vector2(_state["x"], _state["y"])
	for i in points.size():
		if activated[i]:
			continue
		var point: Array = points[i]
		var center := Vector2(float(point[0]), float(point[1]))
		if center.distance_to(pos) <= TOUCH_RADIUS:
			_cp_state = CHECKPOINTS.trigger(_cp_state, i)
			_cp_markers[i].color = _palette["accent"]


func _touch_goal() -> void:
	var goal: Variant = _level["goal"]
	if goal == null:
		return
	var point: Array = goal
	var center := Vector2(float(point[0]), float(point[1]))
	if center.distance_to(Vector2(_state["x"], _state["y"])) > TOUCH_RADIUS:
		return
	_ended = true
	# finished.violations = 本局认证唯一权威清单：双闸违例之外，检查点乱序计数
	# （checkpoints.trigger 产出，spec 裁定 4 乱序=成绩不认可）一并折算成标签入表，
	# 防 Task 8 只认 finished 时把乱序局干净入档。
	var violations := _violations.duplicate()
	if int(_cp_state["violations"]) > 0:
		violations.append("checkpoint-out-of-order")
	finished.emit({
		"time_ms": int(_accumulated_dt * 1000.0),
		"deaths": _deaths,
		"violations": violations,
		"peaks_ok": not violations.has("peak-exceeded"),
	})


func _check_fall() -> void:
	if _state["y"] <= FALL_Y:
		return
	_deaths += 1
	var spawn: Array = _level["spawn"]
	var respawn := CHECKPOINTS.respawn_point(
		_cp_state, _level["checkpoints"], Vector2(float(spawn[0]), float(spawn[1])))
	_state = KINEMATICS.new_state(respawn.x, respawn.y)
	_ground_top = respawn.y
	_airborne = false
	_air_peak = 0.0


## 尘土：池借还（占位实现——同帧借还，brief Step 2；视觉细化随行）。
func _spawn_dust(pos: Vector2) -> void:
	var id := PARTICLES_POOL.acquire(_dust_pool)
	if id < 0:
		return
	_dust_nodes[id].position = pos + Vector2(-3.0, 0.0)
	PARTICLES_POOL.release(_dust_pool, id)


func _sync_view() -> void:
	_player.position = Vector2(_state["x"], _state["y"])
	_hud_time.text = "时间 %d ms" % int(_accumulated_dt * 1000.0)
	_hud_deaths.text = "坠落 %d" % _deaths
