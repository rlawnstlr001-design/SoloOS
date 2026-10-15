# 02. 지형, 구조물, 기술, 유물, 메타 해금

모든 비용·수치는 [가설] 초기값. **한 칸에는 구조물 1개**만 지을 수 있다 → 방어 칸 = 생산하지 못하는 칸이라는 핵심 긴장.

## 1. 지형 (10종)
| 지형 | 특성 | 변종 보정(압력/Guard) |
|---|---|---|
| Meadow(초원) | 기본, 수확 보통 | Spore 압력 +1 |
| Woodland(숲) | Matter 수확 +1, 화염 위험 | Spore 압력 +1, Brazier 3일 후 Cinder로 변함 |
| Hill(언덕) | 시야/사거리 +1 | Murk·Rime에 Guard +1 |
| Marsh(습지) | Lumen 펌프 적합 | Murk 압력 +1, Rust 압력 -1 |
| Ruins(유적) | 로어 조각, Library 보너스 | 변화 없음 |
| Crystal(수정) | Lumen 수확 +1, Prism 사거리 +1 | Hollow 압력 +1 (빛에 끌림) |
| Shore(물가) | 펌프, 우물 | Rust 압력 +1 |
| Salt Flat(소금밭) | 척박, Ward 효율 +1 | Spore·Murk 압력 -1 |
| Frostfield(서리밭) | 척박 | Rime 압력 +1 |
| Cinder(잿더미) | 척박, 영구 | Spore 면역, Rime 압력 +1 |
특수 칸: Shrine(동료 이벤트), Camp(캐러밴), Wellspring(Lumen +2), Old Node(Lattice 유적, 조기 Beacon 건설 가능), Rift(오염 발생원).

## 2. 구조물 (30종)
T1 기본 해금 / T2~T4는 메타 해금. 업그레이드(Lv II): 비용 +50%, 2 LP, 효과 강화.
| # | 구조물 | 분류 | T | 비용 | 효과 |
|---|---|---|---|---|---|
| 1 | Hearth | 핵심 | - | 시작 | Light 3, Folk 상한 4. 파괴 = 패배 |
| 2 | Gatherer's Camp | 경제 | 1 | 4M | 일 +2M (숲/언덕), 그 외 +1M |
| 3 | Cottage | 경제 | 1 | 5M | Folk 상한 +2, 3일마다 +1 Folk |
| 4 | Lamp Press | 경제 | 1 | 4M | 일 +1L (인접 Crystal 시 +2L) |
| 5 | Workshop | 경제 | 2 | 6M 2L | 건설 비용 -1M(최소 1), 인접 Camp +1M |
| 6 | Library | 경제 | 2 | 6M 3L | 3일마다 인사이트 +1 (Ruins 인접 +1) |
| 7 | Market | 경제 | 2 | 5M 2L | 3M↔2L 교환(일 1회), 리롤 -1L |
| 8 | Storehouse | 경제 | 2 | 4M | 자원 상한 +10, 스테이지 이월 75% |
| 9 | Tidal Pump | 경제 | 2 | 5M 2L | 물가/습지에서 일 +2L |
| 10 | Lantern | 빛 | 1 | 3M 1L | Light 2/1 |
| 11 | Beacon Spire | 빛 | 2 | 6M 3L | Light 3/2/1, 능력 Beacon Burst(3L 2LP, 반경2 강도-1, 쿨3일) |
| 12 | Prism Tower | 빛 | 3 | 7M 4L | 한 방향 4칸 직선, Dusk마다 강도 -1 (방벽에 막힘) |
| 13 | Mirror Array | 빛 | 3 | 6M 3L | 인접 Lantern/Beacon 빛 반경 +1 (중첩 불가) |
| 14 | Sunwell | 빛 | 4 | 10M 6L | 반경2 Scar 하루 1칸 복구, Rift 봉인(5L) |
| 15 | Brazier | 화염 | 1 | 4M 2L | Light 2/1, 인접 Rime/Spore 강도 -1(Spore -2) |
| 16 | Kiln | 화염 | 2 | 5M 2L | 인접 Brazier 효과 +1 |
| 17 | Pyre | 화염 | 3 | 7M 3L | 능력: 반경1 강도≤2 전부 제거(5L 2LP, 쿨4일) |
| 18 | Forge Beacon | 화염 | 4 | 10M 5L | Pyre/Brazier 범위 +1, 스테이지당 1회 Eruption(반경3 Murk/Rime 소거) |
| 19 | Palisade | 방벽 | 1 | 2M | Guard +1, HP 2, Hollow 흡입 차단 |
| 20 | Rampart | 방벽 | 2 | 4M 1L | Guard +2, HP 4, 인접 Palisade +1 |
| 21 | Salt Line | 방벽 | 2 | 3M 1L | Guard +1, 인접 칸 포자 낙하 불가, 서리 동결 면역 |
| 22 | Gate Ward | 방벽 | 3 | 5M 2L | Guard +2, 인접 칸 Rust 피해 -1 |
| 23 | Aegis Obelisk | 방벽 | 4 | 9M 5L | 반경1 Guard +3, 능력: Hearth 1 Dusk 면역(스테이지당 1회) |
| 24 | Brightbloom Planter | 성장 | 1 | 3M 1L | Light 1, 2일마다 인접 빈 Lit 칸에 Bloom(Light 1) 생성 |
| 25 | Orchard | 성장 | 2 | 5M 2L | 초원에서 일 +2L +1M, 포자 압력 +1(유인) |
| 26 | Hedgemaze | 성장 | 3 | 6M 2L | 인접 칸 헤럴드 이동 -1, Rime 점프 차단 |
| 27 | Heartroot | 성장 | 4 | 10M 6L | Light 2 반경2, 3일마다 +1 성장(최대 3), HP 3 |
| 28 | Watchtower | 지원 | 2 | 4M 1L | 예고 +1 Dusk, 오멘 하루 일찍 공지 |
| 29 | Shrine | 지원 | 2 | 4M 2L | 3일마다 동료 이벤트(선택지) |
| 30 | Cartographer's Post | 지원 | 3 | 6M 3L | 타일 카드 4장 제시, Fog 반경2 공개 |

