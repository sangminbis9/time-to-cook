extends Node
## 효과음 재생 (PLAN.md §34): 기존 클라이언트 신호만 구독 — 게임 로직 불변.
## 따뜻하고 작은 생활 소리, 실패음은 짧고 부드럽게. 에셋은 tools/gen_sfx.py 생성.

const SOUNDS: Dictionary = {
	&"cut": "res://assets/audio/cut.wav",
	&"fry": "res://assets/audio/fry.wav",
	&"submit": "res://assets/audio/submit.wav",
	&"ding": "res://assets/audio/ding.wav",
	&"coin": "res://assets/audio/coin.wav",
	&"door": "res://assets/audio/door.wav",
	&"fail": "res://assets/audio/fail.wav",
	&"bell": "res://assets/audio/bell.wav",
	&"event": "res://assets/audio/event.wav",
	&"skill": "res://assets/audio/skill.wav",
}
const POOL_SIZE: int = 8
const BGM_PATH: String = "res://assets/audio/bgm.wav"
## 볼륨 설정 저장 위치 (§35 효과음·음악 분리)
const SETTINGS_PATH: String = "user://settings.cfg"

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _bgm_player: AudioStreamPlayer
var _last_money: int = 0
var _last_event_type: String = ""
## 튀김기 key → item_iid (투입 감지용)
var _fryer_items: Dictionary = {}


func _ready() -> void:
	# 효과음·음악 버스 분리 (§35): Master 아래 SFX/Music
	for bus_name: String in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	for i in range(POOL_SIZE):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
	for sfx_name: StringName in SOUNDS.keys():
		_streams[sfx_name] = load(String(SOUNDS[sfx_name]))
	# 배경음 (§34): 무한 루프, 항상 재생 — 볼륨은 Music 버스로 조절
	var bgm: AudioStreamWAV = load(BGM_PATH) as AudioStreamWAV
	if bgm != null:
		bgm.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bgm.loop_begin = 0
		bgm.loop_end = bgm.data.size() / 2  # 16비트 모노: 2바이트 = 1프레임
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.bus = &"Music"
		_bgm_player.stream = bgm
		add_child(_bgm_player)
		_bgm_player.play()
	_load_volumes()
	GameServer.fail_notified.connect(func(_msg: String) -> void: play(&"fail"))
	GameServer.order_completed.connect(
		func(_oid: int, _revenue: int) -> void: play(&"submit"))
	GameServer.fridge_changed.connect(func() -> void: play(&"door"))
	GameServer.station_changed.connect(_on_station_changed)
	GameServer.store_event_changed.connect(_on_store_event_changed)
	GameServer.skill_changed.connect(_on_skill_changed)
	GameClock.phase_changed.connect(_on_phase_changed)
	FranchiseState.money_changed.connect(_on_money_changed)


func play(sfx_name: StringName) -> void:
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null:
		return
	for player: AudioStreamPlayer in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			return


## 튀김기에 아이템이 새로 들어가면 지글 소리 (내 매장 신호만 옴)
func _on_station_changed(key: StringName) -> void:
	var st: StationState = GameServer.station(key)
	if st == null or st.get_def().kind != StationDef.Kind.FRYER:
		return
	if st.item_iid != 0 and int(_fryer_items.get(key, 0)) == 0:
		play(&"fry")
	_fryer_items[key] = st.item_iid


func _on_store_event_changed() -> void:
	var etype: String = String(GameServer.current_store_event().get("type", ""))
	if etype != "" and _last_event_type == "":
		play(&"event")
	elif etype == "" and _last_event_type != "":
		play(&"ding")
	_last_event_type = etype


func _on_skill_changed(peer: int) -> void:
	if peer == multiplayer.get_unique_id():
		play(&"skill")


func _on_phase_changed(phase: GameClock.Phase) -> void:
	if phase == GameClock.Phase.SERVICE or phase == GameClock.Phase.SETTLEMENT:
		play(&"bell")


## 준비 단계의 자금 감소 = 구매 (설비·재고·연구·고용 등) — 동전 소리
func _on_money_changed(money: int) -> void:
	if money < _last_money and GameClock.phase == GameClock.Phase.PREP:
		play(&"coin")
	_last_money = money


# ── 볼륨 옵션 (§35): 효과음·음악 분리, user://settings.cfg 저장 ──────

func get_volume(bus_name: String) -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index(bus_name)))


func set_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(bus_name), linear_to_db(maxf(linear, 0.001)))
	AudioServer.set_bus_mute(
		AudioServer.get_bus_index(bus_name), linear <= 0.0)
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", bus_name, linear)
	config.save(SETTINGS_PATH)


func _load_volumes() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus_name: String in ["SFX", "Music"]:
		var linear: float = float(config.get_value("audio", bus_name, 1.0))
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index(bus_name), linear_to_db(maxf(linear, 0.001)))
		AudioServer.set_bus_mute(
			AudioServer.get_bus_index(bus_name), linear <= 0.0)
