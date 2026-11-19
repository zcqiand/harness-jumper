# harness-jumper — 仓库工作约定（供 Claude Code）

本仓为书《Harness 工程：Codex 智能游戏开发入门》（xr-know-022）配套仓，
是书稿代码块的 **source of truth**。绑定章节：ch10（平台跳跃）。

## 项目定位

Godot 平台跳跃游戏：物理规约（重力/跳跃力/土狼时间写进可测参数契约）+碰撞判定断言+输入状态捕获；关卡通用化参数（一键换关卡布局）。

## 铁律

- **版本钉死**：Godot 版本以 `version-lock.json` 为准（ch4 安装实测后回填实测回执）；不引入 lock 外的插件
- **TDD**：物理参数契约/碰撞判定等纯逻辑先写断言脚本 → 确认失败 → 实现 → 确认绿 → commit（headless 跑，无 Key 无网）
- **关卡契约化**：平台布局必须从 `data/levels/` JSON 加载，禁止硬编码到 GDScript
- **零伪代码**：禁止 `pass`/`TODO` 占位，每段代码必须可运行
- **只增不改**：随章节扩仓不动现有模块签名/行为

## 验收

```bash
"D:/qiand-life/3-resources/8-ego/software/godot/Godot_v4.7-stable_win64_console.exe" --headless --path . --script res://tests/test_runner.gd
```

headless 测试入口（`tests/test_runner.gd` 自动发现 `tests/test_*.gd`）：
exit code 是唯一真相，0=全绿。加关/改关必跑——`test_levels.gd` 关卡集全认证
（validate+certify）是关卡集的发布门槛。

## 正式区 / 临时区（2026-10-24 人定，全产品线通用）

- 过程件（调参实验、碰撞用例记录、调试日志）进 `_work/`，不与正式件混放
- 正式区同名正式件有且仅有一个；`_work/` 整目录 .gitignore；`.godot/` 为可再生件，gitignore

## 细则（docs/conventions/，按需引用）

- 目录结构与章节绑定 → `docs/conventions/structure.md`
- Tag 规约：Release 格式 `v<MAJOR>.<MINOR>.<PATCH>-<YYYYMMDD>`，禁止删/覆盖，禁止 `git push --tags` → `docs/conventions/tagging.md`