설계 의도:
- 방어는 **변종별 카운터**가 다르다 (03 문서). 한 가지만 쌓으면 적응 시스템이 압박한다.
- Bloom(성장)은 오염의 "번지기"를 거울처럼 흉내 내는 플레이어 쪽 확산 수단 → 시그니처 연출.
- 지속 유지: 구조물은 재배치 불필요, 일괄 건설(드래그)과 템플릿 복사로 UI 노동 최소화.

## 3. 인사이트 트리 (인런 기술, 4계열 x 5티어)
Library/키퍼 레벨로 얻는 인사이트 포인트(스테이지당 6~8개). 티어 N 선택에는 같은 계열 N-1 필요. 계열 간 혼합으로 빌드 형성.
| 티어 | Light(빛) | Flame(화염) | Ward(방벽) | Growth(성장) |
|---|---|---|---|---|
| 1 | Brighter Wicks: Lantern Light +1 | Kindling: Brazier 비용 -1L | Thick Timber: Palisade HP +1 | Brightbloom: Planter 주기 -1일 |
| 2 | Long Shadow: Beacon 반경 +1 | Controlled Burn: Pyre 쿨 -1 | Salt Rampart: Rampart에 Salt 효과 | Root Net: Bloom Guard +1 |
| 3 | Refraction: Prism 길이 +1 | Hotter Flames: Brazier가 강도2 대응 | Bulwark Network: 인접 방벽 HP 공유 | Fertile Ground: 수확 +1 |
| 4 | Lightbearer: 키퍼 주변 Light +1 | Ember Chain: 화염이 Rime/Spore를 연쇄 | Reflection: 방벽이 헤럴드에 피해 | Seedcast: Bloom이 2칸 점프 |
| 5 | **Dawn Engine**: Sunwell 2칸/일 복구 | **Pyre Storm**: 스테이지당 1회 Taint 전부 소거 | **Aegis**: Hearth 1 Dusk 추가 면역 | **World Tree**: Heartroot 영구 성장 |

## 4. 유물 (60종 목표)
캠프에서 3택1. 분류 [가설]: Light 12 / Flame 10 / Ward 10 / Growth 8 / 경제 10 / 와일드카드(저주·교환형) 10.
예시:
- Cracked Lens: Prism 길이 +1, Prism이 Wild 칸을 비춤
- Warden's Flint: 첫 Brazier 무료
- Tallow Charm: 매일 +1L, Lantern 건설 시 +1M
- Moth Cloak: Dusk마다 가장 약한 Lit 칸 Guard +1
- Seed Satchel: 타일 보관 2장
- Rift Compass: 모든 Rift의 방출 대상 미리 표시
- Pact of Embers (저주): Ember x1.3, 단 Hearth Light -1
- Hollow Eye (저주): 예고 +1, 단 Hollow 변종 등장
- Glass Heart (와일드): Aegis 능력 쿨다운 대신 Ember 비용
- Hunter's Map: Fog 공개 +2, 확장 위험 보상 x2
- Iron Pledge: Rampart 건설 시 Palisade 1개 무료
- Wick of Dawn: 스테이지 시작 시 랜덤 Lit 칸에 Lantern 무료

## 5. 메타 해금 트리 (Haven, 약 60노드)
화폐: Ember. 총 비용 약 6,000 Ember [가설] ≈ 원정 45회 ≈ 25~35시간 (평균 원정 120~150 Ember).
| 그룹 | 노드 | 내용 |
|---|---|---|
| 키퍼 | 4 | Mara/Odo/Sable/Quill 해금 (Ash는 스토리 해금) |
| 구조물 | 21 | T2~T4 구조물 21종 해금 |
| 타일 | 8 | 특수 타일 카드(Shrine, Camp, Wellspring, Old Node 등) 풀 확장 |
| 유물 팩 | 6 | 유물 5~6개씩 풀에 추가 (총 30종, 나머지 30종 기본) |
| 시스템 | 6 | Satchel 확대, 되돌리기 개선, 데일리 시드, 리플레이 저장, Gentle 세분화, 커스텀 난이도 |
| 소수치 | 6 | 시작 L+2 / M+2 / 리롤 -1 등. **합산 상한 +10%** (그라인드 방지) |
| 동료 | 9 | 동료 12명 중 9명이 Haven 건설로 해금(이야기 기반), 3명은 이벤트 획득 |
설계 원칙:
- 수치 강화보다 **선택지 추가**가 우선. 해금하지 않아도 클리어 가능해야 한다 (메인 클리어는 T3 이하로 가능 [가설]).
- 비용 곡선: 20 → 400 Ember 완만 증가. 한 번에 3~4개씩 해금되는 마일스톤 단위.
