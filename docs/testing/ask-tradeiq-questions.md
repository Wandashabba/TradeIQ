# Ask TradeIQ — test questions and expected answers

A script for judging whether Ask TradeIQ gives **insight, not just lookups**, run
against the demo dataset that `npm run seed` builds.

The dataset is 24 months of history for Kalahari Beverages: 13 territories,
50 field agents, 400 outlets, about 140,000 visits, 93,000 orders and 3,300
monthly sales targets. Seven problems are planted in it on purpose. Each is
defined in one place, `backend/scripts/seed/scenario.ts`, and asserted in
`backend/scripts/seed/visits.test.ts`.

## Before you start

**Which dataset the figures come from.** Every figure below was read from the
dev database after seeding on **Thursday 17 September 2026**. The service
functions behind the assistant's tools produced them, with "now" set to that
morning in Africa/Johannesburg.

- **Whole calendar months** (for example "August") and fixed ranges keep these
  figures until you reseed.
- **Relative periods** ("yesterday", "last week", "this month", "year to date")
  are only exact if you ask on 17 September 2026.
- **To rebuild this exact dataset on a later day:**
  `cd backend && SEED_ANCHOR_DATE=2026-09-17 npm run seed`. The seed is
  deterministic, so two runs with the same anchor produce the same rows.

If you reseed without pinning the anchor, the history moves with the calendar.
The stories stay the same (same territory, same agent, same chain), but the
numbers shift a little. The SQL under each anomaly lets you re-derive them.

**Territory ids.** The assistant's tools take a territory *id*, and no tool
turns a name into an id. If the assistant can't scope "Nelson Mandela Bay",
that is a real gap in the tools, not a problem with the data.

| Territory | Id | Code on outlets |
|---|---|---|
| Gauteng (Johannesburg) | `demo-territory-gp` | `GP` |
| Gauteng North (Tshwane) | `demo-territory-gp-tsh` | `GP-TSH` |
| Gauteng East (Ekurhuleni) | `demo-territory-gp-eku` | `GP-EKU` |
| Western Cape (Cape Town) | `demo-territory-wc` | `WC` |
| Western Cape Winelands | `demo-territory-wc-win` | `WC-WIN` |
| KwaZulu-Natal (Durban) | `demo-territory-kzn` | `KZN` |
| KwaZulu-Natal Midlands | `demo-territory-kzn-pmb` | `KZN-PMB` |
| Eastern Cape – Nelson Mandela Bay | `demo-territory-ec-nmb` | `EC-NMB` |
| Eastern Cape – Buffalo City | `demo-territory-ec-bcm` | `EC-BCM` |
| Free State | `demo-territory-fs` | `FS` |
| Limpopo | `demo-territory-lp` | `LP` |
| Mpumalanga | `demo-territory-mp` | `MP` |
| North West | `demo-territory-nw` | `NW` |

**What the assistant can and cannot see today.** The manager roster has ten
tools: `getRateOfSale`, `getSkuMovement`, `getStockLevels`, `getShareOfShelf`,
`getVisibilityCompliance`, `getCompetitorActivity`, `getAgentScorecard`,
`getVisitHistory`, `getFraudFlags` and `getMetricTrend`. Keep these limits in mind
when you judge answers:

1. **No tool reads shelf pricing, campaigns, contests, tasks or alerts.** For
   those questions a correct answer says plainly that the assistant can't see
   that data. It must not invent a figure. The expected figures are still given
   so you can check them in the console.
2. **Business-wide pillar queries stop at 5,000 rows** (`MAX_SCAN`) and report
   `truncated: true`. At this scale, any whole-business stock, visibility,
   competition or visit question over more than about four working days hits
   the cap. A good answer says the figure is from a partial read, or narrows to
   a territory. Territory-scoped questions over one month stay under the cap.
3. **Sales targets are monthly.** Attainment is only reported for whole
   calendar months. For "this month so far" or "year to date" a correct answer
   gives sell-in units and says no target applies.
4. **`getMetricTrend` has no territory filter.** A territory's trend has to be
   pieced together from monthly pillar calls.
5. **`getSkuMovement` ranks by `daysOutOfStock`**, and capture derives that
   from the outlet's previous five counts only. A shelf that has been empty for
   more than five visits reads **0 days**. This hides the chronic out-of-stock
   in anomaly 2, so read that section's notes before judging.

