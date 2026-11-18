# 物理契约即关卡 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** harness-jumper 完整可玩平台跳跃——每关是物理参数规约的契约实例，双闸认证（加载时可达性判定器拒载不可达关卡+运行时落点/峰值断言），换关即换物理世界。

**Architecture:** 纯函数运动学模块双消费（运行时 `_physics_process` 与认证器模拟共用同一积分与落地判定代码，结构上不分叉）；关卡 JSON 契约只增不改；游戏主体 Node2D 程序化渲染（不用 CharacterBody2D——全单向平台无墙体语义，物理 100% 确定性）；headless 自建测试 runner。

**Tech Stack:** Godot 4.7 stable + GDScript 4.x，零三方依赖（不引 GUT），user:// 本地成绩册 JSON。

**Spec:** docs/superpowers/specs/2026-11-19-physics-contract-jumper-design.md（14 条裁定，已人批 2026-11-19）

## Global Constraints

- Godot 4.7 stable（回执 `4.7.stable.official.5b4e0cb0f`），exe=`D:/qiand-life/3-resources/8-ego/software/godot/Godot_v4.7-stable_win64_console.exe`，版本钉 version-lock.json
- GDScript 4.x 语法，禁 3.x 残留（`is not`、`yield`）；缩进用 Tab（与骨架一致）
- 零三方依赖；测试=headless 自建 runner：`"D:/qiand-life/3-resources/8-ego/software/godot/Godot_v4.7-stable_win64_console.exe" --headless --path . --script res://tests/test_runner.gd`，exit code 是唯一真相（0=全绿）
- 关卡契约只增不改：骨架 flat 键 `name/gravity/jump_speed/platforms` 语义不变（`platforms` 每项 `[x,y,w,h]` 四元组、非负数）
- 运动学积分只在 `_physics_process`（固定 60Hz）调用，dt 恒 `1.0/60.0`；认证器同 dt
- 认证器输入策略集=`{-1.0, 0.0, 1.0}`（全程按满左/中性/按满右），不验其他输入
- 玩家碰撞盒 24×24 px（代码常量 `PLAYER_HALF_W=12.0` / `PLAYER_HEIGHT=24.0`），不入关卡契约
- 峰值断言容差 `PEAK_TOLERANCE=2.0` px；认证模拟超时 `SIM_TIME_LIMIT=3.0` s；模拟坠落死界=平台最低底边 +800 px
- 首输入起表（spec 裁定 14）：待命不起表
- TDD：每任务先写失败测试（headless 红）再实现；UI/渲染层允许接真实输入与帧回调
- 存档写侧 try/catch 静默降级、读侧守卫前置；禁 git add -A；commit 尾 `Co-Authored-By: Claude Code <noreply@anthropic.com>`
- `_work/` 放过程件；正式区同名正式件唯一

## Review Focus

- **帧率漂移破坏认证**：step 若被 `_process`（可变 delta）调用，峰值断言会随帧率误报——Task 3 的 `step` 文档注释钉「仅限 `_physics_process`」+Task 7 接线只用 `_physics_process`
- **认证器验了人类做不到的跳**：模拟若允许任意输入序列，证书失效——Task 4 策略集 `{-1,0,1}`×起跳点采样钉死测试（月球关全策略不可达的负例）
- **骨架契约破坏**：`is_valid_level` 原语义（flat 键+四元组非负）若被重构破坏，骨架承诺失效——Task 2 用骨架原始 jump_001 内容喂新校验器必须仍合法
- **乱序检查点静默通过**：触发序错若无痕迹，时序断言形同虚设——Task 5 乱序→violations+1 不激活钉死测试
- **坏档白屏**：成绩册 JSON 被外部改坏若抛错，选关屏整屏崩——Task 6 坏 JSON/缺键/类型错→回退空册测试

---

### Task 1: headless 测试基建 + Godot 版本回填

**Files:**
- Create: `tests/test_runner.gd`、`tests/harness.gd`、`tests/smoke_test.gd`
- Modify: `version-lock.json`（Godot 版本回填实测值）
- Modify（跨仓，独立 commit）: `../harness-starter/scripts/doctor.mjs`（Godot MISS→已装路径检测）

