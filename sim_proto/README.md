# sim_proto — DIMHOLD 규칙 시뮬레이션 (Python, 헤드리스)

docs/design/01_rules.md 의 규칙을 구현하고 봇이 수천 판을 플레이해 클리어율을 측정한다.
확정된 규칙은 이후 Godot(GDScript) sim 레이어로 이식한다.

    cd sim_proto
    python3 run_experiments.py R1,R2 B   # 변종 6세트 x 봇 5종 매트릭스
    python3 calibrate.py                 # 난이도 보정 격자
    python3 tweaks.py B                  # 구조물 비용 변경 영향

- `duskhold.py`: 보드, 압력/Guard, 적응, 변종 5종, 경제, Dusk 해결
- `bots.py`: random / lantern_only / wall_only / flame_only / mixed(예고 기반 탐욕)
- 알려진 한계: Beacon Burst·Pyre·Sunwell·Rift 봉인·인사이트·유물·Growth 계열·Bloom 미구현.
  Rift는 최대 3개(RIFT_TILES 고정). 봇은 단순해 자원의 일부만 사용한다.
