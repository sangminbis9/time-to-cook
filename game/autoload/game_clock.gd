extends Node
## 게임 시계. 하루의 위상(준비/영업/정산)과 영업 경과 시간을 소유한다.
## SERVICE 중에만 서버(_physics_process)에서 tick하며, 게임플레이는 OS 시간을 직접 읽지 않는다.
## 위상 변경은 서버가 브로드캐스트하고, 영업 중에는 1Hz로 드리프트를 보정한다.

enum Phase { PREP, SERVICE, SETTLEMENT }

signal phase_changed(phase: Phase)
signal day_advanced(day: int)

var day: int = 1
var phase: Phase = Phase.PREP
var service_elapsed: float = 0.0
## 영업 시간(초). 도시/설정 데이터로 조정 가능한 기본값.
var service_length: float = 180.0

var _drift_accum: float = 0.0


func _physics_process(delta: float) -> void:
	if phase != Phase.SERVICE:
		return
	if not multiplayer.is_server():
		# 클라이언트는 로컬 예측 진행, 서버 sync_clock이 보정한다.
		service_elapsed += delta
		return
	service_elapsed += delta
	_drift_accum += delta
	if _drift_accum >= 1.0:
		_drift_accum = 0.0
		sync_clock.rpc(day, phase, service_elapsed)
	if service_elapsed >= service_length:
		GameServer.on_service_time_over()


## 서버 전용: 위상 전환.
func set_phase(new_phase: Phase) -> void:
	assert(multiplayer.is_server())
	if new_phase == Phase.SERVICE:
		service_elapsed = 0.0
	phase = new_phase
	sync_clock.rpc(day, phase, service_elapsed)


## 서버 전용: 다음 날로 진행 (정산 → 준비).
func advance_day() -> void:
	assert(multiplayer.is_server())
	day += 1
	phase = Phase.PREP
	service_elapsed = 0.0
	sync_clock.rpc(day, phase, service_elapsed)
	day_advanced.emit(day)


@rpc("authority", "call_local", "reliable")
func sync_clock(p_day: int, p_phase: Phase, p_elapsed: float) -> void:
	var day_changed: bool = p_day != day
	var phase_was: Phase = phase
	day = p_day
	phase = p_phase
	service_elapsed = p_elapsed
	if day_changed:
		day_advanced.emit(day)
	if phase_was != phase:
		phase_changed.emit(phase)


func to_dict() -> Dictionary:
	return {"day": day, "phase": phase, "service_elapsed": service_elapsed}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	phase = int(data.get("phase", Phase.PREP)) as Phase
	service_elapsed = float(data.get("service_elapsed", 0.0))