**Interfaces:**
- Produces: 测试 harness——`tests/harness.gd` 静态函数 `assert_true(cond: bool, label: String, failures: Array[String])`、`assert_eq(got: Variant, want: Variant, label: String, failures: Array[String])`、`assert_near(got: float, want: float, eps: float, label: String, failures: Array[String])`；测试套件约定——每个 `tests/test_*.gd` `extends RefCounted` 且有 `run(failures: Array[String]) -> void`；runner 自动发现 `res://tests/test_*.gd`（除 harness 基建外全部收进）

- [ ] **Step 1: 写 runner + harness + 冒烟套件**

`test_runner.gd` `extends SceneTree`，`_init()` 里：收集 `res://tests/` 下全部 `test_*.gd`（排除 `test_runner` 自身），逐个 `load(path).new().run(failures)`；全绿打印 `ALL PASS (<套件数> suites, <检查数> checks)` 并 `quit(0)`，否则逐行 `FAIL: <label>` 后 `quit(1)`。harness 三个静态断言函数按上面签名（assert_eq 用 `==` 比较 Variant；assert_near 用 eps）。smoke_test.gd 两个检查：`assert_true(true, "smoke passes", failures)`、`assert_near(1.0 + 0.5, 1.5, 0.001, "near works", failures)`。

- [ ] **Step 2: 跑通绿**

Run: `"D:/qiand-life/3-resources/8-ego/software/godot/Godot_v4.7-stable_win64_console.exe" --headless --path . --script res://tests/test_runner.gd`
Expected: 打印 `ALL PASS (1 suites, 2 checks)`，exit 0。若 class_name 全局注册在 --script 模式不可靠，一律 `load()` 按路径取脚本（本计划所有测试同款，不依赖 class_name）。

- [ ] **Step 3: 故意红一次（自证 runner 会红）**

把 smoke 里一个断言临时改错跑一次确认 exit 1，再改回。红灯证据留 `_work/`（可选）。

- [ ] **Step 4: version-lock.json 回填 + doctor.mjs 跨仓回填（两个 commit）**

version-lock：Godot 钉 `4.7-stable (official.5b4e0cb0f)` + 装机路径；doctor.mjs：Godot 检测改为探测装机路径存在且 `--version` 可执行（MISS 分支保留），commit 分开（本仓一个、starter 仓一个），starter 仓 commit 后跑一遍 `node scripts/doctor.mjs` 确认 Godot 项转 OK。

### Task 2: 关卡契约（校验枚举 + normalize + 骨架接线）

**Files:**
- Create: `scripts/level_contract.gd`、`tests/test_contract.gd`
- Modify: `scripts/main.gd`（load_level 改走 level_contract）、`data/levels/jump_001.json`（升级：加 spawn/goal/checkpoints/theme/move_speed/move_accel）

**Interfaces:**
- Consumes: 无（骨架 is_valid_level 语义）
- Produces: `JumperLevelContract`（脚本，测试按路径 load）——
  - `const ERROR_MISSING_FIELD := "missing-field"`（其余枚举：`not-object` / `bad-type` / `negative-value` / `bad-spawn` / `bad-goal` / `bad-checkpoints` / `unknown-theme`）
  - `static func validate(data: Dictionary) -> String`（`""`=合法；骨架 flat 键语义保留：缺 name/gravity/jump_speed/platforms→missing-field，platforms 每项须 4 元非负数值数组）
  - `static func normalize(data: Dictionary) -> Dictionary`——补缺省：`move_speed=220.0` / `move_accel=2400.0` / `theme="classic"` / `spawn=[40.0, 400.0]` / `goal=null` / `checkpoints=[]`；`platforms` 四元组数组转 `{x,y,w,h}` 字典数组（其余键原样保留）
  - `static func load_level(path: String) -> Dictionary`——fail-fast `fail_payload(reason: String)`：`{}` + push_error（骨架同款）；合法时返回 normalize 后契约并附 `"id"`（文件名去扩展名）

- [ ] **Step 1: 失败测试**（test_contract.gd `run()`）
  - 骨架原始 jump_001 内容（测试内联一份硬编码字典，含 `[0,400,640,40]` 等四元组）喂 `validate` → `""`（**Review Focus：骨架契约不破坏**）
  - 各错误枚举各一例：缺 gravity→missing-field；platforms 二元组→bad-type；`[0,-1,10,10]`→negative-value；spawn 越界（负 x）→bad-spawn；checkpoints 非数组→bad-checkpoints；未知 theme→unknown-theme
  - `normalize`：骨架 flat 输入补出 move_speed=220.0、platforms[0] 变 `{x:0.0,y:400.0,w:640.0,h:40.0}`；显式键不被缺省覆盖
