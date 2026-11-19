extends RefCounted
## 可达性判定器（认证第一闸）：加载时用关卡参数表驱动离散模拟，BFS 平台图
## 断言「从出生点出发每个平台都可达」；不可达关卡当场拒载并报平台序号。
## 认证物理=玩家玩到的物理（spec 裁定 1）：只调 kinematics 同一积分模块，
## 勿在此另写积分。输入策略集={-1,0,1}（裁定 9：只验人类可直接执行的输入）。
## level 须已 normalize（platforms 每项 {x,y,w,h} float 字典）。

const KINEMATICS := preload("res://scripts/kinematics.gd")

## 模拟超时（游戏秒）：防悬空平台死循环模拟。
const SIM_TIME_LIMIT := 3.0
## 模拟坠落死界：最低平台底边再往下这么多像素即判死（与全局约束一致）。
const DEATH_MARGIN := 800.0
## 跳跃边起脚点采样步长（像素）：沿平台顶面每 24px 采一个起脚点。
const EDGE_SAMPLE_STEP := 24.0

## 输入策略集：全程按满左 / 中性 / 按满右（裁定 9）。
const STRATEGIES: Array[float] = [-1.0, 0.0, 1.0]


## 认证：全平台可达 → {ok: true, unreachable: -1}；
## 否则 {ok: false, unreachable: 按序第一个够不到的平台索引}。
static func certify(level: Dictionary) -> Dictionary:
	var platforms: Array = level["platforms"]
	var spawn: Array = level["spawn"]
	var visited := {}
	var queue: Array[int] = []
	var start := _spawn_platform(spawn, platforms)
	if start >= 0:
		_mark(start, visited, queue)
	else:
		# spawn 在无平台处：以 y=spawn.y 虚地面为第 -1 节点
		queue.append(-1)
	var death_y := _death_y(spawn, platforms)
	while not queue.is_empty():
		var node: int = queue.pop_front()
		if node == -1:
			# 虚地面：无顶面可采样，出生点单点起跳 × 3 策略
			_visit_jumps(float(spawn[0]), float(spawn[1]), level, platforms, death_y, visited, queue)
			continue
		var p: Dictionary = platforms[node]
		var top: float = float(p["y"])
		# 跳跃边：沿顶面每 24px 采样起脚点 × 3 策略
		var samples := 1 + int(ceilf(float(p["w"]) / EDGE_SAMPLE_STEP))
		for j in samples:
			var x: float = float(p["x"]) + minf(j * EDGE_SAMPLE_STEP, float(p["w"]))
			_visit_jumps(x, top, level, platforms, death_y, visited, queue)
		# 坠落边：左右缘外 1px、vx=0 落下
		for x: float in [float(p["x"]) - 1.0, float(p["x"]) + float(p["w"]) + 1.0]:
			_mark(
				_simulate_until_landing(KINEMATICS.new_state(x, top), 0.0, level, platforms, death_y),
				visited, queue,
			)
	for i in platforms.size():
		if not visited.has(i):
			return {"ok": false, "unreachable": i}
	return {"ok": true, "unreachable": -1}


## spawn 脚底所站平台索引（脚底=顶面且 x 在顶面区间内）；无 → -1（虚地面）。
static func _spawn_platform(spawn: Array, platforms: Array) -> int:
	var sx: float = float(spawn[0])
	var sy: float = float(spawn[1])
	for i in platforms.size():
		var p: Dictionary = platforms[i]
		if float(p["y"]) == sy and sx >= float(p["x"]) and sx <= float(p["x"]) + float(p["w"]):
			return i
	return -1


## 模拟坠落死界 y：最低平台底边 + DEATH_MARGIN（无平台时以 spawn.y 兜底）。
static func _death_y(spawn: Array, platforms: Array) -> float:
	var bottom: float = float(spawn[1])
	for p in platforms as Array:
		bottom = maxf(bottom, float(p["y"]) + float(p["h"]))
	return bottom + DEATH_MARGIN


## 单个起脚点 × 3 策略模拟跳跃，命中平台全部登记入队。
static func _visit_jumps(x: float, top: float, level: Dictionary, platforms: Array, \
		death_y: float, visited: Dictionary, queue: Array[int]) -> void:
	for input_x in STRATEGIES:
		var state: Dictionary = KINEMATICS.apply_jump(
			KINEMATICS.new_state(x, top), float(level["jump_speed"]),
		)
		_mark(_simulate_until_landing(state, input_x, level, platforms, death_y), visited, queue)


## 登记命中平台；新平台入队继续传播。
static func _mark(landed: int, visited: Dictionary, queue: Array[int]) -> void:
	if landed < 0:
		return
	if not visited.has(landed):
		visited[landed] = true
		queue.append(landed)


## 离散模拟至落地/超时/坠入死界：命中返回平台索引，否则 -1。
## (prev, curr) 状态对逐帧喂 find_landing（下落判据 prev.vy>0），不自行另写积分。
static func _simulate_until_landing(state: Dictionary, input_x: float, level: Dictionary, \
		platforms: Array, death_y: float) -> int:
	var max_frames := int(SIM_TIME_LIMIT / KINEMATICS.DT)
	for i in max_frames:
		var prev: Dictionary = state
		var curr: Dictionary = KINEMATICS.step(state, level, input_x, KINEMATICS.DT)
		var hit: Dictionary = KINEMATICS.find_landing(prev, curr, platforms)
		if not hit.is_empty():
			return int(hit["platform"])
		state = curr
		if state["y"] > death_y:
			return -1
	return -1
