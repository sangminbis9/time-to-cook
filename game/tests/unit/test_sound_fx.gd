extends GutTest
## 효과음 에셋 정합 (PLAN.md §34): SOUNDS 매핑의 모든 wav가 존재·로드 가능.


func test_all_sounds_loadable() -> void:
	assert_gt(SoundFx.SOUNDS.size(), 0, "효과음 매핑 존재")
	for sfx_name: StringName in SoundFx.SOUNDS.keys():
		var path: String = String(SoundFx.SOUNDS[sfx_name])
		assert_true(ResourceLoader.exists(path), "%s 파일 존재" % path)
		assert_true(load(path) is AudioStream, "%s 로드 가능" % path)


func test_pool_ready() -> void:
	# 재생 풀 + 배경음 플레이어 1개
	assert_eq(SoundFx.get_child_count(), SoundFx.POOL_SIZE + 1, "재생 풀 준비")


func test_buses_and_bgm() -> void:
	# 효과음·음악 버스 분리 (§35) + 배경음 무한 루프 (§34)
	assert_ne(AudioServer.get_bus_index("SFX"), -1, "SFX 버스 존재")
	assert_ne(AudioServer.get_bus_index("Music"), -1, "Music 버스 존재")
	var bgm: AudioStreamWAV = load(SoundFx.BGM_PATH) as AudioStreamWAV
	assert_not_null(bgm, "배경음 로드")
	assert_eq(bgm.loop_mode, AudioStreamWAV.LOOP_FORWARD, "루프 설정")


func test_volume_roundtrip() -> void:
	SoundFx.set_volume("SFX", 0.5)
	assert_almost_eq(SoundFx.get_volume("SFX"), 0.5, 0.01, "볼륨 저장·복원")
	SoundFx.set_volume("SFX", 1.0)