- [ ] **Step 2: 跑红**（load 失败：脚本不存在）→ **Step 3: 实现** level_contract.gd（load_level 用 FileAccess+JSON.parse_string，骨架同款）→ **Step 4: 跑绿**
- [ ] **Step 5: jump_001.json 升级**（加 `"spawn":[40,400]`、`"goal":[590,140]`、`"checkpoints":[[260,300],[440,220]]`、`"theme":"classic"`、`"move_speed":220`、`"move_accel":2400`）+ main.gd 的 load_level 换成 level_contract.load_level，_ready 打印保留。再跑全测试绿 + headless 跑主场景一次（`--headless --path . --quit-after 120` 不报错）确认骨架链路活
- [ ] **Step 6: Commit** `feat: 关卡契约——校验枚举+normalize+骨架接线，jump_001 升级`

### Task 3: 运动学纯函数模块

**Files:**
- Create: `scripts/kinematics.gd`、`tests/test_kinematics.gd`

**Interfaces:**
- Produces: `JumperKinematics`——
  - `const DT := 1.0 / 60.0`、`const PLAYER_HALF_W := 12.0`、`const PLAYER_HEIGHT := 24.0`
  - `static func new_state(x: float, y: float) -> Dictionary`→`{x, y, vx: 0.0, vy: 0.0, on_ground: true}`（x,y=脚底中心）
  - `static func apply_jump(state: Dictionary, jump_speed: float) -> Dictionary`——仅 on_ground 时生效（vy=jump_speed，on_ground=false），否则原样返回
  - `static func step(state: Dictionary, params: Dictionary, input_x: float, dt: float) -> Dictionary`——水平：`vx += input_x * move_accel * dt` 钳 `±move_speed`；`input_x==0` 且 on_ground 时 vx 以 move_accel 减速到 0，空中不减速；垂直：`vy += gravity * dt`；位置积分；**注释钉死：仅限 `_physics_process` 固定 dt 调用**（Review Focus）
  - `static func find_landing(prev: Dictionary, curr: Dictionary, platforms: Array) -> Dictionary`——下落中（prev.vy>0）且脚底 prev.y ≤ top < curr.y 且 curr.x ∈ `[px - PLAYER_HALF_W, px+w + PLAYER_HALF_W]` → `{platform: <索引>, land_x: float, land_y: top}`；否则 `{}`
  - `static func land(state: Dictionary, landing: Dictionary) -> Dictionary`——y=land_y、vy=0、on_ground=true
  - `static func peak_height(jump_speed: float, gravity: float) -> float`——`jump_speed*jump_speed / (2.0*gravity)`（jump_speed 传绝对值语义在测试钉：传 -420 同 420 同结果）

- [ ] **Step 1: 失败测试**（数值全钉）：
  - `apply_jump` 落地态→vy=-420 非 ground；空中再跳→原样返回
  - `step` 自由落体：初 vy=0 落 60 帧（dt=1/60, gravity=980）后 y 增量 `assert_near(增量, 0.5*980*1.0², 0.01)`（t=1s 位移公式）；水平：input_x=1 从 vx=0 走 60 帧终 vx=220（钳 move_speed）；地面减速 input_x=0 从 vx=220 半秒内归 0；空中 input_x=0 保持 vx
  - `find_landing` 正例：构造 prev/curr 跨平台顶面（`[0,400,640,40]`，prev.y=399 vy=100，curr.y=401）→命中 platform 0、land_y=400；反例：上升中穿越（vy<0）→`{}`；x 越界→`{}`
  - `peak_height(420, 980)` `assert_near(…, 89.9, 0.1)`
- [ ] **Step 2: 红** → **Step 3: 实现** → **Step 4: 绿** → **Step 5: Commit** `feat: 运动学纯函数模块——积分/跳跃/落地判定，运行时与认证器同代码`

### Task 4: 可达性判定器 + 认证拒载

