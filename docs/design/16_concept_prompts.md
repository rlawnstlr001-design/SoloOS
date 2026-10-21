# 16. 컨셉 시트 프롬프트 목록 — 전체 유닛·요괴 (2026-10-21)

15 문서의 파이프라인(컨셉 → 3D → `assets/models`)을 나머지 로스터 전체로 넓힌다. 이 문서는 **Gemini 나노바나나에 그대로 붙여 넣는 프롬프트 모음**이다.
결과물은 `docs/design/concepts/<키>_turnaround.png`로 저장한다 (키 = `toy2_data.gd`의 유닛 키 / 요괴 `look`).

## 만드는 순서
1. 영웅 12 (바리공주 완료) → 2. 보스 7 (불가사리 완료) → 3. 기본 유닛 24 → 4. 해금 유닛 12 → 5. 일반 요괴 26
- 한 캐릭터당 **새 채팅 하나**. 같은 채팅에서 고쳐 달라고 하면 앞 그림을 되풀이한다(15 문서 10절).
- 결과가 사양과 다르면(뿔 달린 도깨비, 두 발로 선 네 발 짐승 등) 새 채팅에서 그 부분을 앞에 강조해 다시 뽑는다.

## 진행 상황
- **2026-10-21: 전체 로스터 완료 — 83장** (영웅 13 + 보스 8 + 기본 유닛 24 + 해금 유닛 12 + 일반 요괴 26, `concepts/<키 또는 look>_turnaround.png`, 2752×1536 PNG, 장당 약 5MB).
- 요괴 메모: 프롬프트 앞에 `답변 글 없이 이미지만.`을 넣었더니 그림 위 설명 줄(다운로드 버튼 위치를 바꾸던 원인)이 사라졌다.
- **2차 점검 후 다시 뽑음(9장)**: 삼족오(다리 2개 → `exactly THREE legs ... in EVERY view`), 염라대왕(정면 모자만 달랐음 → `the hat is IDENTICAL in all four views`), 독각귀(두 다리 → 세 번째 시도에 외다리, 대신 버섯 갓을 씀), 빈대 떼(한 마리 → 세 마리 무리, 그림이 작음), 구렁이(2줄 5면 → 한 줄 4면), 홍길동(세로 그림·인물 작음 → `wide 16:9 ... LARGE figures`), 의녀(갓 → 가리마), 판수·야광귀(아래 각도 글씨 → `absolutely NO text`). 지네 마디는 옆모습 머리 두 개를 `exactly ONE head, at the FRONT end only`로 고침. 바뀌기 전 파일은 커밋 9280603에 남아 있다.
- 해금 유닛 메모: 의녀는 가리마 대신 검은 갓을 썼다(고증 어긋남, 3D 단계에서 모자만 고치거나 다시 뽑기). 청룡은 호국룡처럼 꼬리로 선 동양 용. 신기전 화차는 처음부터 태극기 금지 문장을 넣어 한 번에 맞음.
- 기본 유닛 메모: 판옥선·거북선은 처음에 **근대 태극기**가 돛·깃발에 들어가서(시대 안 맞음) `IMPORTANT: 16th-century Joseon, NO modern South Korean national flag ...`를 앞에 붙여 다시 뽑았다. 홍길동은 세로로 긴 그림으로 나와 인물이 작다(3D 입력에 부족하면 다시 뽑기). 판수 시트엔 아래에 'Front View' 같은 작은 글씨가 들어갔다(잘라 쓰면 됨). 방망이·씨름 도깨비는 귀가 뾰족하지만 뿔은 없다.
- 다시 뽑은 것: 강철이·금돼지·독룡 — 처음엔 두 발로 서거나 서양 용으로 나와서, 프롬프트 **맨 앞에** `IMPORTANT: ... walking on ALL FOUR legs ..., NOT standing upright` / `long serpentine EAST ASIAN dragon ..., NO wings, NOT a western dragon`을 넣어 해결. 아래 표의 보스 설명은 처음 버전이니, 네 발 짐승·용은 이 문장을 앞에 붙여 쓴다.
- 그대로 쓴 것: 호국룡은 네 발 대신 꼬리로 선 동양 용으로 나왔지만 영웅 유닛 자리에는 오히려 잘 맞아 채택. 여우누이는 보스치고 작지만 '누이로 둔갑한 여우'라 맞음.
- 받는 법: Gemini 이미지의 '원본 크기 다운로드' 버튼 → `Downloads/Gemini_Generated_Image_*.png` → 이름 바꿔 옮김. **다운로드가 끝나기 전(약 15초)에 다른 채팅으로 넘어가면 취소된다.**

