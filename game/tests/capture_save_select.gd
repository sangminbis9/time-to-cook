extends SceneTree
## 그래픽 렌더러가 있는 환경에서 3슬롯 선택 화면을 실제 PNG로 저장한다.

var _frames: int = 0


func _initialize() -> void:
	var router: Node = root.get_node("SceneRouter")
	router.set("save_select_mode", &"new")
	var scene: PackedScene = load("res://scenes/save_select.tscn") as PackedScene
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var image: Image = root.get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://../.tools/save_select_render.png")
	if error != OK:
		push_error("세이브 선택 화면 캡처 저장 실패: %s" % error_string(error))
	return true
