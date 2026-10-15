# Steam 시장 재분석 v2 — "차별화 + 잘 팔림" 기준 (2026-10-15)

방법: Steam 검색 API로 태그별 코호트(2024-10-15 ~ 2026-04-15 출시, 출시 후 6~24개월) 전수 수집.
"히트" = 리뷰 1,000+ (대략 판매 3만 장 안팎, x30 추정). 추정 매출 = 리뷰 x 30 x 가격 x 0.7 (오차 큼, 상대 비교용).
한계: 위시리스트/실판매 비공개. Pixel/Puzzle/Strategy 단독 태그는 검색 상한으로 코호트 절단 → 조합 태그로 재수집.
히트율은 소표본(예: 6/84)이 많아 +-수 %p 오차 가능.

## 전체 태그 히트율 (리뷰 1k+ / 코호트, 상위)
Extraction Shooter 38%(멀티·대형사), Open World Survival Craft 26%, Colony Sim 11.9%, Base Building 11.7%,
Sandbox 10.1%, Souls-like 9.7%, City Builder 8.9%, Bullet Heaven 8.7%, Management 7.7%, Cozy 7.4%,
Automation 6.5%, Roguelite 4.5%, Tower Defense 3.1%, Bullet Hell 1.8%, Platformer 1.8%, Puzzle 1.9%.

## 픽셀 아트 한정 (장르 + Pixel Graphics)
| 조합 | 코호트 | 히트 | 히트율 | 히트작 중앙가격 |
|---|---|---|---|---|
| Management | 453 | 33 | 7.3% | $5.99 |
| Resource Mgmt | 444 | 32 | 7.2% | $6.99 |
| Bullet Heaven | 84 | 6 | 7.1% | $9.99 |
| Base Building | 195 | 13 | 6.7% | $9.99 |
| Incremental | 483 | 31 | 6.4% | $3.49 |
| Idler | 486 | 28 | 5.8% | $3.69 |
| Creature Collector | 196 | 10 | 5.1% | $10.02 |
| Roguelite | 981 | 36 | 3.7% | $9.99 |
| Tower Defense | 222 | 8 | 3.6% | $9.99 |
| Action Roguelike | 760 | 16 | 2.1% | $9.54 |
전체 픽셀 타이틀(스캔 4,020개) 중 히트 136개 = 3.4%. 중앙값 타이틀 매출은 사실상 0.

## 관찰
1. 장르 간 차이는 작다. 어떤 픽셀 장르도 히트율 10%를 넘지 못함. 실행력과 훅이 장르보다 큼.
2. 타워디펜스는 평균 이하(3.6%). 로그라이트 픽셀은 공급 981개 대비 히트율 3.7%로 포화.
3. 공급 대비 수요가 좋은 곳: Base Building+Pixel(공급 195, 히트 6.7%, $10).
4. 저가(~$3-7) 방치/증분 + 로그라이트/덱빌딩/도박 메커닉 혼합작이 다수 히트
   (Scritchy Scratchy 8.9k 리뷰, Shelldiver 4.9k, Slots & Daggers, Unfair Flips, Dice A Million 등). 자가 출판 비중 높음, 개발 기간 짧음.
5. 대형 이상치(Megabonk 5.8만 리뷰, BALL x PIT 1.6만)가 Bullet Heaven 평균을 끌어올림.
6. Creature Collector는 히트율 양호하나 아트 물량이 커서 "직접 제작" 제약과 충돌.
