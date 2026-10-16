extends Node
var music: AudioStreamPlayer
var effects: Array = []
var phase: String = ""
var last_effect: Dictionary = {}

func _ready() -> void:
	for bus in ["Music","Effects"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
	music=AudioStreamPlayer.new();music.bus="Music";add_child(music)
	for i in range(6):
		var player=AudioStreamPlayer.new();player.bus="Effects";add_child(player);effects.append(player)
	music.finished.connect(func():music.play())

func set_phase(value: String) -> void:
	var next="business" if value in ["business","closing"] else "morning"
	if next==phase:return
	phase=next;music.stream=load("res://rebuild/assets/%s.wav"%phase);music.play()

func play(name: String) -> void:
	if Time.get_ticks_msec()-int(last_effect.get(name,-9999))<150:return
	last_effect[name]=Time.get_ticks_msec()
	for player in effects:
		if not player.playing:
			var path="res://rebuild/assets/%s.wav"%name
			if ResourceLoader.exists(path):player.stream=load(path);player.play()
			break

func volume(bus: String,value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(maxf(.0001,value)))
