# DAX measures

Written against the star schema in `DATA_MODEL.md`. I wrote these — I have
not run them, because there is no Power BI engine in this environment to run
them against. Every measure that feeds a number currently shown on the HTML
dashboard has an **expected value** next to it, taken from the same
independently-verified source data used in the project audit. Build the
measure, put it in a card visual, and check it against the number given —
that's your test, not my say-so.

**Before writing any measure:** confirm `CSATScore`/`NPSScore` import as
blank (not `0`) for un-surveyed rows — see the note at the end of
`DATA_MODEL.md`. Every measure below relies on it.

---

## 1. Base measures (no time intelligence)

```dax
Ticket Volume = COUNTROWS(fact_interaction)

Avg CSAT =
AVERAGE(fact_interaction[CSATScore])
-- AVERAGE() ignores blanks automatically — this already only
-- averages surveyed rows, with no explicit filter needed.

CSAT Response Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_interaction), fact_interaction[SurveySent] = TRUE),
    [Ticket Volume]
)

Avg First Response (min) = AVERAGE(fact_interaction[FirstResponseMinutes])

Avg Resolution (hr) = AVERAGE(fact_interaction[ResolutionHours])

FCR Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_interaction), fact_interaction[FCR] = TRUE),
    [Ticket Volume]
)

Escalation Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_interaction), fact_interaction[Escalated] = TRUE),
    [Ticket Volume]
)
```

**Validate against the latest month (Aug 2026) — filter or slice to
`dim_date[MonthKey] = "2026-08"`:**

| Measure | Expected |
|---|---|
| Ticket Volume | 614 |
| Avg CSAT | 4.41 |
| CSAT Response Rate | 56.4% |
| Avg First Response (min) | 9.9 |
| Avg Resolution (hr) | 6.49 |
| FCR Rate | 74.3% |
| Escalation Rate | 9.0% |

---

## 2. NPS

NPS needs promoters-minus-detractors, each independently rounded to one
decimal *before* subtracting — that's how the SQL layer and the Python prep
script both compute it (see `sql/cx_kpi_queries.sql` query 5), and the
dashboard's numbers were verified against that exact method. If you subtract
first and round once at the end, you'll get answers that are off by up to
0.1 from every number below — small, but it's exactly the kind of
"why doesn't this reconcile" gap an interviewer will notice if they check.

```dax
NPS Responses = CALCULATE(COUNTROWS(fact_interaction), fact_interaction[NPSSent] = TRUE)

NPS Promoter % =
ROUND(
    DIVIDE(
        CALCULATE(COUNTROWS(fact_interaction), fact_interaction[NPSSent] = TRUE, fact_interaction[NPSScore] >= 9),
        [NPS Responses]
    ) * 100, 1
)

NPS Detractor % =
ROUND(
    DIVIDE(
        CALCULATE(COUNTROWS(fact_interaction), fact_interaction[NPSSent] = TRUE, fact_interaction[NPSScore] <= 6),
        [NPS Responses]
    ) * 100, 1
)

NPS = [NPS Promoter %] - [NPS Detractor %]
```

**Validate — slice by `dim_date[QuarterLabel]`:**

| Quarter | Expected NPS |
|---|---|
| 2024Q4 (the outage quarter) | -45.7 |
| 2025Q1 (pre-launch baseline quarter) | -7.2 |
| 2026Q3 (latest) | -1.7 |

The dashboard deliberately reports NPS **quarterly, not monthly** — at
~18% survey participation the monthly sample is small enough (~250-400
responses/quarter company-wide) that a monthly promoter-minus-detractor swing
of ±10 points is mostly noise. If you build a monthly NPS visual for
exploration, that's fine, but don't present it as a trend without the same
caveat.

---

## 3. Time-intelligence deltas (headline KPI cards)

Two different comparison bases are used across the six KPI cards on the
original dashboard, and the audit flagged this as inconsistent and worth
either standardizing or explicitly justifying — see finding #4. Both are
given here so you can decide; I'd lean toward standardizing all six to
**prior month** for the Power BI rebuild, since "prior month" is a real DAX
time-intelligence pattern (`DATEADD`) worth demonstrating, while "vs a fixed
historical month" is really just a hardcoded filter, not time intelligence.

```dax
-- Prior-month pattern (requires dim_date marked as a date table)
Ticket Volume PM = CALCULATE([Ticket Volume], DATEADD(dim_date[Date], -1, MONTH))
Ticket Volume Δ vs PM = [Ticket Volume] - [Ticket Volume PM]

Avg Resolution (hr) PM = CALCULATE([Avg Resolution (hr)], DATEADD(dim_date[Date], -1, MONTH))
Avg Resolution (hr) Δ vs PM = [Avg Resolution (hr)] - [Avg Resolution (hr) PM]

-- Fixed pre-launch baseline pattern (Feb 2025, the last full month before
-- the Mar-2025 launch) — CALCULATE overrides whatever month the visual is
-- otherwise filtered to, pinning this one measure to a fixed point in time
Avg CSAT Pre-Launch = CALCULATE([Avg CSAT], dim_date[MonthKey] = "2025-02")
Avg CSAT Δ vs Launch = [Avg CSAT] - [Avg CSAT Pre-Launch]

Avg First Response (min) Pre-Launch = CALCULATE([Avg First Response (min)], dim_date[MonthKey] = "2025-02")
Avg First Response (min) Δ vs Launch = [Avg First Response (min)] - [Avg First Response (min) Pre-Launch]

FCR Rate Pre-Launch = CALCULATE([FCR Rate], dim_date[MonthKey] = "2025-02")
FCR Rate Δ vs Launch pp = ([FCR Rate] - [FCR Rate Pre-Launch]) * 100
-- multiplying by 100 here converts a rate-delta into whole percentage
-- points for display — label it "pp", never "%", see the audit's note on
-- distinguishing % from pp
```