---

## 1. A territory in steady decline — Eastern Cape, Nelson Mandela Bay

**What was planted.** Since mid-March 2026, `EC-NMB` has been losing ground to
a rival cola. It loses about a third of its sell-in, its execution scores drop
about 10 points, and competitor promoters move into most stores. The rival also
cuts its price and takes shelf space.

**Questions**

1. "Which territory is going backwards?"
2. "How has Nelson Mandela Bay been tracking over the last six months, and why?"
3. "Is Nelson Mandela Bay hitting its sales target?"

**A correct answer says**

- EC-NMB sell-in fell from **79,473 units in March 2026** to **53,188 in August**
  (−33%). Attainment of its territory target fell from **103.1% to 67.3%** over
  the same months.

  | Month (2026) | Sell-in units | Target | Attainment | Avg execution score | Share of shelf | Competitor promoter presence |
  |---|---|---|---|---|---|---|
  | Feb | 63,318 | 40,515 | 99.4% | 74.2 | 74.3% | 13.5% |
  | Mar | 79,473 | 49,356 | 103.1% | 74.9 | 73.9% | 14.8% |
  | Apr | 71,816 | 46,592 | 96.8% | 73.0 | 69.9% | 21.8% |
  | May | 56,261 | 44,672 | 80.8% | 70.8 | 66.0% | 32.9% |
  | Jun | 59,311 | 46,933 | 80.6% | 69.1 | 61.8% | 38.2% |
  | Jul | 53,804 | 50,132 | 69.7% | 66.7 | 56.6% | 45.3% |
  | Aug | 53,188 | 49,532 | 67.3% | 64.9 | 51.6% | 56.6% |

- **Why:** RivalCola 2L. In EC-NMB its sightings rose from 288 (March) to 499
  (August), and its facings from 1,699 to 5,881. Its average shelf price fell
  from R32.88 to R29.74. EC-NMB share of shelf is **51.6%** in August, while
  every other territory sits between 73.1% and 75.7%.
- **Year on year:** August sell-in was −29.7% (53,188 against 75,700 in
  August 2025). Year to date is −12.8% (514,036 against 589,578).
- The four EC-NMB agents are the bottom four of the 50 on August execution
  score, not counting Kagiso Molefe (see anomaly 6). Their averages run from
  62.3 to 67.4.

*Tools:* `getRateOfSale` with `territoryId: demo-territory-ec-nmb` over custom
whole months, optionally with `compareTo: previous_period` or
`same_period_last_year`. Then `getShareOfShelf` and `getCompetitorActivity` for
the cause.

```sql
-- sell-in by month for the territory (non-cancelled orders, dated by capture)
SELECT to_char(o.captured_at AT TIME ZONE 'Africa/Johannesburg','YYYY-MM') m, sum(l.quantity) units
FROM order_lines l JOIN orders o ON o.id = l.order_id JOIN outlets ot ON ot.id = o.outlet_id
WHERE ot.territory_id = 'EC-NMB' AND o.status <> 'cancelled' AND o.captured_at >= '2026-01-01'
GROUP BY 1 ORDER BY 1;
```

## 2. A chronic out-of-stock on the best seller — Kalahari Cola 2L in Durban

**What was planted.** Since the start of May 2026, **Kalahari Cola 2L** has
been out of stock in most `KZN` stores most of the time. Cola 2L is the
best-selling SKU: 2,200,352 units in the twelve months to August 2026, against
1,681,227 for Cola 1L in second place. The shortage is a distributor problem,
so Cola 2L sell-in in KZN collapses too.

**Questions**

1. "Where are we having availability problems?"
2. "What's out of stock in KwaZulu-Natal?"
3. "Why is KZN behind target last month?"

**A correct answer says**

- KZN has by far the worst on-shelf availability: **83.4% in August 2026**
  (452 of 2,730 counted lines empty, stockouts at all 40 outlets). Every other
  territory was between 93.3% and 95.6%.
- KZN availability was 94.6% in April and dropped to 86.8% in May. It has
  stayed at about 83–84% since.
- The problem is **Kalahari Cola 2L**. Over the last three months (17 June to
  16 September) it was out of stock on **74.9%** of KZN counts (1,427 counts).
  No other territory is above 7.5%.
