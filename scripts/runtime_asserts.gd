extends RefCounted
## 运行时断言（认证第二闸，纯逻辑层）：峰值高度界 + 落点区间，正常玩法不可触发的
## 防御性断言（spec 裁定 3：触发即成绩不入档）。只判 bool 不收集——违例标签
## "peak-exceeded" / "landing-off-platform" 由调用方 append 进 new_violations() 产出的表。
##
## 双消费铁律同 kinematics：峰值界调 kinematics.peak_height、落点区间与
## find_landing 同款（±PLAYER_HALF_W 撑脚余量）——认证的物理=玩家玩到的物理。

const KINEMATICS := preload("res://scripts/kinematics.gd")

## 峰值容差：理论界 jump_speed²/(2·gravity) 之上允许的浮点/积分余量。
const PEAK_TOLERANCE := 2.0


## 峰值断言：observed_peak ≤ 理论界 + 容差（≤ 含等号）。
## level 取 level_contract.normalize 形状（只消费 gravity / jump_speed 数值键）；
## jump_speed 正负同结果（peak_height 平方吞符号）。
static func check_peak(observed_peak: float, level: Dictionary) -> bool:
	var cap: float = KINEMATICS.peak_height(level["jump_speed"], level["gravity"]) + PEAK_TOLERANCE
	return observed_peak <= cap


## 落点断言：land_x ∈ [x − PLAYER_HALF_W, x + w + PLAYER_HALF_W]——
## 与 kinematics.find_landing 的撑脚余量区间同款（含端点），两边不分叉。
## platform 取 normalize 产物平台项 {x, y, w, h}（本判定只消费 x / w）。
static func check_landing(land_x: float, platform: Dictionary) -> bool:
	return land_x >= platform["x"] - KINEMATICS.PLAYER_HALF_W \
		and land_x <= platform["x"] + platform["w"] + KINEMATICS.PLAYER_HALF_W


## 违例表收集器：每次本局断言检查开一个新空表，调用方按违例 append 标签，
## 结算面按表非空拒绝成绩入档。
static func new_violations() -> Array[String]:
	return []