**Files:**
- Create: `scripts/reachability.gd`、`tests/test_reachability.gd`
- Modify: `scripts/level_contract.gd`（load_level 增认证闸）、`data/levels/`（`_work/` 放不可达负例 fixture，不入库）

**Interfaces:**
- Consumes: kinematics（step/apply_jump/find_landing/land/DT）、level_contract.normalize 产物
- Produces: `JumperReachability`——
  - `const SIM_TIME_LIMIT := 3.0`、`const DEATH_MARGIN := 800.0`、`const EDGE_SAMPLE_STEP := 24.0`
  - `static func certify(level: Dictionary) -> Dictionary`→`{ok: bool, unreachable: int}`（ok=false 时 unreachable=按序第一个够不到的平台索引，全可达=-1）；level 须已 normalize
  - 算法：BFS 平台图。起点=出生站立的平台（spawn 脚底所在平台，spawn 在无平台处→以 y=spawn.y 虚地面为第 -1 节点）。转移：①跳跃边——沿平台顶面每 24px 采样起脚点，策略 `{-1,0,1}` 逐个 `apply_jump` 后循环 `step`（dt=DT）直到 `find_landing` 命中/超 SIM_TIME_LIMIT/脚底超 DEATH_MARGIN 死界，命中→该平台入队；②坠落边——平台左右边缘外 1px 落下（vx=0）模拟至落地。visited 全覆盖→ok
- `level_contract.load_level` 接线：validate 过→normalize→certify，`ok=false` 时 fail-fast `fail_payload("unreachable-platform-%d" % idx)`（**Review Focus：拒载报第一个不可达平台**）

- [ ] **Step 1: 失败测试**：
  - 正例：升级后 jump_001（normalize 后）certify→`{ok: true, unreachable: -1}`
  - 负例：内联两平台关——`spawn [40,400]` 在平台 A `[0,400,200,40]`，平台 B `[500, 100, 100, 20]`（参数默认 gravity=980/jump_speed=-420 时峰高 ~90px 够不到 300px 高差）→`{ok: false, unreachable: 1}`（**Review Focus：不可达负例**）
  - 坠落边正例：A `[0,200,200,40]`、B `[150,400,200,40]`（从 A 右缘走出坠落到 B）→ok=true（无跳跃也可达）
  - 认证闸接线：`load_level` 喂不可达契约文件（`_work/` 临时写）→返回 `{}` 且 push_error 含 `unreachable-platform-1`
- [ ] **Step 2: 红** → **Step 3: 实现** → **Step 4: 绿** → **Step 5: Commit** `feat: 可达性判定器——离散模拟 BFS 认证+拒载报平台序号`

### Task 5: 运行时断言 + 检查点时序

**Files:**
- Create: `scripts/runtime_asserts.gd`、`scripts/checkpoints.gd`、`tests/test_asserts.gd`、`tests/test_checkpoints.gd`

**Interfaces:**
- Consumes: kinematics.peak_height、level_contract 契约
- Produces:
  - `JumperRuntimeAsserts`——`const PEAK_TOLERANCE := 2.0`；`static func check_peak(observed_peak: float, level: Dictionary) -> bool`（≤ `peak_height(jump_speed, gravity)` + PEAK_TOLERANCE）；`static func check_landing(land_x: float, platform: Dictionary) -> bool`（x ∈ 平台顶面 x 区间±PLAYER_HALF_W 容差）；`static func new_violations() -> Array[String]`（空数组；调用方 append 违例标签 `"peak-exceeded"` / `"landing-off-platform"`）
  - `JumperCheckpoints`——`static func new_state(count: int) -> Dictionary`→`{next: 0, activated: []（bool×count）, violations: 0}`；`static func trigger(state: Dictionary, index: int) -> Dictionary`（index==next→激活、next+1；否则 violations+1 不激活；**Review Focus：乱序不激活**）；`static func respawn_point(state: Dictionary, points: Array, spawn: Vector2) -> Vector2`（最近激活检查点坐标，无→spawn）

