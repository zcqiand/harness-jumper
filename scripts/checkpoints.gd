extends RefCounted
## 检查点按序时序状态机（纯逻辑）：检查点必须按序激活，跳序=时序断言红
## （违例计数+1、目标位不激活、成绩不认可但流程不锁死——spec 裁定 4）；
## 激活中按序最新者即坠落重生点，无激活则回出生点。
##
## 全部函数纯：不改传入 state，trigger 一律 duplicate 后改、返回新字典。
## points 取 level_contract.normalize 产物形状（checkpoints 是 [x, y] 数组的数组），
## 转 Vector2 由本模块负责。

## 初始状态：next=待激活序号，activated=bool×count 激活位，violations=乱序触发计数。
static func new_state(count: int) -> Dictionary:
	var activated: Array[bool] = []
	for i in count:
		activated.append(false)
	return {"next": 0, "activated": activated, "violations": 0}


## 触发检查点：index==next → 激活该位、next+1；否则（乱序/重复触发）只计违例，
## 目标位不激活、next 不动。全激活后（next==count）再触发无位可激活，
## 按乱序同款计违例，防止越界。
static func trigger(state: Dictionary, index: int) -> Dictionary:
	var next := state.duplicate(true)
	var next_index: int = state["next"]
	var activated: Array[bool] = next["activated"]
	if index == next_index and next_index < activated.size():
		activated[index] = true
		next["next"] = next_index + 1
	else:
		next["violations"] = int(state["violations"]) + 1
	return next


## 坠落重生点：按激活顺序最新的检查点坐标（时序语义，非空间最近——
## 按序激活下最新激活位即进度最远者）；无任何激活 → spawn。
static func respawn_point(state: Dictionary, points: Array, spawn: Vector2) -> Vector2:
	var activated: Array = state["activated"]
	var latest := -1
	for i in activated.size():
		if activated[i]:
			latest = i
	if latest < 0 or latest >= points.size():
		return spawn
	var point: Array = points[latest]
	return Vector2(float(point[0]), float(point[1]))
