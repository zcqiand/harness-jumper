extends RefCounted
## 主题色板真源（校验层与渲染层共用）：
## 校验层按 THEMES 键集判 theme 合法性；渲染层经 palette() 取色，
## 未知 theme 兜底 classic（渲染宽容，校验严格，两者不矛盾）。

const THEMES := {
	"classic": {
		"bg": Color("1a1c2c"),
		"platform": Color("333a5c"),
		"player": Color("f4f4f4"),
		"accent": Color("ef476f"),
	},
	"moon": {
		"bg": Color("0b0e2a"),
		"platform": Color("3d4a8f"),
		"player": Color("d9e4ff"),
		"accent": Color("7fd1e0"),
	},
	"candy": {
		"bg": Color("2d1b3d"),
		"platform": Color("8f5aa8"),
		"player": Color("ffe9ec"),
		"accent": Color("ff8fb1"),
	},
}


## 取主题色板；未知 theme 返回 classic 色板（不抛错，渲染层兜底）。
# @impl M04.F01.I02
static func palette(theme: String) -> Dictionary:
	return THEMES.get(theme, THEMES["classic"])
