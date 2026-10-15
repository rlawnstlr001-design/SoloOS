# 03. 오염 도감 (적 설계)

핵심 원칙: **적은 유닛이 아니라 규칙이다.** 경로탐색 없이 결정론적 규칙으로 움직이고, 모든 움직임은 예고된다.
스프라이트/연출은 변종마다 형태 언어(둥글다/각지다/흩날린다)로 구분 → 색맹 접근성 확보.

## 1. 오염 변종 5종
| 변종 | 형태 언어 | 확산 규칙 (01 문서 기본 규칙에 추가) | 약점 / 카운터 | 강점 / 위협 |
|---|---|---|---|---|
| **Murk** (머크) | 둥근 진흙, 느린 맥동 | 기본 압력 확산. 습지 압력 +1 | Lantern, Beacon, Prism (빛) | 가장 예측 쉬움. 입문 변종 |
| **Rime** (림) | 각진 서리 결정 | 강도≥2는 직선 6방향으로 거리 2 칸에 (강도-1) 압력(**Reach**). 강도≥1 구조물 생산 절반(**Freeze**) | Brazier/Kiln/Pyre (화염), Hedgemaze(점프 차단), Salt Line(동결 면역) | 방벽을 건너뛰어 후방을 공략 |
| **Spore** (포자) | 점점이 퍼진 버섯 | 초원/숲 압력 +1. 강도≥2는 Dusk마다 **씨앗 1개** 낙하(반경 3, 시드 해시로 결정, 2 Dusk 전 공지) | Brazier(-2), Salt Line(인접 낙하 불가), 소금밭, Cinder 면역 | 방벽 무시하고 도약, 넓게 흩어짐 |
| **Rust** (러스트) | 비늘처럼 벗겨지는 녹 | 구조물 있는 칸 압력 +1, 빈 칸 -1. 오염된 칸의 구조물은 Dusk마다 HP -1 | Gate Ward, 빈 완충칸, 펌프/우물(물가는 +1 주의) | 건물을 갉아먹음, 지은 것이 약점 |
| **Hollow** (할로) | 구멍/나선, 빛 삼킴 | 인접 확산은 약함(압력 -1). 오염 칸 반경 2의 Guard -1. **Seed**: 3 Dusk마다 가장 밝은 구조물 인접 Wild 칸에 출현(공지) | Salt Line(인접 출현 불가), Pyre, 빛을 여러 곳에 분산 | "빛을 한곳에 몰면 노출" 방지 → 거북이 전략 억제 |

### 변종-도구 카운터 매트릭스 (◎ 강함 / ○ 보통 / △ 약함)
| | Light(빛) | Flame(화염) | Ward(방벽) | Growth(성장) |
|---|---|---|---|---|
| Murk | ◎ | ○ | ○ | ○ |
| Rime | △ | ◎ | △ (Reach로 우회) | ○ |
| Spore | ○ | ◎ | △ (도약) | △ |
| Rust | ○ | △ | ◎ (Gate Ward) | ○ |
| Hollow | △ (밝을수록 표적) | ◎ (Pyre) | ○ | ◎ (Bloom 분산) |
어떤 도구도 모든 변종에 ◎가 아니다 → 지역마다 도구 구성을 바꿔야 한다.

## 2. 적응 시스템 (Adaptation) — 지배 전략 방지
- 각 도구 계열(Light/Flame/Ward/Growth)이 최근 3 Dusk 동안 기여한 **정화/압력 상쇄량의 비율**을 추적.
- 한 계열 비중 > 60% 이고 절대량 ≥ 6이면, 다음 Dusk부터 오염이 그 계열에 **내성(Resist)** 획득: 그 계열의 기여가 2 Dusk 동안 -1.
- **결정론적이며 하루 전에 경고**한다 (적응 아이콘). 다른 계열 기여가 40% 이상인 Dusk가 있으면 해제.
- 의도: 전문화는 허용하되 단일 해법 스팸은 비효율. 내성은 완전 면역이 아니라 -1 수준이라 절벽이 아니다.

