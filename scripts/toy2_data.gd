extends RefCounted
# Content tables for 도깨비 디펜스: kins, units + skills, recipe heroes, relics, yokai + traits, acts, synergy.
# Rules live in toy2.gd, models in toy2_art.gd. Lore sources and design notes: docs/design/12_folklore_content.md.

const KINS := {
	"dokkaebi": ["도깨비", Color(0.90, 0.30, 0.25)],
	"sinsu": ["신수", Color(0.95, 0.78, 0.30)],
	"muin": ["무인", Color(0.35, 0.60, 0.95)],
	"jusul": ["주술", Color(0.65, 0.40, 0.95)],
	"sinseon": ["신선", Color(0.40, 0.85, 0.65)],
	"sugun": ["수군", Color(0.25, 0.75, 0.90)],
}
# kin synergy by number of same-kin units on the board (effects coded in toy2.gd)
const SYN_STEPS := [2, 4, 6]
const SYN := {
	"dokkaebi": ["도깨비 놀음", ["뚝딱 확률 2배", "+ 도깨비 공격력 +25%", "+ 처치마다 골드 +1"]],
	"sinsu": ["신령의 가호", ["아군 전체 보스 피해 +25%", "아군 전체 보스 피해 +50%", "아군 전체 보스 피해 +90%"]],
	"muin": ["진법", ["무인 사거리 +0.5", "사거리 +1.0, 공격 속도 +10%", "사거리 +1.5, 공격 속도 +20%"]],
	"jusul": ["씻김굿", ["둔화 지속 +50%", "+ 처형 기준 +5%p", "+ 주술 MP 충전 +50%"]],
	"sinseon": ["도술", ["신선 스킬 피해 +30%", "스킬 피해 +60%, MP 충전 +25%", "스킬 피해 +100%, MP 충전 +50%"]],
	"sugun": ["수군 진형", ["수군 범위 +0.3", "+ 장갑 절반 무시", "범위 +0.6, 공격력 +25%"]],
}

