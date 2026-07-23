extends Control
## 타이틀 화면: 새 게임 / 이어하기 / 참가하기 / 종료.
## 호스트가 세이브를 소유하며 새 게임과 이어하기 모두 3개 슬롯 화면을 거친다.

@onready var _new_button: Button = %NewGame
@onready var _continue_button: Button = %ContinueGame
@onready var _join_button: Button = %JoinGame
@onready var _quit_button: Button = %Quit
@onready var _address: LineEdit = %Address
@onready var _notice: Label = %Notice


func _ready() -> void:
	theme = PixelUi.theme()
	PixelUi.decorate_button(_new_button, &"store")
	PixelUi.decorate_button(_continue_button, &"manage")
	PixelUi.decorate_button(_join_button, &"staff")
	PixelUi.decorate_button(_quit_button, &"close")
	_new_button.pressed.connect(_on_new_game)
	_continue_button.pressed.connect(_on_continue)
	_join_button.pressed.connect(_on_join)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_continue_button.disabled = not SaveService.any_save()
	_notice.text = SceneRouter.pending_notice
	SceneRouter.pending_notice = ""


func _on_new_game() -> void:
	SceneRouter.to_save_select(&"new")


func _on_continue() -> void:
	SceneRouter.to_save_select(&"continue")


func _on_join() -> void:
	GameServer.reset()
	var address: String = _address.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	if NetworkService.join(address) != OK:
		_notice.text = "참가 실패"
		return
	_notice.text = "접속 중..."
	_join_button.disabled = true
	var connected: bool = await _await_session()
	if connected:
		SceneRouter.to_store()
	else:
		_notice.text = "접속할 수 없습니다"
		_join_button.disabled = false


func _await_session() -> bool:
	var result: Array = [false]
	var on_started: Callable = func(_is_host: bool) -> void: result[0] = true
	NetworkService.session_started.connect(on_started, CONNECT_ONE_SHOT)
	# 실패 시 session_ended가 온다
	var timeout: SceneTreeTimer = get_tree().create_timer(5.0)
	await timeout.timeout
	if NetworkService.session_started.is_connected(on_started):
		NetworkService.session_started.disconnect(on_started)
	return result[0]
