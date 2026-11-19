extends RefCounted
## 运动学纯函数模块：状态构造、跳跃、积分、落地判定、峰值高度。
## 双消费铁律（spec 裁定 1）：运行时（游戏屏）与可达性认证器只准调本模块，
## 认证的物理=玩家玩到的物理，结构上不分叉——两边各写一份积分即是事故。
##
## 调用纪律：step() 仅限 Node._physics_process 固定 dt 调用。
## 垂直积分用恒加速度精确的半步（梯形）公式：y += (vy + vy') * dt / 2，
## 恒 g 下与闭式位移 0.5*g*t^2 逐点吻合；可变/乱序 dt 会破坏该恒等式与确定性回放。
## 全部函数纯：不改传入 state / platforms，一律返回新字典。
## 坐标系：y 向下为正；x, y 是玩家脚底中心；platform 是 level_contract.normalize
## 产出的 {x, y, w, h} float 字典（y=顶面）。

const DT := 1.0 / 60.0
const PLAYER_HALF_W := 12.0
const PLAYER_HEIGHT := 24.0


## 初始状态：脚底中心 (x, y)，静止、落地。
static func new_state(x: float, y: float) -> Dictionary:
	return {"x": x, "y": y, "vx": 0.0, "vy": 0.0, "on_ground": true}


## 跳跃：仅落地态生效（vy=jump_speed、离地）；空中调用原样返回。
static func apply_jump(state: Dictionary, jump_speed: float) -> Dictionary:
	if not state.get("on_ground", false):
		return state
	var next := state.duplicate()
	next["vy"] = jump_speed
	next["on_ground"] = false
	return next


## 推进一帧。水平：vx += input_x * move_accel * dt 后钳 ±move_speed；
## input_x==0 且 on_ground 时以 move_accel 减速到 0，空中不减速。
## 垂直：半步积分（见头部注释）。params 取 level_contract.normalize 形状键。
static func step(state: Dictionary, params: Dictionary, input_x: float, dt: float) -> Dictionary:
	var next := state.duplicate()

	var vx: float = state["vx"] + input_x * params["move_accel"] * dt
	if input_x == 0.0 and state["on_ground"]:
		var decel: float = params["move_accel"] * dt
		if absf(vx) <= decel:
			vx = 0.0
		else:
			vx -= signf(vx) * decel
	vx = clampf(vx, -params["move_speed"], params["move_speed"])
	next["vx"] = vx
	next["x"] = state["x"] + vx * dt

	var vy: float = state["vy"] + params["gravity"] * dt
	next["vy"] = vy
	next["y"] = state["y"] + (state["vy"] + vy) * 0.5 * dt
	return next


## 落地判定：下落中（prev.vy>0）且脚底跨过平台顶面（prev.y ≤ top < curr.y）
## 且 curr.x ∈ [px - PLAYER_HALF_W, px + w + PLAYER_HALF_W]（撑脚余量）
## → {platform: 索引, land_x: curr.x, land_y: top}；否则 {}。
static func find_landing(prev: Dictionary, curr: Dictionary, platforms: Array) -> Dictionary:
	if prev["vy"] <= 0.0:
		return {}
	for i in platforms.size():
		var platform: Dictionary = platforms[i]
		var top: float = platform["y"]
		var spans: bool = prev["y"] <= top and top < curr["y"]
		var within: bool = curr["x"] >= platform["x"] - PLAYER_HALF_W \
			and curr["x"] <= platform["x"] + platform["w"] + PLAYER_HALF_W
		if spans and within:
			return {"platform": i, "land_x": curr["x"], "land_y": top}
	return {}


## 吸附落地：y=land_y、vy=0、on_ground=true。
static func land(state: Dictionary, landing: Dictionary) -> Dictionary:
	var next := state.duplicate()
	next["y"] = landing["land_y"]
	next["vy"] = 0.0
	next["on_ground"] = true
	return next


## 跳跃峰值高度：jump_speed² / (2g)（平方天然吞符号，传 -420 同 420）。
static func peak_height(jump_speed: float, gravity: float) -> float:
	return jump_speed * jump_speed / (2.0 * gravity)
