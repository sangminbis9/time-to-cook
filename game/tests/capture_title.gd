extends SceneTree
## 그래픽 렌더러가 있는 환경에서 타이틀 UI의 실제 640×360 렌더를 저장하는 QA 도구.

var _frames: int = 0


func _initialize() -> void:
	var title: PackedScene = load("res://scenes/title.tscn") as PackedScene
	root.add_child(title.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var image: Image = root.get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://../.tools/title_render.png")
	if error != OK:
		push_error("타이틀 캡처 저장 실패: %s" % error_string(error))
	return true