- Cola 2L sell-in in KZN fell from **16,788 units in April to 5,390 in May**
  and stayed there: 5,412 in August, against 14,071 in August 2025 (−61.5%).
  That is why KZN reached only **78.0%** of its August territory target.
  KZN is −4.3% year on year for August.
- Knock-on: KZN has **505** overdue tasks, the most of any territory (the next
  is Mpumalanga with 139). Most are critical Cola 2L restock tasks.

**Judging note.** `getStockLevels` for KZN makes the territory obvious, but it
isn't broken down by SKU. `getSkuMovement` for KZN in August ranks Sunrise Apple
Juice first (47 days out) and puts Kalahari Cola 2L near the bottom (16 days).
That ranking is limitation 5 above: long streaks of empty counts read as zero
days. The SKU can still be found from the same result. Cola 2L has
**6,078 units on hand across 455 counts (about 13 per count)**, against 20,781
across 455 counts (about 46 per count) in Gauteng. An assistant that names
Apple Juice as the problem has been misled by the tool. One that notices the
Cola 2L stock level has found the insight.

```sql
SELECT o.territory_id, round(100.0 * count(*) FILTER (WHERE vs.units_available = 0) / count(*), 1) oos_pct
FROM visit_stock vs JOIN visits v ON v.id = vs.visit_id JOIN outlets o ON o.id = v.outlet_id
WHERE vs.sku_id = 'demo-sku-2' AND v.checkin_ts >= '2026-06-16T22:00:00Z'
GROUP BY 1 ORDER BY 2 DESC;
```

## 3. A retailer chain pricing above RRP — QuickSave

**What was planted.** QuickSave is a fictional supermarket chain with 18 stores:
4 each in GP, GP-TSH and GP-EKU, and 2 each in FS, MP and NW. Since mid-March
2026, about 80% of its shelf prices have been 11–22% above RRP. Before that it
priced like everyone else.

**Questions**

1. "Are any retailers overpricing our products?"
2. "Which stores have the worst price compliance?"
3. "What is QuickSave charging for Cola 2L?"

**A correct answer says** (no pricing tool yet, so see limitation 1; these are
the console figures)

- QuickSave is the problem. In August 2026 its average price deviation was
  **+13.7%**, and **83.3%** of its priced lines were more than 10% above RRP.
  All other outlets averaged +0.7%, with 1.6% of lines in breach.
- In August, **672 of the 934** price breaches (>10% over RRP) recorded
  anywhere were at QuickSave stores.
- Kalahari Cola 2L (RRP R34.99) averaged **R39.91** at QuickSave in August
  (+14.1%), against R35.14 elsewhere. Cola 1L (RRP R24.99) averaged R28.24
  against R25.12.
- Timeline: QuickSave's average deviation was +0.9% in January, +1.0% in
  February, +5.7% in March (the month it started), then +13–14% every month
  since.
- Worst stores over the last three months: QuickSave Boitekong (NW-002, +14.9%),
  QuickSave Matsulu (MP-002, +14.1%) and QuickSave Mbombela CBD (MP-008, +14.0%).
- Alerts: **424 of the 825** price-deviation alerts are at QuickSave, and 207
  price alerts are still unacknowledged.

```sql
SELECT o.name LIKE 'QuickSave %' AS quicksave, round(avg(p.deviation_pct)::numeric, 1) avg_dev,
  round(100.0 * count(*) FILTER (WHERE p.deviation_pct > 10) / count(*), 1) breach_pct
FROM visit_pricing p JOIN visits v ON v.id = p.visit_id JOIN outlets o ON o.id = v.outlet_id
WHERE v.checkin_ts >= '2026-07-31T22:00:00Z' AND v.checkin_ts < '2026-08-31T22:00:00Z'
GROUP BY 1;
```

## 4. A fraud pattern — Lwazi Mthembu's ghost visits

**What was planted.** From 6 July 2026, `GP-EKU` agent **Lwazi Mthembu** logs
ghost visits. They last seconds and check in right at the edge of the 50 m
geofence. He reuses the same three shelf photos, geotagged about 7 km away in
Benoni, and has failed check-ins from kilometres away. He also copies stock
counts from his previous visit.

**Questions**

