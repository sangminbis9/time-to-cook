extends Node
## ENet 세션 수명 관리. 호스트=서버=피어 1=세이브 소유자.
## 싱글플레이도 동일하게 로컬 ENet 서버를 열어 코드 경로를 통일한다.

signal session_started(is_host: bool)
signal session_ended(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 2

var is_session_active: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## 호스트 시작 (싱글플레이 포함 — 항상 서버를 연다).
func host(port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_session_active = true
	session_started.emit(true)
	return OK


## 게스트 참가.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave(reason: String = "") -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	_reset_to_offline()
	session_ended.emit(reason)


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		GameServer.on_peer_left(peer_id)
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	is_session_active = true
	session_started.emit(false)


func _on_connection_failed() -> void:
	_reset_to_offline()
	session_ended.emit("connection_failed")


func _on_server_disconnected() -> void:
	# 호스트가 나가면 세션 종료 (PLAN.md §4.2).
	_reset_to_offline()
	session_ended.emit("host_left")


## 세션 종료 후 오프라인 피어로 복귀 — null이면 multiplayer API 호출마다 에러
func _reset_to_offline() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_session_active = false
