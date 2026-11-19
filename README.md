# harness-jumper

书《Harness 工程：Codex 智能游戏开发入门》（xr-know-022）配套仓——Godot 平台跳跃游戏。

| 字段 | 值 |
|------|------|
| 绑定章节 | ch10 平台跳跃 |
| 技术栈 | GDScript（Godot 4.x）+ JSON 关卡契约 |
| 状态 | 三关闭环（2026-11-19 physics-contract 批次收官：物理契约即关卡双闸认证+三主题关卡集） |

工程纪律见 [CLAUDE.md](CLAUDE.md)。

## 玩法

- 三态闭环：选关屏 → 游戏屏 → 结算屏。选关屏自动扫描 `data/levels/*.json` 生成关卡卡片；
  主题（classic/moon/candy）换关即换配色，物理参数（gravity/jump_speed/move_speed）换关即换手感
- 按满左/右移动，跳跃键起跳；平台单向顶面碰撞
- 检查点必须按序触发，乱序触发计违例（成绩不入档）；坠落出底界 deaths+1、
  回最近激活检查点重生
- 运行时断言（认证第二闸）：空中峰值超过理论界（jump_speed²/2g+容差）或落点出
  撑脚区间，本局成绩不入档

## 关卡集

| 关卡 | 主题 | 物理指纹 | 说明 |
|------|------|------|------|
| jump_001 | classic | 980/-450/220 | 入门阶梯关，双检查点 |
| jump_002 | candy | 980/-450/220 | 双检查点+坠落捷径：从上层平台跳下去直通 goal 更近 |
| moon_001 | moon | 160/-260/200 | 月球 showcase：低重力大跨度三连跳链，同一布局 classic 参数不可达（认证闸会拒载）——换关即换物理世界的可证样本 |

## 测试

```bash
"D:/qiand-life/3-resources/8-ego/software/godot/Godot_v4.7-stable_win64_console.exe" --headless --path . --script res://tests/test_runner.gd
```

exit code 是唯一真相：0=全绿（11 套件），非 0=按 FAIL 行修。

## 关卡集认证门槛

`tests/test_levels.gd` 扫描 `data/levels/*.json`，每关断言：

- 契约合法（`validate==""`）
- 全平台可达（`certify.ok==true`）——不可达关卡在认证闸（`load_level`）当场拒载
- 关卡集三关齐全；moon_001 额外断言 gravity==160，且同一布局喂 classic 参数必须不可达
  （「classic 玩不了、moon 玩得了」的 showcase 承诺双向钉住）

加关/改关跑一次 runner 即可：认证门槛套件自动扫到新关。

## 部署

tag push（`v*`）→ CI deploy job（agent 家族 web-only 变体，docs/families/agent.md 游戏段）：
Godot headless 导出 Web 产物 → 单镜像 `zcqiand/harness-jumper-web`（latest+tag 双份）→
VPS 拉镜像起容器（host 127.0.0.1:5310）→ `https://hjumper.xiangru.uk`。

本地导出（产物落 `_work/`，gitignore）：

```bash
"D:/qiand-life/3-resources/8-ego/software/godot/Godot_v4.7-stable_win64_console.exe" --headless --path . --export-release "Web" _work/build-web/index.html
```