# unit: n, kin, dmg, int (attack interval), rng, spl (splash radius), slow, sp (special), d, fire (불 속성)
#  sp: gold(뚝딱) multi(2타겟) pierce(3타겟) boss(보스+50%) exec/exec30(처형) stun(타격 기절) holy(영체·장갑 무시)
#      exorcist(영체·역병 ×2) dispel(맞은 요괴 능력 봉인) crit(25% 치명 ×3)
# sk: MP skill (영웅 등급 이상, 레시피 영웅) — k kind + params, see toy2.gd cast()
const UNITS := {
	# 도깨비
	"dokkaebi": {"n": "방망이 도깨비", "kin": "dokkaebi", "dmg": 11.0, "int": 0.6, "rng": 3.6, "spl": 0.0, "slow": 0.0, "sp": "gold",
		"d": "방망이로 때린다. 8% 확률로 '금 나와라 뚝딱' (+1골드).",
		"sk": {"n": "금 나와라 뚝딱", "k": "gold", "g": 12, "d": "방망이를 두드려 골드 +12 (전설은 더)."}},
	"dokkaebibul": {"n": "도깨비불", "kin": "dokkaebi", "dmg": 9.0, "int": 0.7, "rng": 3.8, "spl": 1.0, "slow": 0.0, "sp": "", "fire": true,
		"d": "밤길에 떠도는 푸른 불. 작은 범위를 태운다 (불 속성).",
		"sk": {"n": "불 무리", "k": "nuke", "r": 2.4, "m": 4.5, "d": "불덩이 무리가 넓은 범위를 태운다."}},
	"ssireum": {"n": "씨름 도깨비", "kin": "dokkaebi", "dmg": 22.0, "int": 1.2, "rng": 3.2, "spl": 0.0, "slow": 0.0, "sp": "stun",
		"d": "밤길에 씨름을 거는 도깨비. 맞은 요괴가 잠깐 멈춘다.",
		"sk": {"n": "밤샘 씨름", "k": "boss", "m": 8.0, "hold": 3.0, "d": "가장 강한 요괴를 붙잡아 3초 멈추고 큰 피해 (보스는 절반)."}},
	"bihyeong": {"n": "비형랑", "kin": "dokkaebi", "dmg": 8.0, "int": 0.7, "rng": 4.0, "spl": 0.0, "slow": 0.0, "sp": "multi",
		"d": "『삼국유사』 반은 귀신인 신라 화랑. 귀신 무리를 부려 둘을 동시에 친다.",
		"sk": {"n": "귀교(鬼橋)", "k": "slow", "t": 4.5, "d": "하룻밤에 놓은 귀신 다리: 모든 요괴 4.5초 둔화."}},
	# 신수
	"haetae": {"n": "해태", "kin": "sinsu", "dmg": 30.0, "int": 2.0, "rng": 5.0, "spl": 0.8, "slow": 0.0, "sp": "boss",
		"d": "시비를 가리는 신수. 느리지만 강한 일격, 보스에게 피해 +50%.",
		"sk": {"n": "시비 판별", "k": "boss", "m": 12.0, "d": "체력이 가장 많은 요괴에게 일격 (공격력 ×12)."}},
	"gumiho": {"n": "구미호", "kin": "sinsu", "dmg": 10.0, "int": 0.6, "rng": 3.8, "spl": 0.0, "slow": 0.0, "sp": "multi", "fire": true,
		"d": "여우불로 요괴 두 마리를 동시에 공격 (불 속성).",
		"sk": {"n": "홀림", "k": "stun", "t": 1.6, "d": "모든 요괴를 1.6초 홀려 멈춘다 (보스는 절반)."}},
	"samjogo": {"n": "삼족오", "kin": "sinsu", "dmg": 14.0, "int": 0.9, "rng": 5.0, "spl": 0.0, "slow": 0.0, "sp": "pierce", "fire": true,
		"d": "고구려 벽화의 해 속 세 발 까마귀. 햇살이 셋을 꿰뚫는다 (불 속성).",
		"sk": {"n": "일광", "k": "chain", "n_t": 8, "m": 3.0, "d": "햇살이 가장 앞선 요괴 8마리를 태운다."}},
	"hyeonmu": {"n": "현무", "kin": "sinsu", "dmg": 10.0, "int": 1.0, "rng": 3.8, "spl": 0.8, "slow": 0.45, "sp": "",
		"d": "북쪽 수호신. 뱀이 거북을 휘감은 모습. 맞은 요괴를 느리게 한다.",
		"sk": {"n": "북방 결계", "k": "buff", "t": 6.0, "m": 1.4, "d": "주변 유닛 공격 속도 ×1.4 (6초)."}},
	# 무인
	"gungsa": {"n": "궁사", "kin": "muin", "dmg": 8.0, "int": 0.4, "rng": 4.4, "spl": 0.0, "slow": 0.0, "sp": "",
		"d": "각궁을 쏘는 활잡이. 빠르고 멀리 쏜다.",
		"sk": {"n": "애기살 연사", "k": "chain", "n_t": 6, "m": 2.5, "d": "가장 앞선 요괴 6마리에게 화살 (공격력 ×2.5)."}},
	"posu": {"n": "포수", "kin": "muin", "dmg": 40.0, "int": 2.2, "rng": 6.0, "spl": 0.0, "slow": 0.0, "sp": "",
		"d": "범도 잡는 사냥꾼. 가장 멀리서 강한 한 발.",
		"sk": {"n": "조총 일제사격", "k": "chain", "n_t": 3, "m": 6.0, "by": "hp", "d": "체력이 많은 요괴 3마리를 저격 (공격력 ×6)."}},
	"hwarang": {"n": "화랑", "kin": "muin", "dmg": 16.0, "int": 0.7, "rng": 3.4, "spl": 0.0, "slow": 0.0, "sp": "",
		"d": "신라의 청년 수련 집단. 환두대도를 든 근접 검객.",
		"sk": {"n": "임전무퇴", "k": "buff", "t": 5.0, "m": 1.5, "d": "주변 유닛 공격 속도 ×1.5 (5초)."}},
	"seungbyeong": {"n": "승병", "kin": "muin", "dmg": 13.0, "int": 0.8, "rng": 3.6, "spl": 0.0, "slow": 0.0, "sp": "holy",
		"d": "고려 항마군의 후예. 영체·장갑을 무시하고 요괴를 친다.",
		"sk": {"n": "항마진", "k": "nuke", "r": 2.4, "m": 4.0, "d": "넓은 범위에 영체·장갑을 무시하는 피해."}},
	# 주술
	"mudang": {"n": "무당", "kin": "jusul", "dmg": 12.0, "int": 1.1, "rng": 3.6, "spl": 1.3, "slow": 0.0, "sp": "",
		"d": "굿판을 벌여 주변 요괴를 한꺼번에 공격.",
		"sk": {"n": "작두굿", "k": "nuke", "r": 2.6, "m": 5.0, "d": "넓은 범위에 큰 피해 (공격력 ×5)."}},
	"jeoseung": {"n": "저승사자", "kin": "jusul", "dmg": 7.0, "int": 0.9, "rng": 3.8, "spl": 0.0, "slow": 0.0, "sp": "exec",
		"d": "체력 15% 이하인 요괴를 즉시 저승으로 데려간다 (보스 제외).",
		"sk": {"n": "명부 호명", "k": "exec", "thr": 0.4, "d": "사거리 안 체력 40% 이하 요괴를 모두 데려간다. 보스에겐 큰 피해."}},
	"cheoyong": {"n": "처용", "kin": "jusul", "dmg": 10.0, "int": 0.9, "rng": 4.0, "spl": 1.0, "slow": 0.0, "sp": "exorcist",
		"d": "『삼국유사』 노래와 춤으로 역신을 물리친 동해 용의 아들. 영체·역병 요괴에게 ×2.",
		"sk": {"n": "처용무", "k": "stun", "t": 2.2, "d": "춤으로 모든 요괴를 2.2초 물러서게 한다."}},
	"pansu": {"n": "판수", "kin": "jusul", "dmg": 7.0, "int": 1.0, "rng": 4.2, "spl": 1.6, "slow": 0.0, "sp": "dispel",
		"d": "경문을 읽어 악귀를 쫓는 독경무. 맞은 요괴의 능력(장갑·은신·재생·수호)을 잠깐 봉인.",
		"sk": {"n": "독경", "k": "dispel", "t": 8.0, "m": 2.0, "d": "사거리 안 요괴의 능력을 8초 봉인하고 피해."}},
	# 신선
	"jeonuchi": {"n": "전우치", "kin": "sinseon", "dmg": 12.0, "int": 0.55, "rng": 4.0, "spl": 0.0, "slow": 0.0, "sp": "multi",
		"d": "『전우치전』 도술로 임금도 속인 도사. 둘을 동시에 친다.",
		"sk": {"n": "분신술", "k": "buff_self", "t": 6.0, "m": 2.4, "d": "분신을 만들어 6초 동안 공격 속도 ×2.4."}},
	"honggildong": {"n": "홍길동", "kin": "sinseon", "dmg": 18.0, "int": 0.5, "rng": 3.6, "spl": 0.0, "slow": 0.0, "sp": "crit",
		"d": "『홍길동전』 둔갑장신의 의적. 25% 확률로 치명타 ×3.",
		"sk": {"n": "둔갑", "k": "chain", "n_t": 4, "m": 5.0, "by": "hp", "d": "몸을 감추고 체력 많은 요괴 4마리를 급습."}},
	"baksi": {"n": "박씨부인", "kin": "sinseon", "dmg": 15.0, "int": 1.2, "rng": 4.2, "spl": 1.5, "slow": 0.0, "sp": "",
		"d": "『박씨전』 도술 여걸. 범위 도술 공격.",
		"sk": {"n": "피화당 나무진", "k": "slow", "t": 6.0, "d": "나무 결계로 모든 요괴 6초 둔화."}},
	"mago": {"n": "마고할미", "kin": "sinseon", "dmg": 26.0, "int": 1.8, "rng": 4.6, "spl": 1.2, "slow": 0.0, "sp": "",
		"d": "산과 강을 만든 거인 할미. 바위를 던진다.",
		"sk": {"n": "산 만들기", "k": "nuke", "r": 3.0, "m": 6.0, "d": "큰 바위를 떨어뜨려 넓은 범위에 큰 피해."}},
	# 수군
	"mulgwisin": {"n": "물귀신", "kin": "sugun", "dmg": 5.0, "int": 0.8, "rng": 3.8, "spl": 0.0, "slow": 0.45, "sp": "",
		"d": "물에서 죽은 넋. 요괴의 발목을 잡아 느리게 만든다.",
		"sk": {"n": "물귀신 작전", "k": "push", "dist": 4.0, "d": "모든 요괴를 길 뒤쪽으로 끌어당긴다 (보스는 조금)."}},
	"panokseon": {"n": "판옥선 수군", "kin": "sugun", "dmg": 28.0, "int": 1.6, "rng": 5.2, "spl": 1.4, "slow": 0.0, "sp": "",
		"d": "조선 수군의 2층 전선. 화포로 범위 공격.",
		"sk": {"n": "총통 일제사격", "k": "nuke", "r": 2.5, "m": 5.0, "d": "화포 일제사격으로 넓은 범위에 큰 피해."}},
	"geobukseon": {"n": "거북선", "kin": "sugun", "dmg": 34.0, "int": 1.4, "rng": 3.6, "spl": 1.0, "slow": 0.0, "sp": "",
		"d": "덮개를 씌운 돌격선. 가까운 요괴를 들이받는다.",
		"sk": {"n": "돌격", "k": "nova", "m": 5.0, "d": "주변 요괴 전부에게 큰 피해."}},
	"yongwang": {"n": "용왕", "kin": "sugun", "dmg": 9.0, "int": 1.0, "rng": 4.4, "spl": 1.6, "slow": 0.45, "sp": "",
		"d": "비와 바다를 다스리는 신. 물보라로 범위 둔화.",
		"sk": {"n": "호우", "k": "slow", "t": 6.0, "d": "큰비를 내려 모든 요괴 6초 둔화."}},
	# ---- recipe heroes (always 전설) ----
	"dokkaebi_king": {"n": "도깨비 대왕", "kin": "dokkaebi", "dmg": 14.0, "int": 0.5, "rng": 4.2, "spl": 1.0, "slow": 0.0, "sp": "gold", "hero": true,
		"rec": ["dokkaebi", "dokkaebi", "mudang"], "d": "[영웅] 범위 방망이질 + 뚝딱 확률 25%.",
		"sk": {"n": "도깨비 잔치", "k": "buff", "t": 6.0, "m": 1.6, "d": "주변 유닛 공격 속도 ×1.6 (6초)."}},
	"gwigyo": {"n": "귀교의 비형", "kin": "dokkaebi", "dmg": 14.0, "int": 0.5, "rng": 4.4, "spl": 0.0, "slow": 0.0, "sp": "multi", "hero": true,
		"rec": ["bihyeong", "dokkaebibul", "hwarang"], "d": "[영웅] 귀신 무리를 부리는 비형랑. 둘을 동시에.",
		"sk": {"n": "귀신 다리", "k": "push", "dist": 7.0, "d": "모든 요괴를 길 뒤쪽으로 멀리 되돌린다."}},
	"chakho": {"n": "착호갑사", "kin": "muin", "dmg": 45.0, "int": 1.6, "rng": 6.5, "spl": 0.0, "slow": 0.0, "sp": "boss", "hero": true,
		"rec": ["gungsa", "posu", "haetae"], "d": "[영웅] 조선의 범 사냥 부대. 보스 사냥 전문.",
		"sk": {"n": "범 사냥", "k": "boss", "m": 20.0, "d": "체력이 가장 많은 요괴에게 일격 (공격력 ×20)."}},
	"agijangsu": {"n": "아기장수", "kin": "muin", "dmg": 30.0, "int": 0.6, "rng": 4.0, "spl": 0.0, "slow": 0.0, "sp": "", "hero": true,
		"rec": ["hwarang", "seungbyeong", "mago"], "d": "[영웅] 겨드랑이에 날개 달린 지리산 장수.",
		"sk": {"n": "콩·팥 군사", "k": "buff_all", "t": 6.0, "m": 1.5, "d": "콩·팥 군사가 일어나 모든 유닛 공격 속도 ×1.5 (6초)."}},
	"cheonnyeon": {"n": "천년 구미호", "kin": "sinsu", "dmg": 16.0, "int": 0.6, "rng": 4.2, "spl": 1.2, "slow": 0.0, "sp": "multi", "hero": true, "fire": true,
		"rec": ["gumiho", "gumiho", "mudang"], "d": "[영웅] 여우불 범위 공격을 두 곳에 동시에.",
		"sk": {"n": "여우 구슬", "k": "nuke", "r": 3.2, "m": 7.0, "d": "여우 구슬이 터지며 넓은 범위에 큰 피해."}},
	"yeomra": {"n": "염라대왕", "kin": "jusul", "dmg": 10.0, "int": 0.8, "rng": 4.5, "spl": 0.0, "slow": 0.3, "sp": "exec30", "hero": true,
		"rec": ["jeoseung", "mulgwisin", "mudang"], "d": "[영웅] 체력 30% 이하 요괴를 즉시 심판. 느리게도 만든다.",
		"sk": {"n": "시왕 심판", "k": "exec", "thr": 0.6, "d": "사거리 안 체력 60% 이하 요괴를 모두 심판."}},
	"bari": {"n": "바리공주", "kin": "jusul", "dmg": 12.0, "int": 0.7, "rng": 4.6, "spl": 1.2, "slow": 0.0, "sp": "", "hero": true,
		"rec": ["mudang", "jeoseung", "samjogo"], "d": "[영웅] 저승 약수로 부모를 살린 무조신.",
		"sk": {"n": "생명수", "k": "mp_all", "amt": 45.0, "d": "모든 유닛 MP +45."}},
	"cheoyongrang": {"n": "처용랑", "kin": "jusul", "dmg": 16.0, "int": 0.7, "rng": 4.6, "spl": 1.4, "slow": 0.0, "sp": "exorcist", "hero": true,
		"rec": ["cheoyong", "yongwang", "pansu"], "d": "[영웅] 처용가로 역신을 물리친다. 영체·역병에 ×2.",
		"sk": {"n": "처용가", "k": "stun", "t": 3.2, "d": "모든 요괴를 3.2초 멈춘다."}},
	"hwalbin": {"n": "활빈당 두령", "kin": "sinseon", "dmg": 22.0, "int": 0.45, "rng": 4.2, "spl": 0.0, "slow": 0.0, "sp": "crit", "hero": true,
		"rec": ["honggildong", "jeonuchi", "dokkaebi"], "d": "[영웅] 탐관오리의 재물을 털어 나누는 의적 두령.",
		"sk": {"n": "활빈", "k": "gold", "g": 30, "d": "골드 +30."}},
	"tongjesa": {"n": "수군 통제사", "kin": "sugun", "dmg": 40.0, "int": 1.2, "rng": 6.0, "spl": 1.2, "slow": 0.0, "sp": "", "hero": true,
		"rec": ["geobukseon", "panokseon", "posu"], "d": "[영웅] 학익진으로 적을 에워싸는 수군 장수 (원형 인물).",
		"sk": {"n": "학익진 일제사격", "k": "chain", "n_t": 10, "m": 4.0, "d": "가장 앞선 요괴 10마리에게 일제사격."}},
	"hogukryong": {"n": "호국룡", "kin": "sugun", "dmg": 20.0, "int": 0.8, "rng": 5.0, "spl": 1.6, "slow": 0.3, "sp": "", "hero": true,
		"rec": ["yongwang", "panokseon", "hyeonmu"], "d": "[영웅] 죽어서도 동해를 지키는 용 (원형 인물).",
		"sk": {"n": "만파식적", "k": "stun", "t": 2.8, "d": "피리 소리로 모든 요괴를 2.8초 잠재운다."}},
}
const BASE_KEYS := ["dokkaebi", "dokkaebibul", "ssireum", "bihyeong", "haetae", "gumiho", "samjogo", "hyeonmu",
	"gungsa", "posu", "hwarang", "seungbyeong", "mudang", "jeoseung", "cheoyong", "pansu",
	"jeonuchi", "honggildong", "baksi", "mago", "mulgwisin", "panokseon", "geobukseon", "yongwang"]
