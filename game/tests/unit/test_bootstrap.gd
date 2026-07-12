extends GutTest
## P0 트리비얼 테스트: 테스트 파이프라인과 프로젝트 골격이 살아있는지 확인.


func test_gut_pipeline_alive() -> void:
	assert_true(true, "GUT가 headless로 실행된다")


func test_save_version_constant() -> void:
	assert_eq(SaveService.SAVE_VERSION, 2)


func test_defs_registry_loaded() -> void:
	assert_gt(Defs.all_ids().size(), 0, "정의 데이터가 로드되어야 함")
