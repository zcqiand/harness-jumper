# 目录结构与章节绑定

> 树是文件系统的复写，以仓库实际为准；模块职责与章节绑定在此维护。

```text
harness-jumper/
├── CLAUDE.md                       ← 工程约定入口
├── version-lock.json               ← 版本钉死 SSOT（Godot 版本）
├── project.godot                   ← Godot 工程描述（config_version=5）
├── export_presets.cfg              ← Web 导出 preset（name 恰为 "Web"，Dockerfile 同名引用）
├── icon.svg                        ← 工程图标（classic 主题配色，Web 导出消费）
├── Dockerfile                      ← web-only 容器：Godot headless 导出 → nginx:alpine 静态
├── nginx.conf                      ← 容器 nginx：静态服务+COOP/COEP（WASM 跨域隔离）
├── .github/
│   └── workflows/
│       └── ci.yml                  ← test（Godot headless runner）+ deploy（tag v* 触发）
├── deploy/
│   ├── harness-jumper.sh           ← VPS deploy 脚本（web-only 变体，5310/hjumper）
│   └── nginx-vps.conf.example      ← vhost 模板（单 upstream+COOP/COEP 双保险）
├── scenes/
│   └── main.tscn                   ← 主场景：三态路由根（选关/游戏/结算）
├── scripts/
│   ├── main.gd                     ← 三态路由：select ↔ game ↔ result 切换
│   ├── select_view.gd              ← 选关屏：扫描 data/levels/*.json 生成卡片，拒载文件留空槽
│   ├── game_view.gd                ← 游戏屏：确定性物理接线+检查点/断言/尘土池+HUD+触屏钮
│   ├── result_view.gd              ← 结算屏：本局时间/死亡/违例展示，全绿徽章
│   ├── level_contract.gd           ← 关卡契约层：validate 枚举+normalize 缺省+load_level 认证闸拒载
│   ├── reachability.gd             ← 可达性判定器（认证第一闸）：BFS 平台图，不可达当场拒载
│   ├── kinematics.gd               ← 运动学纯函数：积分/跳跃/落地判定（运行时与认证器同代码）
│   ├── runtime_asserts.gd          ← 运行时断言（认证第二闸）：峰值界+落点区间
│   ├── checkpoints.gd              ← 检查点按序时序状态机（乱序=违例计数，重生点）
│   ├── particles_pool.gd           ← 尘土粒子对象池（纯逻辑）
│   ├── scorebook.gd                ← 成绩册：读侧守卫+PB 单槽（user:// 存档）
│   ├── file_storage.gd             ← 存档读写底层
│   └── themes.gd                   ← 主题色板真源：classic/moon/candy（校验与渲染共用）
├── data/
│   └── levels/
│       ├── jump_001.json           ← classic 入门关：阶梯上行+双检查点
│       ├── jump_002.json           ← candy 常规关：双检查点+坠落捷径到 goal
│       └── moon_001.json           ← moon showcase：大跨度三连跳（classic 参数不可达、moon 参数可达）
├── tests/
│   ├── harness.gd                  ← 断言工具（静态）：失败记 label 不中断，count 计数
│   ├── test_runner.gd              ← headless 入口：自动发现 test_*.gd，exit code 唯一真相
│   ├── test_smoke.gd               ← 基建冒烟：runner 发现机制（true / 1.5）
│   ├── test_asserts.gd             ← 运行时断言套件：峰值界+落点区间+违例收集
│   ├── test_contract.gd            ← 契约层：校验枚举/normalize/themes
│   ├── test_reachability.gd        ← 认证器：正例/负例/坠落边/拒载接线
│   ├── test_kinematics.gd          ← 运动学：积分/峰值/落地
│   ├── test_checkpoints.gd         ← 检查点时序状态机
│   ├── test_pool.gd                ← 对象池
│   ├── test_scorebook.gd           ← 成绩册守卫+PB
│   ├── test_game_smoke.gd          ← 游戏屏冒烟：装载/节点/步进/goal 接线
│   ├── test_loop_smoke.gd          ← 三态闭环冒烟
│   └── test_levels.gd              ← 关卡集全认证门槛：扫 levels 目录逐关 validate+certify
├── docs/
│   ├── conventions/                ← structure / tagging
│   └── superpowers/                ← spec 与 plan（SDD 批次文档）
└── _work/                          ← 过程件（gitignore）
```

## 章节绑定表

| 章节 | 落点 | 交付物 |
|---|---|---|
| ch10 平台跳跃 | `data/levels/`+`scripts/` | 物理规约+碰撞断言+输入状态捕获+关卡通用化参数 |

## 关卡集认证门槛（发布纪律）

- 加关/改关必须过 `test_levels.gd`：扫描 `res://data/levels/*.json` 每关
  `validate==""`（契约合法）且 `certify.ok==true`（全平台可达）——关卡集全认证
  是关卡集的发布门槛，缺关或不可达即红
- moon_001 额外钉物理差异双向指纹：gravity==160 在册；同一布局喂 classic 参数
  （980/-450/220/2400）必须不可达——「classic 玩不了、moon 玩得了」的 showcase 承诺
- 认证物理=玩家玩到的物理（双消费铁律）：认证器与游戏屏只准调 `kinematics.gd`
  同一积分模块，两边各写一份积分即是事故
