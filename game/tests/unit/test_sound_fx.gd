extends GutTest
## 효과음 에셋 정합 (PLAN.md §34): SOUNDS 매핑의 모든 wav가 존재·로드 가능.


func test_all_sounds_loadable() -> void:
	assert_gt(SoundFx.SOUNDS.size(), 0, "효과음 매핑 존재")
	for sfx_name: StringName in SoundFx.SOUNDS.keys():
		var path: String = String(SoundFx.SOUNDS[sfx_name])
		assert_true(ResourceLoader.exists(path), "%s 파일 존재" % path)
		assert_true(load(path) is AudioStream, "%s 로드 가능" % path)


func test_pool_ready() -> void:
	assert_eq(SoundFx.get_child_count(), SoundFx.POOL_SIZE, "재생 풀 준비")
