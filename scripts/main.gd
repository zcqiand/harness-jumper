extends Node2D
## 主场景脚本：经关卡契约层（level_contract）加载并 normalize 后消费。
## ch10 落物理规约断言与碰撞判定；本场景只证「契约文件可加载、可校验」。

const LEVEL_PATH := "res://data/levels/jump_001.json"
const LEVEL_CONTRACT := preload("res://scripts/level_contract.gd")


func _ready() -> void:
	var level := LEVEL_CONTRACT.load_level(LEVEL_PATH)
	if level.is_empty():
		push_error("关卡加载失败，见上方错误。")
		return
	print(
		"关卡加载成功：%s（id=%s，%d 块平台，重力 %s，跳跃力 %s）" % [
			level["name"],
			level["id"],
			(level["platforms"] as Array).size(),
			level["gravity"],
			level["jump_speed"],
		]
	)