- [ ] **Step 1: 失败测试**：check_peak 正例（observed=89.9, level 默认参数→true）负例（observed=95.0→false，超出 89.9+2.0）；check_landing 平台 `{x:0,y:400,w:640}` 落 x=650→false、x=630→true；checkpoints：触发 0→1→2 全激活 violations=0；跳过 0 直触 1→violations=1 且 1 未激活；respawn：激活 0,1 后→points[1]，空 state→spawn
- [ ] **Step 2: 红** → **Step 3: 实现** → **Step 4: 绿** → **Step 5: Commit** `feat: 运行时落点/峰值断言+检查点按序时序状态机`

### Task 6: 成绩册 + 粒子对象池（纯逻辑）

**Files:**
- Create: `scripts/scorebook.gd`、`scripts/particles_pool.gd`、`scripts/file_storage.gd`、`tests/test_scorebook.gd`、`tests/test_pool.gd`

**Interfaces:**
- Produces:
  - `FileStorage`（运行时实现）——`func load_text(path: String) -> String`（不存在→""）、`func save_text(path: String, text: String) -> bool`（FileAccess+try 语义：失败 false）、`func exists(path: String) -> bool`
  - `JumperScorebook`——`const SAVE_PATH := "user://scorebook.json"`；`static func load_book(storage) -> Dictionary`→`{"best": {}}`（**Review Focus：坏档回退**——JSON 坏/非对象/缺 best 键/best 非字典→空册）；`static func record_result(book: Dictionary, level_id: String, time_ms: int, assertions_ok: bool) -> Dictionary`（assertions_ok=false→原样返回；无 PB 或更快→更新并附 `{"best": {level_id: {time_ms, saved_at}}}`；平局/更慢→原样）；`static func save_book(book: Dictionary, storage) -> bool`
  - `JumperParticlesPool`——`static func new_pool(capacity: int) -> Dictionary`→`{free: [0..capacity-1], in_use: {}}`；`static func acquire(pool: Dictionary) -> int`（free 空→-1，调用方静默丢弃本粒尘）；`static func release(pool: Dictionary, id: int) -> void`（回 free，双释放幂等）
- [ ] **Step 1: 失败测试**（storage 用内联内存假件 `{store: {}}` 实现同签名——测试不碰真 user://）：坏串 `"not json{"`→空册；`{"best": 3}`→空册；record：assertions_ok=false 不记；快于 PB 覆盖；慢于 PB 原样；pool：acquire 到 capacity-1 后返 -1；release 后可再 acquire 同 id
- [ ] **Step 2: 红** → **Step 3: 实现** → **Step 4: 绿** → **Step 5: Commit** `feat: 成绩册（读侧守卫+PB 单槽）+尘土粒子对象池逻辑`

### Task 7: 游戏屏——渲染/输入/状态机/断言接线

**Files:**
- Create: `scripts/game_view.gd`（游戏屏场景脚本）、`scripts/themes.gd`
- Modify: `scripts/main.gd`（三态路由：`select`/`game`/`result`）、`scenes/main.tscn`（如需挂子节点则程序化创建为主，.tscn 只留根）

**Interfaces:**
- Consumes: Task 2-6 全部产物（契约/运动学/断言/检查点/成绩册/池/主题）
- Produces: 游戏屏信号——`finished(result: Dictionary)`（`{time_ms, deaths, violations: Array[String], peaks_ok}`）；main.gd 状态机 `select → game → result → select`；Esc=放弃回选关不计档