## 3. 헤럴드 (보스, 7종)
스테이지 3(원정 마지막)에 등장. Presence: 반경 1 칸에 압력 +2. 체력(Hold) 12 [D0]. 50%에서 2단계.
격퇴 수단: Beacon Burst(4), Pyre(4), Prism 라인(2/Dusk), Reflection(방벽 접촉 2) 등.
| # | 헤럴드 | 지역 | 변종 | 규칙 | 약점 |
|---|---|---|---|---|---|
| 1 | **Mother Mold** | Meadowmere | Murk/Spore | 8일차까지 고정, 이후 기어서 이동. 매 Dusk 씨앗 2개 | 화염 |
| 2 | **The Hushwood** | Pinewall | Spore/Rime | 걷는 죽은 숲. "Hush": 반경 2 Lantern Light -1 | Pyre, Brazier |
| 3 | **Brinequeen** | Saltmarsh | Rust/Murk | 물길을 따라 이동. 매 Dusk 물가/습지 홍수(Rust 압력 +1) | Prism, Gate Ward |
| 4 | **The Rustbound** | Ironhill | Rust/Rime | 갑옷 골렘. 방벽 반사 면역. 구조물이 가장 밀집한 칸으로 이동 | Prism, Beacon Burst |
| 5 | **Pale Choir** | Glassreach | Rime/Hollow | 유령 3체를 모두 격퇴. 각자 직선 이동하며 Rime 투사 | Brazier 라인업 |
| 6 | **Ember Hollow** | Emberdeep | Hollow/Spore | 살아있는 싱크홀. 가장 밝은 칸으로 이동, 반경 2 어둡게 | 빛 분산, Pyre |
| 7 | **The First Warden** | Aureole | 전 변종 | 3단계(Murk+Rime → Hollow → 선택). 05 문서 참조 | 전체 |
이동 규칙: 턴당 1~2칸, 그리디(목표 칸 규칙 고정, 경로탐색 불필요). 이동 목표는 항상 예고선으로 표시.

## 4. 오멘 (돌발 변수, 16종)
하루 전에 공지. 대부분 양면성(이득+위험)을 가진다.
1. Long Night — 다음 Dusk 모든 압력 +1
2. Fog Bloom — Wild 칸 2개가 Fog로 되돌아감
3. Merchant Caravan — 유물 1개를 M으로 구매 가능
4. Wandering Warden — 동료 이벤트 + 인사이트 +1
5. Eclipse — 한 Dusk 동안 모든 Light -1
6. Wildfire — 숲 칸 점화: 숲 위 Spore 소각, 숲 위 내 구조물도 피해
7. Cold Snap — Rime 압력 +1, Spore 압력 -1
8. Rain — Brazier 비활성, Rust +1, Spore -1, Lamp Press +1L
9. Crystal Rain — Crystal 칸 수확 +2L
10. Rift Surge — Rift 1개 이중 방출
11. Bountiful Harvest — 오늘 Matter +50%
12. Plague of Moths — 빛 구조물 Light -1 / 대신 Lumen +1
13. Restless Dead — Ruins 칸에서 Taint 씨앗 (대신 로어 조각 획득)
14. Dawn Whisper — 다음 Dusk Hearth 반경 2 확산 정지
15. Tidal Surge — 물가 칸 구조물 HP -1, Pump 수확 x2
16. Herald's Shadow — 스테이지 3 헤럴드 사전 예고 + 약점 공개

## 5. Dimlings (선택 요소, Could)
D3 이상에서 강도 2 칸에서 태어나는 작은 오염체. 매 Dusk 1칸 이동(가장 가까운 Light≤1 구조물로), 도착 시 HP -1.
Lantern 인접 칸에 있으면 Dusk에 소멸. 형태 3종(기어다님/날아다님/굴러감). 구현·밸런싱 비용 때문에 M3 이후 평가.

## 6. 환경 생물 (Ambient, 연출용)
무해. 반딧불, 나방, 사슴 실루엣, 새, 두더지, 고양이. 오염에 닿으면 사라지고, 정화하면 돌아온다 (정화의 시각적 보상).