1. "Are any agents gaming their visits?"
2. "Show me suspicious visits this month."
3. "Should I be worried about Lwazi?"

**A correct answer says**

- **Every flagged visit belongs to one agent, Lwazi Mthembu.**
  - Month to date (1–16 September): **77** visits with a risk score of 50 or
    more, all his, all scoring 100.
  - Previous week (7–13 September): **35** flagged visits, all his.
  - All time: **364** flagged visits, none from any other agent.
- The signals on those visits:
  - `fast_completion` on every one. His average dwell in August was **37
    seconds**; before July it was about 20 minutes.
  - `duplicate_photo` (byte-identical photo from a visit to a different outlet)
    on every one. All 586 of his photos are copies of just 3 images.
  - `photo_gps_divergence` on every one, with photo GPS about **6.9 km** from
    the check-in.
  - `geofence_distance` (44–49 m) on every one.
  - `failed_attempts` on 85 of the 147 flagged visits in the last 30 days.
- Failed check-ins in the last 30 days: **126 for Lwazi**, averaging
  **11.2 km** from the outlet (up to 22.9 km). The next-highest agent had 7, all
  within 180 m.
- **Why his numbers look good:** he has 100% beat-plan adherence (147 of 147
  planned stops in August), and his August execution score of **79.6** is the
  second-best of 50 (team average 72.9). He is second in the September Visit
  Sprint and tops the cancelled Gauteng East Spot Prize. A good answer treats
  his strong numbers as suspect.

*Tools:* `getFraudFlags` (default `minScore` 50) for the period, then
`getAgentScorecard` for "Lwazi".

## 5. A campaign that underperformed despite high execution — Winter Warmer

**What was planted.** Seven campaigns. Two worked, two flopped for different
reasons, one is running now and one is a draft. The easiest mistake is to read
good execution as success.

**Questions**

1. "Which campaigns delivered a return?"
2. "Did Winter Warmer work? Execution looked great."
3. "How is Braai Day doing?"

**A correct answer says** (no campaign tool yet, so see limitation 1; figures
from the campaign ROI and compliance endpoints)

| Campaign | Window | Budget | Attributed | Baseline | Lift | ROI | Planogram | Promo live |
|---|---|---|---|---|---|---|---|---|
| Kalahari Zero Winter Launch | 6 Jul – 16 Aug 2026 | R400,000 | R8,966,247 | R7,212,446 | **+24.3%** | **+338%** | 65.5% | 73.5% |
| Festive Cheer Carbonates | 17 Nov – 31 Dec 2025 | R600,000 | R9,455,277 | R7,454,233 | +26.8% | +234% | 63.1% | 72.1% |
| Easter Family Pack | 7 – 27 Apr 2025 | R60,000 | R1,856,347 | R1,726,521 | +7.5% | +116% | 60.2% | 72.1% |
| **Winter Warmer Hot Beverages** | 4 May – 14 Jun 2026 | R300,000 | R5,257,219 | R5,912,607 | **−11.1%** | **−318%** | **94.0%** | **96.5%** |
| Mzansi Water Challenge | 4 Aug – 14 Sep 2025 | R220,000 | R3,408,798 | R3,295,940 | +3.4% | −49% | 48.5% | 30.7% |
| Braai Day Snack Attack (active) | 1 – 30 Sep 2026 | R150,000 | R1,637,670 | R3,030,880 | (−46%) | (−1,029%) | 64.0% | 74.9% |
| Summer Refresh 2026 (draft) | 16 Nov – 31 Dec 2026 | R200,000 | — | — | — | — | — | — |

- **Winter Warmer** is the planted flop. Execution was the best of any
  campaign: 100% of its 50 outlets visited, **94.0%** planogram compliance, and
  the promotion live on **96.5%** of priced lines. Sell-in still came in
  **R655,388 below** the equal-length baseline before it, so it lost its whole
  R300,000 budget and more.
- **Mzansi Water Challenge** also failed, but because of poor execution:
  48.5% planogram and the promotion live on only 30.7% of lines. A good answer
  contrasts the two.
- **Kalahari Zero Winter Launch** clearly worked: +R1,753,802 incremental sell-in
  on R400,000.
