extends RefCounted
## 游戏屏冒烟套件（brief Step 4）：实例化 game_view，喂 normalize 后 jump_001，
## 直接调内部 tick 路径逐帧推进（headless 不依赖 SceneTree 帧推进）。
## 断言：装载不崩、player 状态字典存在、平台节点数==契约平台数、
## 30 帧步进后仍立在出生平台、触 goal 发 finished 且结果形状完整。

const HARNESS_PATH := "res://tests/harness.gd"
const GAME_VIEW_PATH := "res://scripts/game_view.gd"
const LEVEL_CONTRACT_PATH := "res://scripts/level_contract.gd"
const LEVEL_PATH := "res://data/levels/jump_001.json"


func run(failures: Array[String]) -> void:
	var harness: GDScript = load(HARNESS_PATH)
	var game_view_script: GDScript = load(GAME_VIEW_PATH)
	harness.assert_true(game_view_script != null, "game_view script loads", failures)
	if game_view_script == null:
		return
	var contract: GDScript = load(LEVEL_CONTRACT_PATH)
	var level: Dictionary = contract.load_level(LEVEL_PATH)
	harness.assert_true(not level.is_empty(), "jump_001 passes certification gate", failures)
	if level.is_empty():
		return
	var view: Node2D = game_view_script.new()
	view.setup(level)

	harness.assert_eq(view.platform_node_count(), (level["platforms"] as Array).size(),
		"platform node count == contract platform count", failures)
	harness.assert_true(not view.player_state().is_empty(), "player state dict exists", failures)

	for i in 30:
		view.tick(0, false)
	harness.assert_true(not view.player_state().is_empty(), "state survives 30 ticks", failures)
	harness.assert_true(view.is_resting(), "resting on spawn platform after 30 ticks", failures)

	# 尘土可见化（终审 Important #2）：起跳落地喷尘土——借出可见，TTL 过后隐身还池。
	harness.assert_eq(view.dust_visible_count(), 0, "idle run shows no dust", failures)
	view.tick(0, true)  # 出生点起跳
	var dust_wait := 0
	while not view.is_resting() and dust_wait < 200:
		view.tick(0, false)  # 抛物线回落出生平台，落地帧喷尘土
		dust_wait += 1
	harness.assert_true(view.is_resting(), "dust probe lands back on spawn platform", failures)
	harness.assert_true(view.dust_visible_count() >= 1, "dust visible right after landing", failures)
	harness.assert_true(view.dust_pool_free_count() < view.DUST_CAPACITY,
		"dust borrowed from pool while visible", failures)
	for i in view.DUST_TTL_TICKS + 1:
		view.tick(0, false)  # TTL 全程 + 1 帧
	harness.assert_eq(view.dust_visible_count(), 0, "dust hidden after TTL expiry", failures)
	harness.assert_eq(view.dust_pool_free_count(), view.DUST_CAPACITY,
		"dust returned to pool after TTL expiry", failures)

	# 触 goal → finished({time_ms, deaths, violations, peaks_ok}) 恰发一次。
	var results: Array = []
	view.finished.connect(func(result: Dictionary) -> void: results.append(result))
	view.player_state()["x"] = 590.0
	view.player_state()["y"] = 140.0
	view.tick(0, false)
	harness.assert_eq(results.size(), 1, "goal touch emits finished exactly once", failures)
	if results.size() == 1:
		var result: Dictionary = results[0]
		harness.assert_true(result.has_all(["time_ms", "deaths", "violations", "peaks_ok"]),
			"result carries full shape", failures)
		harness.assert_true(result["violations"] is Array, "violations is array", failures)

	view.free()

	# 乱序触检查点（跳过 cp1 直接触 cp2）→ finished.violations 含
	# "checkpoint-out-of-order"（spec 裁定 4：乱序=成绩不认可，须进权威违例清单）。
	# 注：本场景 violations 还会含一条合成 "peak-exceeded"——传送把玩家从地面顶面
	# 拍到检查点位，打破 y==_ground_top 不变量，静立复核探针把这段位差当超大跳跃
	# 计峰（运行时断言的预期伪影，非真违例）；下方断言面只认 checkpoint-out-of-order
	# 是有意为之（终审 Minor 裁定：断言不改性，传送场景不入正式玩法）。
	var view2: Node2D = game_view_script.new()
	view2.setup(level)
	view2.player_state()["x"] = 440.0
	view2.player_state()["y"] = 220.0
	view2.tick(0, false)  # next=0 时触 cp2：计违例不激活
	var waited := 0
	while not view2.is_resting() and waited < 200:
		view2.tick(0, false)  # 落回地面恢复静立
		waited += 1
	harness.assert_true(view2.is_resting(), "out-of-order runner lands back on floor", failures)
	view2.player_state()["x"] = 590.0
	view2.player_state()["y"] = 140.0
	var results2: Array = []
	view2.finished.connect(func(result: Dictionary) -> void: results2.append(result))
	view2.tick(0, false)
	harness.assert_eq(results2.size(), 1, "out-of-order run still reaches goal", failures)
	if results2.size() == 1:
		var violations2: Array = results2[0]["violations"]
		harness.assert_true(violations2.has("checkpoint-out-of-order"),
			"out-of-order checkpoint lands in finished violations", failures)
	view2.free()
