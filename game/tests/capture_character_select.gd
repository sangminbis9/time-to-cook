extends SceneTree
## 그래픽 렌더러가 있는 환경에서 캐릭터 생성 화면을 실제 640×360 PNG로 저장한다.

var _frames: int = 0


func _initialize() -> void:
	var router: Node = root.get_node("SceneRouter")
	router.set("pending_save_slot", 1)
	var scene: PackedScene = load("res://scenes/character_select.tscn") as PackedScene
	root.add_child(scene.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var image: Image = root.get_viewport().get_texture().get_image()
	var error: Error = image.save_png("res://../.tools/character_select_render.png")
	if error != OK:
		push_error("캐릭터 생성 화면 캡처 저장 실패: %s" % error_string(error))
	return true