- **Braai Day** is a trap. It is only half-way through, so 16 days of attributed
  sell-in are being compared with a full 30-day baseline. The −46% means
  nothing yet. A correct answer says so rather than calling it a failure.
- The Festive campaign's lift partly reflects the December seasonal peak (see
  Seasonality below).

## 6. A standout agent and a struggling one

**What was planted.** Naledi Sithole (`GP-TSH`) is excellent across the board.
Since about mid-February 2026, Kagiso Molefe (`MP`) skips about half his
planned stops, scores red and lets tasks breach their SLAs.

**Questions**

1. "Who is my best agent?"
2. "How is Kagiso doing compared with the team?"
3. "Which agents are falling behind on their route plans or their targets?"

**A correct answer says**

- **Naledi Sithole** had the top August execution score of the 50 agents:
  **85.95** against a team average of 72.70. Of her 144 visits, 132 were green.
  - Six months (Mar–Aug 2026): 885 visits, average 85.21, team average 72.83.
  - Month to date: 83 visits, average 85.09.
  - Beat-plan adherence in August: 144 of 147 planned stops (98.0%).
  - Outlet-level Cola targets in August: **158.5%** (16,614 against 10,483 units).
  - She had 20 tasks in August and none breached its SLA.
  - She won the **August 2026 Execution Cup** (85.95 points).
- **Kagiso Molefe** is last of the 50: **59.46** in August against a team
  average of 73.18. Of his 62 visits, 33 were red.
  - His weakest dimensions: visibility 43.2, display 43.2, sales capability 43.5.
  - Six months: 397 visits, average 58.72.
  - Month to date: 34 visits, average 58.81.
  - **He visited only 62 of 126 planned stops in August (49.2%).** Every other
    agent was at 85.7% or higher.
  - **Outlet-level Cola targets in August: 42.9%** (2,464 against 5,741 units).
  - 73.1% of his 26 August tasks breached their SLA, and he has 101 overdue
    tasks (46 of them raised since 1 June).
  - A manager messaged him about it on 8 September.
- Don't confuse the stories: the four EC-NMB agents also sit near the bottom
  (anomaly 1). Lwazi's second-place score is not a sign of good performance
  (anomaly 4).

*Tools:* `getAgentScorecard` for "Naledi" or "Kagiso", with a custom August
period or `mtd`. Beat-plan adherence and outlet targets are not in the
assistant's tools yet, so those figures are for console verification.

## 7. Year-on-year growth in one territory and decline in another

**What was planted.** From about September 2025, **Limpopo** (`LP`) grows
about 40% after winning new distribution, and **Free State** (`FS`) shrinks
about 30% after losing a wholesale account. The rest of the business grows
about 6% a year.

**Questions**

1. "How does Limpopo compare with the same period last year?"
2. "Which region has declined most against last year?"
3. "Are we up or down year to date overall?"

**A correct answer says**

- **Limpopo** year to date (1 Jan – 17 Sep): **834,100 units, against 577,853
  in the same period of 2025 (+44.3%)**. August 2026 was 100,817 against 72,440
  (+39.2%), and Limpopo reached **134.3%** of its August territory target.
- **Free State** year to date: **385,394 units, against 550,026 (−29.9%)**.
  August 2026 was 48,202 against 65,358 (−26.2%), and Free State reached
  **62.8%** of its August target.
- August against August last year, by territory:

  | Territory | Aug 2026 | Aug 2025 | Change |
  |---|---|---|---|
  | LP | 100,817 | 72,440 | +39.2% |
  | GP-EKU | 108,341 | 91,165 | +18.8% |
  | GP-TSH | 126,112 | 106,430 | +18.5% |
  | WC-WIN | 63,769 | 54,940 | +16.1% |
  | GP | 81,956 | 72,169 | +13.6% |
  | EC-BCM | 56,873 | 52,161 | +9.0% |
  | NW | 58,929 | 55,617 | +6.0% |
  | WC | 86,812 | 82,097 | +5.7% |
  | KZN-PMB | 51,329 | 49,015 | +4.7% |
  | MP | 70,560 | 68,417 | +3.1% |
  | KZN | 72,512 | 75,746 | −4.3% |
  | FS | 48,202 | 65,358 | −26.2% |
  | EC-NMB | 53,188 | 75,700 | −29.7% |