const HERO_KEYS := ["dokkaebi_king", "gwigyo", "chakho", "agijangsu", "cheonnyeon", "yeomra", "bari", "cheoyongrang", "hwalbin", "tongjesa", "hogukryong"]
const START_POOL := ["dokkaebi", "gungsa", "mudang", "mulgwisin", "haetae"]

const RELICS := {
	"bangmang": ["도깨비 방망이", "소환 비용 30 → 24"],
	"bok": ["복주머니", "합성할 때 15% 확률로 두 단계 상승"],
	"haetae_stone": ["해태 석상", "보스에게 주는 피해 +30%"],
	"bujeok": ["부적", "이웃 시너지 +12% → +20%"],
	"jangseung": ["장승", "요괴 이동 속도 -12%"],
	"yeopjeon": ["엽전 꾸러미", "웨이브 보상 +12골드"],
	"yeouiju": ["여의주", "전설 등급(영웅 포함) 공격력 +25%"],
	"manpa": ["만파식적", "웨이브 시작 8초 뒤 모든 요괴 2초 정지"],
	"cheonbuin": ["천부인", "모든 유닛 공격력 +10%"],
	"bigyeok": ["비격진천뢰", "범위 공격 반경 +0.4"],
	"angbu": ["앙부일구", "MP 자연 충전 2배"],
	"jeokpae": ["적패지", "보스가 체력 15% 깎인 채 등장"],
	"hwansaeng": ["환생꽃", "판매 환급 50% → 100%"],
	"cheonmado": ["천마도 장니", "모든 유닛 공격 속도 +10%"],
	"chiljido": ["칠지도", "다중 공격 유닛의 대상 +1"],
	"cheoyong_face": ["처용 화상", "영체 요괴가 받는 피해 반감 무효"],
}