- [ ] **Step 1: themes.gd**——`const THEMES := {"classic": {bg: Color("1a1c2c"), platform: Color("333a5c"), player: Color("f4f4f4"), accent: Color("ef476f")}, "moon": {bg: Color("0b0e2a"), platform: Color("3d4a8f"), player: Color("d9e4ff"), accent: Color("7fd1e0")}, "candy": {bg: Color("2d1b3d"), platform: Color("8f5aa8"), player: Color("ffe9ec"), accent: Color("ff8fb1")}}`；`static func palette(theme: String) -> Dictionary`（未知→classic）
- [ ] **Step 2: game_view.gd**——`setup(level: Dictionary) -> void`（normalize 后契约）：程序化建平台 ColorRect（palette.platform 色）、goal 旗、检查点标记（未激活灰/激活 accent 色）、player Node2D（24×24 方块）；`_physics_process` 固定 dt 调 kinematics.step（**Review Focus：只用固定步长**）：输入轴 `Input.get_axis("move_left","move_right")` 取整钳 `{-1,0,1}`、跳跃沿 edge 触发 `apply_jump`；`find_landing` 命中→`land()`+落地尘土（pool.acquire，同帧粒子落地回收）+峰值记录（本次跳跃 max 跳跃高度，`check_peak` 违例 append）；坠落出底界→deaths+1 回 respawn_point；触 goal→emit finished（计时：首输入起表，`accumulated_dt` 累加×1000 取整）；HUD CanvasLayer 显示关卡名/主题徽章 `certified ✓`/时间/坠落数/Esc 提示；触屏：左下左右两钮+右下跳钮（TouchScreenButton，拇指区）
- [ ] **Step 3: main.gd 三态路由 + input map**（project.godot 加 `move_left/move_right/jump/back` 键位映射：A/←、D/→、Space/W/↑、Esc）
- [ ] **Step 4: headless 冒烟**——`tests/test_game_smoke.gd`：实例化 game_view，喂 normalize 后 jump_001，模拟 30 帧 `_physics_process` 等价调用（直接调内部 step 路径或 SceneTree 帧推进 `await process_frame`×30），断言：不崩、player 状态字典存在、平台节点数==契约平台数。跑全量绿
- [ ] **Step 5: 真窗口手验**（非 headless 打开跑一局 jump_001 可通关）+ Commit `feat: 游戏屏——确定性物理接线+检查点/断言/尘土池+三态路由`

### Task 8: 选关屏 + 结算屏 + 成绩册接线

**Files:**
- Create: `scripts/select_view.gd`、`scripts/result_view.gd`
- Modify: `scripts/main.gd`（三态完整化）、`scripts/game_view.gd`（finished→main 落账）

**Interfaces:**
- Consumes: scorebook、themes、level_contract.load_level、game_view.finished
- Produces: 完整游戏循环（选关→玩→结算→选关）

- [ ] **Step 1: select_view.gd**——扫描 `res://data/levels/*.json` 逐个 load_level（拒载关卡列表尾部红字一行报原因，不崩）；关卡卡：名字+主题色块+`certified ✓` 徽章+PB 时间（scorebook）；点击进图
- [ ] **Step 2: result_view.gd**——通关时间+ deaths+断言徽章（violations 空→`认证全绿 ✓` accent 色；非空→逐条红字+本局不入档提示）；PB 破格高亮（本次更快时「新纪录」）+「再战」「回选关」按钮
- [ ] **Step 3: main.gd 接线**——finished→record_result（violations 空才落账）→result_view；全流程 headless 冒烟扩展：选关屏建出（卡数==合法关卡数）→进图→直通 goal（测试内直接 emit finished）→落账→result 呈现（内存假件 storage 注入）
- [ ] **Step 4: 跑全量绿 + 真窗口手验全流程** → Commit `feat: 选关/结算屏+成绩册接线——三态闭环`

### Task 9: 关卡集扩充 + 全链冒烟 + 文档收口

**Files:**
- Create: `data/levels/moon_001.json`、`data/levels/jump_002.json`、`tests/test_levels.gd`
- Modify: `docs/conventions/structure.md`（目录树+章节绑定表）、`README.md`（玩法+测试命令）、`CLAUDE.md`（如有过时项）

**Interfaces:**
- Consumes: 全部——测试直接扫 levels 目录逐关 certify

- [ ] **Step 1: moon_001.json**——月球 showcase：`gravity=160` / `jump_speed=-260` / `move_speed=200` / `theme="moon"`，平台布置成大跨度跳跃链（**每平台间距设计成 classic 参数不可达、moon 参数可达**——物理差异可玩可证）；jump_002.json——candy 主题常规关，含 2 检查点+一段坠落路线
- [ ] **Step 2: test_levels.gd 失败测试**：扫描 `res://data/levels/*.json` 每关 `validate==""` 且 `certify.ok==true`（**关卡集全认证是关卡集的发布门槛**）；moon_001 断言 gravity==160（物理差异在册）
- [ ] **Step 3: 红→补关→绿**（先跑红证明 fixture 缺失/不可达会被抓，再补齐绿）
- [ ] **Step 4: 真窗口手验**——三关各通一局，换主题换手感可感知，断言全绿徽章可见；文档三件更新
- [ ] **Step 5: Commit** `feat: 关卡集（月球 showcase+candy 常规关）+全关认证门槛+文档收口`