- For year to date the biggest decline is Free State (−29.9%), not EC-NMB
  (−12.8%): EC-NMB only started falling in March. Asked about August alone,
  EC-NMB (−29.7%) edges out Free State (−26.2%). A good answer notices the
  period changes the answer.
- The whole business year to date: **7,794,019 units, against 7,425,531
  (+5.0%)**. August: 979,400 against 921,255 (+6.3%).
- Year to date has no target (limitation 3). Month to date to 16 September:
  LP 55,037 against 43,207 (+27.4%), FS 22,986 against 37,074 (−38.0%).

*Tools:* `getRateOfSale` with `territoryId` and `compareTo:
same_period_last_year`, with `period: ytd` or a custom whole month.

---

## Other things planted that you can ask about

- **Seasonality.** Sell-in peaked in December 2025 at **1,167,991 units**, then
  fell to **692,368** in January 2026 (−40.7%). Month-end orders are larger:
  orders captured on the 26th or later average **R7,055**, against **R4,867** on
  other days.
- **Sales targets, with some met, some missed and some not set.** In August 2026
  client-wide attainment was **102.6%** (919,385 targeted units against
  895,760).
  - Met: Kalahari Cola 1L 113.8%, Chocolate Bar 110.7%, Kalahari Cola 2L 108.1%.
  - Missed: Kalahari Lemon 500ml 89.4%, Sunrise Apple Juice 91.8%, Full Cream
    Milk 92.1%.
  - **No client-wide target:** Highveld Yoghurt, Instant Coffee, Rusks and
    Sunrise Tropical.
  - **No territory targets at all:** North West. A null target is not a target
    of zero.
- **Tasks and SLAs.** 32,057 tasks in total:
  - 25,801 closed on time and 5,055 closed after breaching their SLA;
  - 1,201 still open, of which 1,059 are overdue.
- **Alerts.** 3,120 in total, 763 unacknowledged:
  - out of stock: 1,714 (400 open);
  - price deviation: 825 (207 open);
  - low execution score: 339 (92 open);
  - SLA breach: 242 (64 open).
- **Contests**, with standings computed from the points ledger:
  - *September Visit Sprint* (active): Naledi Sithole 166 points, Lwazi
    Mthembu 154, Boitumelo Seabi 142.
  - *Q3 2026 Perfect Store Challenge* (active): Kavitha Naidoo 1,605.25, Thabo
    Ngcobo 1,590.03, Bongani Zulu 1,544.82. The KZN agents lead on points from
    closing stockout tasks, which is worth questioning.
  - *KZN Close the Loop* (active): Thabo Ngcobo, 26 tasks closed.
  - *August 2026 Execution Cup* (ended): Naledi Sithole 85.95.
  - *Winter Warmer Blitz (Western Cape)* (ended): Yusuf Isaacs 417.11.
  - *Festive Push 2026*: upcoming.
  - *Gauteng East Spot Prize*: cancelled.

## Plain lookups

| Question | Expected answer |
|---|---|
| "How many visits did we do yesterday?" (asked 17 Sep) | 274 visits on Wednesday 16 September, each at a different outlet. |
| "How many visits last week?" | 1,345 visits, Monday 7 to Sunday 13 September, covering 399 of 400 outlets. |
| "How many visits in Gauteng East last week?" | 134. |
| "What was our sell-in in August and did we hit target?" | 979,400 units from all 400 outlets. Attainment 102.6%: 919,385 units on targeted SKUs against a target of 895,760. |
| "What's our share of shelf in the Western Cape this month?" | 76.1%: 6,540 of our facings against 2,053 competitor facings, from 264 visits. |
| "How was planogram compliance in the Western Cape in August?" | 64.3% average, cleanliness 3.2/5, high-traffic placement 65.4%, from 474 visits. |
| "How did Sipho Ndlovu do last month?" | 115 visits to 11 outlets, average score 71.4 against a team average of 73.1. |
| "What's our on-shelf availability this month?" (whole business) | 93.9%, but from a **truncated** read of the first 5,000 lines. A good answer says so or offers a territory breakdown. |
| "How many outlets and agents do we have?" | 400 outlets (123 spaza, 118 supermarket, 58 forecourt, 37 wholesaler, 34 convenience, 30 hypermarket) and 50 field agents in 13 territories. No tool counts these directly. |