# traits (effects in toy2.gd); boss patterns (bp): summon (minion key), enrage, regen, split (into key x n)
const TRAIT_NAMES := {"fast": "빠름", "armor": "장갑", "spirit": "영체", "split": "분열", "regen": "재생", "stealth": "은신",
	"slowimm": "둔화 면역", "shield": "수호", "ironeater": "쇠 먹음", "thief": "도둑", "plague": "역병", "flee": "도주", "swarm": "떼"}
const TRAIT_TIPS := {"fast": "빠르게 달린다", "armor": "약한 공격을 크게 깎는다 → 한 방이 센 유닛, 승병·판수",
	"spirit": "무인·도깨비 공격 절반 → 주술·신수·승병", "split": "죽으면 작은 요괴 둘로 갈라진다", "regen": "체력을 계속 회복한다 → 판수",
	"stealth": "가끔 모습을 감춰 공격받지 않는다 → 판수", "slowimm": "느려지지 않는다", "shield": "주변 요괴가 받는 피해를 줄인다 → 판수",
	"ironeater": "무인·수군(쇠붙이) 공격을 먹어 버린다. 불 속성에 약함", "thief": "한 바퀴 돌 때마다 골드를 훔친다",
	"plague": "가까운 유닛의 공격을 느리게 한다 → 처용", "flee": "체력이 절반 아래면 빨라진다", "swarm": "둘씩 몰려나온다"}
