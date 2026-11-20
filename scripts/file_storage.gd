extends RefCounted
## 本地文件存储（运行时实现，非 static）：scorebook 的注入鸭子接口。
## 读侧守卫：不存在/打不开 → ""（调用方按缺档处理，不抛错）；
## 写侧守卫 try 语义：打不开（目录缺失/权限/盘满）→ false 静默降级，
## 存档写失败不致命——本局成绩照玩，下局再写。
## path 语义与 Godot 一致：res://（工程内）/ user://（用户持久目录）。

## 读文本：不存在或打不开 → ""（空串即缺档信号）。
func load_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## 写文本：FileAccess 写；打不开 → false（失败原因经 FileAccess.get_open_error 可查）。
func save_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


## 存在性：存在 → true。
# @impl M03.F02.I03
func exists(path: String) -> bool:
	return FileAccess.file_exists(path)
