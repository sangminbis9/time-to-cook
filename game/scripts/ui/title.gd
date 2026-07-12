extends Control
## 타이틀 화면: 새 게임 / 이어하기 / 참가하기 / 종료.
## 호스트가 세이브를 소유한다 (수직 슬라이스: 슬롯 1 고정).

const SLOT: int = 1

@onready var _new_button: Button = %NewGame
@onready var _continue_button: Button = %ContinueGame
@onready var _join_button: Button = %JoinGame
@onready var _quit_button: Button = %Quit
@onready var _address: LineEdit = %Address
@onready var _notice: Label = %Notice


func _ready() -> void:
	_new_button.pressed.connect(_on_new_game)
	_continue_button.pressed.connect(_on_continue)
	_join_button.pressed.connect(_on_join)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_continue_button.disabled = not SaveService.has_save(SLOT)
	_notice.text = SceneRouter.pending_notice
	SceneRouter.pending_notice = ""


func _on_new_game() -> void:
	GameServer.reset()
	FranchiseState.set_money(FranchiseState.STARTING_MONEY)
	# 시작 도시 인천은 최초 시장 정보를 최고 수준으로 무료 제공 (§6.4)
	var incheon: CityDef = Defs.get_def(&"city.korea.incheon") as CityDef
	FranchiseState.market_info = {
		"city.korea.incheon": MarketReport.exact_report(incheon, 1),
	}
	SaveService.current_slot = SLOT
	if NetworkService.host() != OK:
		_notice.text = "호스트를 열 수 없습니다 (포트 사용 중?)"
		return
	SceneRouter.to_store()


func _on_continue() -> void:
	GameServer.reset()
	if NetworkService.host() != OK:
		_notice.text = "호스트를 열 수 없습니다 (포트 사용 중?)"
		return
	# 매장 씬이 setup_store를 수행한 뒤 세이브를 적용해야 하므로
	# 씬 전환 후 로드 (store_gameplay가 SaveService.pending_load 확인)
	SaveService.current_slot = SLOT
	SceneRouter.pending_load_slot = SLOT
	SceneRouter.to_store()


func _on_join() -> void:
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