# enemy: n, hp (multiplier), spd (multiplier), tr (traits), look (art key), src (출전), d
const ENEMIES := {
	# 1막 마을 (설날 밤)
	"jabgwi": {"n": "잡귀", "hp": 1.0, "spd": 1.0, "tr": [], "look": "jabgwi", "src": "민간신앙", "d": "불행하게 죽은 넋 같은 하급 귀신들."},
	"gaekgwi": {"n": "객귀", "hp": 0.7, "spd": 1.55, "tr": ["fast"], "look": "gaekgwi", "src": "민간신앙", "d": "객지에서 죽어 떠도는 귀신."},
	"dungapjwi": {"n": "둔갑쥐", "hp": 0.8, "spd": 1.05, "tr": ["split"], "look": "rat", "src": "쥐둔갑 설화", "d": "버린 손톱을 먹고 사람으로 둔갑한 쥐."},
	"yagwang": {"n": "야광귀", "hp": 0.9, "spd": 1.15, "tr": ["thief", "stealth"], "look": "yagwang", "src": "세시풍속 '야광이 쫓기'", "d": "설날 밤 신발을 훔쳐 가는 귀신."},
	"yeou": {"n": "여우", "hp": 0.6, "spd": 1.5, "tr": ["fast"], "look": "fox", "src": "변신 설화", "d": "여우누이가 부르는 여우 떼."},
	# 2막 깊은 산
	"changgwi": {"n": "창귀", "hp": 1.0, "spd": 1.1, "tr": ["spirit"], "look": "changgwi", "src": "호식장 민속", "d": "범에게 죽어 범을 돕는 넋."},
	"dueoksini": {"n": "두억시니", "hp": 1.8, "spd": 0.8, "tr": ["armor"], "look": "brute", "src": "표준국어대사전", "d": "모질고 사나운 귀신."},
	"eodukseoni": {"n": "어둑서니", "hp": 1.2, "spd": 0.95, "tr": ["stealth"], "look": "shadow", "src": "표준국어대사전", "d": "어두운 밤에 있는 것처럼 잘못 보이는 것."},
	"horangi": {"n": "산중 호랑이", "hp": 1.4, "spd": 1.4, "tr": ["fast"], "look": "tiger", "src": "『삼국유사』 김현감호", "d": "고갯길의 사나운 범."},
	# 3막 강·못
	"gureongi": {"n": "구렁이", "hp": 2.2, "spd": 0.75, "tr": ["slowimm"], "look": "snake", "src": "구렁이 설화", "d": "깊은 못의 큰 뱀."},
	"isimi": {"n": "이시미", "hp": 1.3, "spd": 1.0, "tr": ["stealth", "regen"], "look": "isimi", "src": "「산삼과 이시미」", "d": "물속을 오가는 작은 이무기."},
	"bindae": {"n": "빈대 떼", "hp": 0.35, "spd": 1.2, "tr": ["swarm"], "look": "swarm", "src": "빈대절터 설화", "d": "절을 망하게 했다는 빈대 무리."},
	"dokgakgwi": {"n": "독각귀", "hp": 1.2, "spd": 1.2, "tr": ["spirit"], "look": "onelegged", "src": "도깨비의 이명", "d": "외다리로 껑충 뛰는 심술 도깨비."},
	# 4막 지하국
	"yogwi": {"n": "요귀", "hp": 1.5, "spd": 0.95, "tr": ["armor", "regen"], "look": "yogwi", "src": "『금방울전』", "d": "금방울을 삼킨 굴 속 요괴."},
	"daegwi": {"n": "대귀", "hp": 2.2, "spd": 0.8, "tr": ["shield"], "look": "daegwi", "src": "『삼국유사』 밀본최사", "d": "작은 귀신들을 부리는 큰 귀신."},
	"sogwi": {"n": "소귀", "hp": 0.6, "spd": 1.45, "tr": ["fast"], "look": "sogwi", "src": "『삼국유사』 밀본최사", "d": "철퇴를 든 작은 귀신."},
	"agwi": {"n": "아귀", "hp": 1.2, "spd": 1.0, "tr": ["thief", "regen"], "look": "agwi", "src": "불교 육도", "d": "끝없이 굶주린 존재."},
	# 5막 옛 도읍 궁궐
	"gildal": {"n": "길달", "hp": 1.3, "spd": 1.0, "tr": ["flee"], "look": "gildal", "src": "『삼국유사』 도화녀 비형랑", "d": "관복 입은 귀신. 쫓기면 여우로 변해 달아난다."},
	"jigwi": {"n": "지귀", "hp": 1.2, "spd": 1.05, "tr": ["spirit"], "look": "jigwi", "src": "『수이전』 심화요탑", "d": "마음의 불로 불귀신이 된 사내."},
	"yeoksin": {"n": "역신", "hp": 1.4, "spd": 0.95, "tr": ["plague"], "look": "yeoksin", "src": "『삼국유사』 처용랑 망해사", "d": "열병을 옮기는 신. 처용 앞에서 물러난다."},
	"yeongno": {"n": "영노", "hp": 2.0, "spd": 0.9, "tr": ["armor", "regen"], "look": "yeongno", "src": "오광대·야류", "d": "양반 아흔아홉을 먹었다는 괴물."},
	# 보스 (hp: 그 웨이브 일반 요괴 대비 배수)
	"yeounui": {"n": "여우누이", "hp": 24.0, "spd": 0.7, "tr": ["flee"], "look": "foxsister", "boss": true, "bp": "summon", "minion": "yeou", "src": "여우누이 설화", "d": "여동생으로 태어난 여우."},
	"jine": {"n": "천년 지네", "hp": 20.0, "spd": 0.7, "tr": ["slowimm"], "look": "centipede", "boss": true, "bp": "split", "minion": "jine_madi", "src": "두꺼비의 보은 (지네장터)", "d": "처녀 제물을 받던 큰 지네."},
	"jine_madi": {"n": "지네 마디", "hp": 3.0, "spd": 0.9, "tr": ["slowimm"], "look": "segment", "src": "두꺼비의 보은", "d": "갈라진 지네의 마디."},
	"imugi": {"n": "이무기", "hp": 26.0, "spd": 0.65, "tr": ["regen"], "look": "imugi", "boss": true, "bp": "regen", "src": "용 항목, 「구복여행」", "d": "용이 되지 못한 큰 뱀."},
	"daejeok": {"n": "지하국 대적", "hp": 26.0, "spd": 0.65, "tr": ["armor"], "look": "daejeok", "boss": true, "bp": "summon", "minion": "sogwi", "src": "지하국대적퇴치설화", "d": "사람을 훔쳐 가는 지하국의 괴물."},
	"bulgasari": {"n": "불가사리", "hp": 24.0, "spd": 0.65, "tr": ["ironeater"], "look": "bulgasari", "boss": true, "bp": "enrage", "src": "불가사리 설화 (송도 말년)", "d": "쇠를 먹고 자라 불로만 죽는다는 괴수."},
}
const ACTS := [
	{"n": "1막 · 설날 밤 마을", "roster": ["jabgwi", "gaekgwi", "dungapjwi", "yagwang"], "boss": "yeounui"},
	{"n": "2막 · 깊은 산 고갯길", "roster": ["changgwi", "dueoksini", "eodukseoni", "horangi"], "boss": "jine"},
	{"n": "3막 · 강과 깊은 못", "roster": ["gureongi", "bindae", "isimi", "dokgakgwi"], "boss": "imugi"},
	{"n": "4막 · 지하국", "roster": ["sogwi", "yogwi", "daegwi", "agwi"], "boss": "daejeok"},
	{"n": "5막 · 옛 도읍 궁궐", "roster": ["gildal", "jigwi", "yeoksin", "yeongno"], "boss": "bulgasari"},
]
