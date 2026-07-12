extends Control
## 부트 씬: autoload 워밍업과 정의 데이터 검증 후 타이틀로 이동.

@onready var _label: Label = $Label


func _ready() -> void:
	_label.text = "Time to Cook\n정의 데이터 %d개 로드됨" % Defs.all_ids().size()
	# 통합 테스트 드라이버가 활성화되면 씬 전환은 드라이버가 담당한다
	if NetTest.active:
		return
	SceneRouter.to_title.call_deferred()
