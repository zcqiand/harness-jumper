# 目录结构与章节绑定

> 树是文件系统的复写，以仓库实际为准；模块职责与章节绑定在此维护。

```text
harness-jumper/
├── CLAUDE.md                       ← 工程约定入口
├── version-lock.json               ← 版本钉死 SSOT（Godot 版本）
├── project.godot                   ← Godot 工程描述（config_version=5）
├── scenes/
│   └── main.tscn                   ← 主场景：平台跳跃渲染根
├── scripts/
│   └── main.gd                     ← 主场景脚本：加载关卡 JSON 并校验
├── data/
│   └── levels/
│       └── jump_001.json           ← 关卡契约样例（平台布局+物理参数）
├── docs/conventions/               ← structure / tagging
└── _work/                          ← 过程件（gitignore）
```

## 章节绑定表

| 章节 | 落点 | 交付物 |
|---|---|---|
| ch10 平台跳跃 | `data/levels/`+`scripts/` | 物理规约+碰撞断言+输入状态捕获+关卡通用化参数 |
