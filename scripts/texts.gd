extends RefCounted
# Player-facing descriptions (Korean / English). Numbers must match sim/game_state.gd STRUCT and docs/design/01_rules.md v0.2.

const STRUCT_KO := {
	"hearth": ["본진", "당신의 마지막 불빛. 먹히면 패배.", "빛 3을 내고 주변 6칸에 빛 2, 두 칸 거리에 빛 1."],
	"lantern": ["등불", "기본 방어. 싸고 넓게 지킨다.", "자기 칸 빛 2, 주변 6칸 빛 1. 빛은 곧 방어력.\n쓸 때: 오염이 다가오는 쪽에 미리 깔기."],
	"brazier": ["화로", "불로 서리·포자를 태우는 방어.", "등불과 같은 빛(2/주변 1)에 더해, 매일 밤 주변 서리 오염 -1, 포자 오염 -2.\n쓸 때: 하늘색(서리)·노란색(포자) 오염이 올 때."],
	"beacon": ["봉화", "강한 빛 + 오염을 밀어내는 능력.", "빛 3 / 주변 2 / 두 칸 거리 1.\n능력 '정화': 봉화를 선택하고 정화 버튼 → 반경 2칸 모든 오염 -1 (빛3, 행동2, 4일마다).\n쓸 때: 넓은 지역을 지키고 반격할 때."],
	"palisade": ["목책", "가장 싼 땜질. 그 칸 방어 +1.", "놓은 칸 하나만 방어 +1 (빛 없음). 내구 2라 녹 오염에 약함.\n쓸 때: 빨간 삼각형 칸이 1 차이로 위험할 때."],
	"rampart": ["성벽", "튼튼한 벽. 그 칸 방어 +2.", "놓은 칸 하나만 방어 +2, 내구 4.\n쓸 때: 압력이 높은 최전선 칸."],
	"pyre": ["화염탑", "주변 오염을 단번에 태운다.", "능력 '화염 발사': 화염탑을 선택하고 버튼 → 주변 1칸의 강도 2 이하 오염을 모두 제거 (빛3, 행동1, 3일마다)."],
	"sunwell": ["태양우물", "땅을 되살리고 균열을 봉인한다.", "빛 1. 매일 반경 2칸의 파괴된 칸 하나를 복구.\n능력 '균열 봉인': 균열(빨간 테두리)이 2칸 이내면 봉인 (빛5, 행동2). 균열 2개 봉인 = 즉시 승리."],
	"camp": ["채집소", "자재 생산.", "매일 자재 +2 (숲·언덕 위), 그 외 +1.\n자재는 모든 건설의 재료."],
	"cottage": ["오두막", "주민(행동력) 증가.", "주민 상한 +2, 3일마다 주민 +1.\n주민 수 = 하루에 할 수 있는 행동 수."],
	"press": ["압착소", "빛(자원) 생산.", "매일 빛 +1 (수정 옆이면 +2).\n빛은 고급 건물·능력·유지비에 쓰임. 빛 건물 2개마다 매일 빛 1 유지비."],
}
const STRUCT_EN := {
	"hearth": ["Hearth", "Your last light. Lose it and you lose.", "Light 3, 2 on the 6 neighbours, 1 at distance 2."],
	"lantern": ["Lantern", "Basic defense. Cheap, covers an area.", "Light 2 on its hex, 1 on the 6 neighbours. Light = defense.\nUse: place ahead of approaching blight."],
	"brazier": ["Brazier", "Fire defense that burns Rime and Spore.", "Same light as a Lantern, plus each night: nearby Rime -1, Spore -2.\nUse: against cyan (Rime) and yellow (Spore) blight."],
	"beacon": ["Beacon", "Strong light + an ability that pushes blight back.", "Light 3 / 2 / 1.\nAbility BURST: select the Beacon, press Burst -> all blight within 2 hexes -1 (3 light, 2 actions, every 4 days)."],
	"palisade": ["Palisade", "Cheapest patch: +1 defense on its hex.", "+1 defense on that hex only (no light). Durability 2, weak to Rust.\nUse: when a red-triangle hex is short by 1."],
	"rampart": ["Rampart", "Solid wall: +2 defense on its hex.", "+2 defense on that hex only, durability 4.\nUse: front-line hexes under high pressure."],
	"pyre": ["Pyre", "Burns nearby blight in one go.", "Ability FIRE: select it, press the button -> clears blight of strength 2 or less on neighbours (3 light, 1 action, every 3 days)."],
	"sunwell": ["Sunwell", "Restores land and seals Rifts.", "Light 1. Each day restores one destroyed hex within 2.\nAbility SEAL: a Rift within 2 hexes can be sealed (5 light, 2 actions). Seal 2 Rifts = instant win."],
	"camp": ["Camp", "Produces materials.", "+2 materials per day on woodland/hill, +1 elsewhere."],
	"cottage": ["Cottage", "More people = more actions.", "+2 population cap, +1 person every 3 days. People = actions per day."],
	"press": ["Lamp Press", "Produces light (resource).", "+1 light per day (+2 next to crystal). Light buildings cost 1 light per 2 each day."],
}
const VAR_KO := {
	"murk": ["머크 (보라)", "가장 기본 오염. 이웃으로 한 칸씩 번진다. 습지에서 강함. 빛에 약함."],
	"rime": ["서리 (하늘색)", "직선으로 두 칸 너머까지 뻗어 벽을 건너뛴다. 걸린 건물 생산 절반. 화로에 약함."],
	"spore": ["포자 (노랑)", "강도 2부터 3칸 이내 아무 곳에 씨앗을 날린다. 초원·숲에서 강함. 화로에 매우 약함."],
	"rust": ["녹 (주황)", "건물이 있는 칸을 노리고 건물 내구를 깎는다. 빈 칸에선 약함. 성벽으로 버틴다."],
	"hollow": ["공허 (검정)", "주변 2칸의 방어를 1 낮춘다. 가장 밝은 곳 옆에 나타난다. 빛을 한곳에 몰지 말 것."],
}
const VAR_EN := {
	"murk": ["Murk (purple)", "Basic blight. Spreads hex by hex. Strong on marsh. Weak to light."],
	"rime": ["Rime (cyan)", "Reaches 2 hexes in straight lines, jumping walls. Halves production. Weak to Brazier."],
	"spore": ["Spore (yellow)", "At strength 2+ drops seeds anywhere within 3. Strong on meadow/woods. Very weak to Brazier."],
	"rust": ["Rust (orange)", "Targets hexes with buildings and wears them down. Weak on empty hexes."],
	"hollow": ["Hollow (black)", "Lowers defense by 1 within 2 hexes. Appears next to your brightest hex."],
}
const TERR_KO := {
	"meadow": "초원: 평범. 포자에 약함.", "woodland": "숲: 채집소 자재 +1. 포자에 약함.", "hill": "언덕: 머크·서리 상대로 방어 +1, 채집소 +1.",
	"marsh": "습지: 머크가 강해짐.", "ruins": "유적: 특별한 효과 없음 (추후 로어).", "crystal": "수정: 옆 압착소 빛 +1.",
	"shore": "물가: 녹이 강해짐.", "salt": "소금밭: 포자에 강함.", "frost": "서리밭: 서리가 강해짐.", "cinder": "잿더미: 포자에 강함, 서리에 약함.",
}
const TERR_EN := {
	"meadow": "Meadow: plain. Weak to Spore.", "woodland": "Woodland: Camp +1. Weak to Spore.", "hill": "Hill: +1 defense vs Murk/Rime, Camp +1.",
	"marsh": "Marsh: Murk is stronger.", "ruins": "Ruins: no effect yet.", "crystal": "Crystal: adjacent Lamp Press +1 light.",
	"shore": "Shore: Rust is stronger.", "salt": "Salt flat: resists Spore.", "frost": "Frost field: Rime is stronger.", "cinder": "Cinder: resists Spore, weak to Rime.",
}