## 공통 틀
아래 `{설명}`과 `{비율}`만 바꿔 넣는다.

```
이미지 생성해줘 (나노 바나나). 게임용 3D 모델의 기준이 될 캐릭터 컨셉 시트. Character turnaround sheet of the same character in 4 views side by side (front, front three-quarter, side, back), full body, plain white background, no text. Character: {설명} for a stylized low-poly tower defense game based on Korean folklore. {비율} Flat solid colors, simple shapes, clean readable silhouette, soft cel shading, toy-like, consistent design across all views.
```

| 비율 코드 | `{비율}`에 넣는 문장 |
|---|---|
| **H** (사람형) | Chibi proportions about 2.5 heads tall, big head. |
| **B** (짐승·신수) | Cute chunky stylized creature proportions, big head, standing on all four legs. |
| **F** (새·날짐승) | Cute chunky stylized creature proportions, big head, wings half open, standing pose. |
| **O** (배·기계) | Small cute toy-like model proportions, chunky and simplified. |
| **Y** (요괴) | Chibi proportions, spooky but cute, murky muted colors with small glowing eyes. |
| **YB** (네 발 요괴) | Chibi proportions, spooky but cute, murky muted colors with small glowing eyes, standing on all four legs. |
| **BOSS** | Large imposing boss monster, chunky stylized proportions, menacing but readable, murky colors with glowing eyes. |

공통 금지 (설명에 이미 반영): 일본 오니풍(뿔 + 호랑이 가죽 옷), 실존 인물 얼굴, 지금도 모시는 신격(삼신·용왕·염라·자청비·마고·처용)의 희화화 — 이들은 **위엄 있게, 귀엽게**.
도깨비는 모두 `Korean dokkaebi (NOT a Japanese oni: no horns, no tiger-skin clothes)`를 앞에 붙였다.

