# 외부 캐릭터 모델 (.glb)

여기에 `.glb` 파일을 넣으면 게임이 절차 모델 대신 그 모델을 씁니다 (게임 실행 중에 직접 읽음, 에디터 임포트 불필요).

- 아군: `units/<유닛키>.glb` — 예: `units/bari.glb` (바리공주)
- 요괴: `yokai/<외형키>.glb` — 예: `yokai/bulgasari.glb` (불가사리)

유닛키는 `scripts/toy2_data.gd`의 `UNITS` 키, 외형키는 `ENEMIES`의 `look` 값입니다.
크기·방향·재질 사양과 시범 모델 브리프는 `docs/design/15_model_pipeline.md`를 보세요.
게임이 자동으로 키를 맞추고(유닛 1.45, 영웅 1.65, 보스 2.2), 발을 바닥에 맞추고, 셀 셰이딩과 외곽선을 입힙니다.
