extends RefCounted
## 尘土粒子对象池（纯逻辑，ch10 对象池教学）：落地时喷的尘土粒子预先造满
## capacity 颗，运行时只借还、不再实例化——实例化卡帧是对象池要治的病。
##
## 池形状：{free: [0..capacity-1] 待借 id 队列, in_use: {id: true} 借出登记}。
## acquire free 空 → -1，调用方静默丢弃本粒尘（尘土少一颗无感，不值得排队等）；
## release 把 id 回 free，双释放幂等（守卫在 in_use 登记：不在借出册的 id 不回队，
## 防同 id 占两格后被借两次）。

## 建池：id 0..capacity-1 全部待借。
static func new_pool(capacity: int) -> Dictionary:
	var free: Array[int] = []
	for i in capacity:
		free.append(i)
	return {"free": free, "in_use": {}}


## 借一颗：free 空 → -1（调用方静默丢弃本粒尘）；否则弹出最小 id 并登记借出。
static func acquire(pool: Dictionary) -> int:
	var free: Array = pool["free"]
	if free.is_empty():
		return -1
	var id: int = free.pop_front()
	pool["in_use"][id] = true
	return id


## 还一颗：仅登记在借出册的 id 回队（双释放/未知 id 幂等跳过）。
# @impl M04.F03.I01
static func release(pool: Dictionary, id: int) -> void:
	var in_use: Dictionary = pool["in_use"]
	if not in_use.has(id):
		return
	in_use.erase(id)
	pool["free"].append(id)