**Validate at Aug 2026:**

| Measure | Expected |
|---|---|
| Ticket Volume Δ vs PM | +32 |
| Avg Resolution (hr) Δ vs PM | +0.29 (displays as +0.3) |
| Avg CSAT Δ vs Launch | +0.22 |
| Avg First Response (min) Δ vs Launch | -4.1 |
| FCR Rate Δ vs Launch pp | +11.6 |
| NPS Δ vs Launch (latest quarter minus 2025Q1) | +5.5 |

---

## 4. Team scorecard

Grain: Team × latest month. This is the table the audit flagged as having
**no SQL query behind it** in the original repo (finding #2) — it was built
directly in pandas from the raw fact table, skipping the SQL layer entirely.
Building it properly in DAX, sliced by `dim_agent[Team]`, closes that gap for
real: this measure set + a table visual sliced by Team *is* the query, in a
form you can point at directly.

```dax
Latest Month Text = CALCULATE(MAX(fact_interaction[Month]), ALL(fact_interaction))
Is Latest Month = IF(SELECTEDVALUE(dim_date[MonthKey]) = [Latest Month Text], 1, 0)
```

Add `Is Latest Month` as a visual-level filter (`= 1`) on the team-scorecard
table/matrix, put `dim_agent[Team]` on rows, and drop in `[Ticket Volume]`,
`[Avg CSAT]`, `[FCR Rate]`, `[Avg First Response (min)]`,
`[Avg Resolution (hr)]`, `[Escalation Rate]` as values.

**Validate — Aug 2026, by team:**

| Team | Tickets | Avg CSAT | FCR | Avg First Resp | Avg Resolution | Escalation |
|---|---|---|---|---|---|---|
| Billing & Payments | 80 | 4.56 | 90.0% | 7.1 min | 4.18 hr | 6.2% |
| Tier 1 Support | 362 | 4.46 | 74.3% | 9.7 min | 6.60 hr | 8.0% |
| Returns & Refunds | 114 | 4.31 | 78.1% | 11.8 min | 7.42 hr | 13.2% |
| Tier 2 Support | 58 | 4.11 | 44.8% | 10.8 min | 7.15 hr | 10.3% |

(Tickets sum to 614 — the same latest-month total as the KPI card. If your
build doesn't sum to that, a relationship or filter is wrong somewhere.)

Worth knowing before you're asked about it: **Tier 1 Support alone covers
three of the six feedback categories** (Shipping & Delivery, Product
Quality, Customer Service — 60% of all volume), while Returns & Refunds and
Billing & Payments each get a dedicated team. That's a modeling assumption
from the original data generator, not something the data model discovers —
be ready to say so if asked why Tier 1's row is so much bigger than the
others.

---

## 5. Channel comparison (fixes audit finding #3)

This is the one finding from the audit that a proper DAX rebuild fixes
*automatically*, and it's worth understanding why. The original HTML
dashboard computed this by averaging three already-monthly-averaged CSAT
numbers together (`AvgCSAT.mean()` over 3 rows of a pre-aggregated CSV) —
an unweighted "average of averages" that's biased whenever monthly volume
isn't stable. As long as you build these measures against `fact_interaction`
directly — interaction grain, not a pre-rolled-up table — and let DAX's
filter context do the aggregation, there's no pre-averaged intermediate step
for the bias to hide in.

```dax
Channel Ticket Volume (Trailing 3mo) =
CALCULATE(
    [Ticket Volume],
    DATESINPERIOD(dim_date[Date], MAX(dim_date[Date]), -3, MONTH)
)

Channel Avg CSAT (Trailing 3mo) =
CALCULATE(
    [Avg CSAT],
    DATESINPERIOD(dim_date[Date], MAX(dim_date[Date]), -3, MONTH)
)
```

Slice by `dim_channel[Channel]`, filtered/slicered to Jun–Aug 2026.

**Validate (these are the corrected, volume-weighted numbers — not the
slightly-off ones currently on the live HTML dashboard):**

| Channel | Volume | Avg CSAT |
|---|---|---|
| Phone | 535 | 4.43 |
| Chat | 724 | 4.43 |
| Email | 394 | 4.46 |
| Social | 135 | 4.51 |

(These round to nearly the same displayed values as the HTML dashboard's
biased version in this particular window — the bug is real but its effect
here is small; see the audit for a window where it isn't.)

---

## 6. Category mix (all-time)

```dax
Category Ticket Volume = [Ticket Volume]   -- sliced by dim_category[Category], no date filter
Category % of Total = DIVIDE([Category Ticket Volume], CALCULATE([Ticket Volume], ALL(dim_category)))
```

**Validate — all-time, by category:**

| Category | Tickets | % of total |
|---|---|---|
| Shipping & Delivery | 6,071 | 30.4% |
| Returns & Refunds | 3,380 | 16.9% |
| Customer Service | 3,126 | 15.7% |
| Product Quality | 3,114 | 15.6% |
| Billing & Payments | 2,456 | 12.3% |
| Website/App Experience | 1,797 | 9.0% |

Total: 19,944.