## 1. 영웅 (12)
| 키 | 이름 | 비율 | 설명 `{설명}` |
|---|---|---|---|
| dokkaebi_king | 도깨비 대왕 | H | Korean dokkaebi king (NOT a Japanese oni: no horns, no tiger-skin clothes), big shaggy dark hair and beard, broad grin, small gold crown over a black gat-like cap, deep red royal robe with gold dragon roundel, holding a huge knobbed wooden magic club (bangmangi) that glows with gold sparks, stout and jolly but powerful |
| gwigyo | 귀교의 비형 | H | Bihyeong, a half-ghost Silla youth noble (hwarang) who commands ghosts, long black hair tied up, pale face with calm smirk, layered dark blue and white Silla robe, holding a ghostly blue paper lantern, two small floating wisp ghosts around him, a small arched wooden bridge charm at his belt |
| chakho | 착호갑사 | H | Joseon royal tiger hunter elite soldier, black wide-brim beonggeoji felt hat with red tassel, dark green military coat (dongdari) with black vest, a tiger-hunting spear with a red ribbon in one hand and a matchlock musket on the back, determined face, tiger-claw charm on chest |
| agijangsu | 아기장수 | H | Agijangsu, a legendary baby general from Jirisan with small white feathered wings growing from his armpits, toddler-like round face with brave eyes, topknot with a red band, light white-and-blue armor vest over a hanbok, holding a small sword, standing proudly on a little rock |
| cheonnyeon | 천년 구미호 | B | thousand-year-old nine-tailed fox spirit, elegant white fox with nine large fluffy tails tipped with blue foxfire, a glowing blue fox bead floating in front of the mouth, gold markings on the forehead, mystic and dignified (not seductive) |
| yeomra | 염라대왕 | H | Yeomra, king of the underworld judges, dignified not scary, black official hat with flat square top plate (myeonryugwan with bead strings), crimson judge robe with gold trim, holding a black wooden judgment tablet and a brush, stern fair face with thick beard, small scroll ledger at the belt |
| cheoyongrang | 처용랑 | H | Cheoyongrang, son of the East Sea dragon king who drives away the plague god by song and dance, wearing the red Cheoyong dance mask style face (calm wide face, peony flowers and peaches on a black hat), flowing red Cheoyong dance robe with long white sleeves, dancing pose with one sleeve raised |
| hwalbin | 활빈당 두령 | H | leader of the Hwalbindang righteous outlaws, black straw gat hat slightly tilted, black mask over the eyes, dark navy outlaw jeogori with a red sash, a sack of gold coins over the shoulder and a short sword, cheerful confident grin |
| tongjesa | 수군 통제사 | H | Joseon naval commander (a generic admiral, not a real person's face), black helmet with red plume and neck guard, dark blue lamellar armor with gold studs, red cape, holding a commander's baton (with a small crane-wing battle formation flag on the back), calm determined face |
| hogukryong | 호국룡 | B | guardian sea dragon of the East Sea that protects the kingdom, Korean style dragon (long body, deer antlers, catfish whiskers, a glowing pearl held in one claw), teal and gold scales, sea-wave fins, coiled pose standing on four short legs with a raised head, noble and kind expression |
| sasin | 사신 수호진 | H | a Taoist guardian sage in white-and-gold robes holding a round bronze mirror with the four directions, with three small spirit animals floating around him: an azure dragon, a white tiger and a vermilion bird, colored cloud base under his feet |
| seungjang | 도총섭 승장 | H | warrior monk general leading righteous armies (generic, not a real person), shaved head, gray monk robe with a red kasaya sash over light lamellar armor, long prayer beads around the neck, holding a long staff with metal rings (khakkhara), steady compassionate face |

## 2. 보스 (7)
| 키 (look) | 이름 | 비율 | 설명 |
|---|---|---|---|
| foxsister | 여우누이 | BOSS | Yeou-nui, a fox demon disguised as a little sister, a girl in a white jeogori and red skirt with long braided hair, but with a big fox tail, fox ears and fox eyes showing, holding a small knife and a cow's liver (abstract dark red shape, no gore), eerie cute grin |
| centipede | 천년 지네 | BOSS | thousand-year-old giant centipede monster, long segmented armored body raised in an S-curve, dark red and black shell plates with gold edges, many orange legs, big pincers, glowing yellow eyes, front view shows the head raised high |
| imugi | 이무기 | BOSS | Imugi, a giant serpent that failed to become a dragon, huge thick snake body coiled, small bumps where horns never grew, murky green-gray scales with a pale belly, a cloudy unfinished pearl in its jaw, glowing yellow eyes |
| daejeok | 지하국 대적 | BOSS | the great bandit monster of the underground kingdom, hulking nine-headed troll-like ogre (one big head with smaller heads on the shoulders), dark purple skin, ragged stolen royal robe, iron club, gold loot chains, glowing eyes, NOT a Japanese oni (no horns, no tiger skin) |
| gangcheol | 강철이 | BOSS | Gangcheori, an evil drought dragon whose passing withers plants, Korean style dragon with cracked dry earth-colored scales, heat haze, withered leaves falling around it, smoldering orange eyes, standing on four legs, long body |
| dokryong | 독룡 | BOSS | a vengeful poison dragon that turned into a willow tree, a dragon whose body is half gnarled willow trunk with hanging willow branches as a mane, sickly purple-green poison drips, glowing green eyes, standing on four root-like legs |
| goldpig | 금돼지 | BOSS | the golden pig monster that kidnaps people into its cave, huge golden boar with gold coin-shaped markings, tusks, small golden crown of stolen jewelry, glowing red eyes, standing on all four legs, heavy and greedy |

## 3. 기본 유닛 (24, 영웅 재료·소환 풀)
| 키 | 이름 | 비율 | 설명 |
|---|---|---|---|
| dokkaebi | 방망이 도깨비 | H | Korean dokkaebi goblin (NOT a Japanese oni: no horns, no tiger-skin clothes), shaggy hair, round face with a big toothy grin, patched brown hanbok vest and loose trousers, holding a knobbed wooden magic club (bangmangi) |
| dokkaebibul | 도깨비불 | F | Dokkaebi-bul, a floating blue will-o'-the-wisp spirit flame with a small cute face, two tiny flame arms, a trail of small blue flames, hovering above the ground |
| ssireum | 씨름 도깨비 | H | Korean dokkaebi wrestler (NOT a Japanese oni: no horns, no tiger-skin clothes), stocky muscular build, red ssireum satba belt around waist and thigh, white wrestling shorts, shaggy hair tied back, ready-to-grapple stance |
| bihyeong | 비형랑 | H | Bihyeongnang, a half-ghost Silla youth, young man in a simple light gray and blue Silla robe, long hair half tied, pale calm face, one small blue wisp ghost following him |
| haetae | 해태 | B | Haetae, a lion-like Korean guardian beast that judges right and wrong, stone-gray and blue curly mane, a single small horn bump on the head, friendly big eyes, bell on a red collar, sitting-ready stance on four legs |
| gumiho | 구미호 | B | young nine-tailed fox, orange-red fox with nine fluffy tails, a small orange foxfire floating above the tails, sly but cute face |
| samjogo | 삼족오 | F | Samjok-o, the three-legged sun crow from Goguryeo tomb murals, black crow with a golden sun disc behind it, three red legs, red crest feathers, proud pose |
| hyeonmu | 현무 | B | Hyeonmu, the black tortoise of the north entwined with a snake, dark teal tortoise with a hexagon-patterned shell, a black snake wrapped around the shell with its head beside the tortoise head |
| gungsa | 궁사 | H | Joseon archer, black gat hat with a feather, blue military coat with red sleeves, quiver on the back, holding a Korean composite bow (gakgung) |
| posu | 포수 | H | Joseon mountain tiger hunter (posu), fur-lined cap, brown padded jacket, straw sandals, a long matchlock musket held at the ready, powder horn at the belt, weathered friendly face |
| hwarang | 화랑 | H | Silla hwarang youth swordsman, hair tied in a topknot with a ribbon, white and sky-blue layered robe, holding a ring-pommel sword (hwandudaedo), elegant stance |
| seungbyeong | 승병 | H | Korean warrior monk soldier, shaved head, gray monk robe with tied sleeves, wooden prayer beads, holding a long monk staff, calm face |
| mudang | 무당 | H | Korean shaman (mudang) performing a gut ritual, red and blue layered ritual robe (kwaeja) with long sleeves, black and red hat with a feather, holding a fan in one hand and a bunch of brass shaman bells in the other |
| jeoseung | 저승사자 | H | Korean grim reaper (jeoseung saja), tall black gat hat, black robe with long sleeves, very pale face with dark lips, holding a scroll of names, mysterious but cute, not gory |
| cheoyong | 처용 | H | Cheoyong, son of the East Sea dragon, wearing a simple Cheoyong mask face (wide calm face, ruddy skin) and a black hat decorated with peony flowers, blue dance robe with long sleeves, gentle dancing pose |
| pansu | 판수 | H | blind sutra-reciting exorcist (pansu), dark glasses, white robe with a black gat hat, holding a small drum and a scroll of sutras, kind serene face |
| jeonuchi | 전우치 | H | Jeon Woo-chi, a playful Taoist magician, sky blue Taoist robe, black gat hat, holding a folding fan and a magic paper talisman, a small cloud under his feet, mischievous smile |
| honggildong | 홍길동 | H | Hong Gil-dong, the righteous outlaw hero, black gat hat, dark navy robe with a red belt, a straight sword on the back, confident pose, one hand making a magic seal gesture |
| baksi | 박씨부인 | H | Lady Park, a Joseon noblewoman Taoist heroine, simple pale green hanbok with a dark purple skirt, hair in a neat bun with a binyeo pin, holding a magic fan, calm wise face |
| mago | 마고할미 | H | Mago Halmi, the giant grandmother goddess who shaped mountains and rivers, dignified kind elder woman, white hair in a bun, earthy brown and white robe, holding a big round boulder, a tiny mountain-shaped hairpin |
| mulgwisin | 물귀신 | Y | Korean water ghost, a drowned spirit with long wet black hair covering half the face, pale blue skin, dripping white robe, seaweed tangled around, reaching hands, cute-spooky |
| panokseon | 판옥선 수군 | O | Joseon panokseon warship, two-deck wooden battleship with a flat roofed upper deck, red and blue flags, small cannons on the sides, square sails, one tiny sailor waving on deck |
| geobukseon | 거북선 | O | Joseon turtle ship (geobukseon), covered roof with iron spikes, dragon head at the bow with smoke, oars on the sides, red and dark wood colors |
| yongwang | 용왕 | H | Yongwang, the dignified dragon king of the sea, dragon-faced elder with whiskers and small antlers, gold royal crown, deep blue royal robe with wave patterns, holding a glowing pearl scepter, kind and majestic |

## 4. 해금 유닛 (12)
| 키 | 이름 | 비율 | 설명 |
|---|---|---|---|
| yeonggam | 영감 도채비 | H | Jeju yeonggam dokkaebi (NOT a Japanese oni: no horns, no tiger-skin clothes), old dokkaebi with a white beard, wearing a Jeju straw hat and a fisherman's vest, holding a fishing net and a small torch, cheerful |
| cheongryong | 청룡 | B | Cheongryong, the azure dragon of the east, Korean style dragon with blue scales, deer antlers, whiskers, small lightning sparks around, standing on four legs |
| baekho | 백호 | B | Baekho, the white tiger of the west, white tiger with blue-gray stripes, fierce but cute, standing on four legs |
| jujak | 주작 | F | Jujak, the vermilion bird of the south, elegant red and orange phoenix-like bird with flame-tipped tail feathers |
| girin | 기린 | B | Girin (qilin), an auspicious beast with a deer-like body, golden scales, a single soft horn, cloud-shaped mane, hooves, standing on four legs |
| bonghwang | 봉황 | F | Bonghwang, the Korean phoenix, colorful five-color plumage, long flowing tail, gold crest |
| uibyeong | 의병 | H | Joseon righteous army volunteer, white headband, plain white farmer's clothes with a tied jacket, holding a bamboo spear, brave face |
| singijeon | 신기전 화차 | O | Joseon singijeon hwacha rocket launcher cart, wooden two-wheeled cart with a rack of many arrow rockets, small flags |
| gaema | 개마무사 | B | Goguryeo heavy cavalry (gaema musa), armored rider in lamellar armor and plumed helmet on a fully armored horse, holding a long lance, horse standing on four legs |
| uinyeo | 의녀 | H | Joseon female physician (uinyeo), black gareuma hat, pale yellow jeogori with a dark blue skirt, holding acupuncture needles and a medicine pouch, kind face |
| samsin | 삼신할미 | H | Samsin Halmi, the dignified goddess who grants children, gentle grandmother in white hanbok, white hair, holding a bundle of colorful threads and a small bowl, warm smile |
| jacheongbi | 자청비 | H | Jacheongbi, the Jeju goddess of agriculture, young woman in Jeju-style hanbok with a flower crown from the Seocheon flower garden, holding a bundle of five grains and a magic flower |

## 5. 일반 요괴 (26 외형)
| look | 이름 | 비율 | 설명 |
|---|---|---|---|
| jabgwi | 잡귀 | Y | small low-rank Korean ghost (japgwi), tattered gray-white robe, messy hair, round body, floating legs fading into wisps |
| gaekgwi | 객귀 | Y | wandering traveler ghost who died far from home, ragged straw hat, travel bundle on the back, pale greenish skin, tired eyes |
| rat | 둔갑쥐 | YB | shapeshifting rat that ate discarded fingernails, gray rat with a long tail, half transformed with a tiny human topknot and a scrap of hanbok |
| yagwang | 야광귀 | Y | Yagwanggwi, the New Year's night ghost who steals shoes, small dark blue ghost carrying a pair of straw shoes, sieve-patterned eyes, sneaky pose |
| fox | 여우 | YB | wild fox from the fox-sister tale, scrawny reddish-brown fox with glowing eyes, sly expression |
| songaksi | 손각시 | Y | Son-gaksi, ghost of an unmarried maiden, white hanbok, long black loose hair, pale face with red lips, sad eyes |
| mongdal | 몽달귀신 | Y | Mongdal ghost of an unmarried bachelor, pale young man in a white jeogori with a loose topknot, dangling arms, sulky face |
| changgwi | 창귀 | Y | Changgwi, a ghost enslaved by a tiger, pale ghost with tiger-stripe markings on the robe, leading a tiny shadow of a tiger |
| brute | 두억시니 | Y | Dueoksini, a fierce brutish goblin-ghost (NOT a Japanese oni: no horns, no tiger skin), hunched hulking body, gray-purple skin, wild hair, big fists |
| shadow | 어둑서니 | Y | Eodukseoni, a dark shadow illusion that grows when looked at, a black inky silhouette with two glowing white eyes, smoky edges |
| tiger | 산중 호랑이 | YB | fierce mountain tiger from a mountain pass, orange tiger with bold black stripes, snarling but cute |
| snake | 구렁이 | Y | big Korean rat snake (gureongi) from a deep pond, thick dark brown-green snake coiled, yellow eyes |
| isimi | 이시미 | Y | small water imugi serpent (isimi), slick teal snake with small fins, water droplets around |
| swarm | 빈대 떼 | Y | swarm of giant bedbugs that ruined a temple, three round reddish-brown bugs grouped together |
| onelegged | 독각귀 | Y | Dokgakgwi, a one-legged hopping goblin (NOT a Japanese oni: no horns, no tiger skin), single big foot, hopping pose, mischievous grin, shabby clothes |
| haeryong | 해룡 | Y | small sea dragon that kidnapped Lady Suro, dark blue Korean dragon with seaweed whiskers, water wave fins |
| yogwi | 요귀 | Y | cave monster that swallowed a golden bell, round lumpy body with a golden bell glowing in its belly, big mouth |
| daegwi | 대귀 | Y | Daegwi, a big ghost that commands small ghosts, tall ghost in a gray robe with a black gat hat, carrying a ledger, two tiny ghosts at its feet |
| sogwi | 소귀 | Y | Sogwi, a small ghost holding an iron mace (cheoltoe), stubby gray ghost with an oversized iron mace |
| agwi | 아귀 | Y | Agwi, an endlessly hungry ghost, thin limbs with a big round belly, tiny mouth, holding an empty bowl |
| judungi | 주둥이 닷 발 | YB | 'five-fathom snout' monster, a creature with an extremely long snout and an equally long tail, round body, standing on four short legs |
| gildal | 길달 | Y | Gildal, a ghost in a Silla official's robe who turns into a fox when chased, ghost with an official hat and robe, fox ears and tail peeking out |
| jigwi | 지귀 | Y | Jigwi, a man who became a fire ghost from burning love, ghost made of flames in the shape of a young man, sad face |
| yeoksin | 역신 | Y | Yeoksin, the plague spirit, sickly green-gray ghost with spots, ragged robe, carrying a small cloud of fever haze |
| yeongno | 영노 | YB | Yeongno, a mask-dance monster that ate noblemen, big round creature with a huge mouth, colorful mask-like face, fluttering ribbons, standing on four legs |
| segment | 지네 마디 | YB | a single detached segment of the giant centipede, dark red armored segment with orange legs and small glowing eyes |
