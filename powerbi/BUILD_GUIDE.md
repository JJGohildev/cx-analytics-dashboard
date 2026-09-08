# Build guide: Power BI Desktop

Use this guide to rebuild the report from the CSV files in the data folder. A completed PBIX file is included alongside this guide.

The instructions describe the intended setup. Check the relationships, imported types, measures, and active filters against your own report as you work.

## 1. Import the data

1. Power BI Desktop → **Get Data → Text/CSV**.
2. Import these seven files from `../data/`, one at a time: `fact_interaction.csv`, `dim_customer.csv`, `dim_agent.csv`, `dim_category.csv`, `dim_date.csv`, `dim_channel.csv`, and `company_monthly_kpi.csv` (this last one is optional — it's a pre-aggregated table, not needed for the model below, but handy if you want to sanity-check a DAX measure against a known-correct number without writing a validation query).
3. For each import, click **Transform Data** rather than **Load** directly — you want a chance to check column types before they land in the model, not after.

## 2. Check column types in Power Query (before loading)

This is the step most likely to go wrong silently. In the Power Query Editor, for **`fact_interaction`**:

- `CSATScore` and `NPSScore`: confirm they're typed as **Decimal Number** / **Whole Number**, and that empty cells show as `null`, not `0`. If Power Query guessed the type from a sample that happened to have no blanks near the top, it can occasionally get this wrong — click into a few rows you know are blank (any row where `SurveySent = FALSE`) and confirm.
- `Date`: **Date** type, not text.
- `FCR`, `Escalated`, `SurveySent`, `NPSSent`: **True/False** (Boolean) type.
- `Month`: leave as **Text** — it's a display/join helper (`"2026-08"`), not used for time intelligence; `dim_date` handles that.

For **`dim_date`**: confirm `Date` is typed as **Date**, and `IsOutageMonth`/`IsPostLaunch` as **True/False**.

Click **Close & Apply** once these look right.

## 3. Build the relationships

Go to **Model view**. Power BI will often auto-detect some relationships on load (typically by matching column names) — check each one it created rather than trusting it, then add whichever it missed. You want exactly the five relationships in `DATA_MODEL.md`'s table, all many-to-one, single-direction, fact-to-dimension:

- `fact_interaction[CustomerID]` → `dim_customer[CustomerID]`
- `fact_interaction[AgentID]` → `dim_agent[AgentID]`
- `fact_interaction[Category]` → `dim_category[Category]`
- `fact_interaction[Channel]` → `dim_channel[Channel]`
- `fact_interaction[Date]` → `dim_date[Date]`

Drag from one field to the other to create any that are missing.

## 4. Mark the date table and set channel sort order

1. Right-click `dim_date` in the Fields pane → **Mark as date table** → choose the `Date` column. Do this before writing time-intelligence measures — `DATEADD`/`DATESINPERIOD` return blank without it.
2. Click into `dim_channel[Channel]` → **Column tools** → **Sort by column** → `ChannelSortOrder`. This makes every visual sliced by Channel display Phone → Chat → Email → Social instead of alphabetical order.

## 5. Add the DAX measures

Create a dedicated measures table so they're not scattered across the model (Model view → **Enter Data** → name it `_Measures`, one blank column, load it — this is a standard organizational pattern, not a data table). Paste in the measures from `DAX_MEASURES.md`, section by section. Check each one against its validation table as you go — don't wait until the whole report is built to discover a measure is wrong.

## 6. Report pages

Match the four sections of the original HTML dashboard as four report pages (or one scrolling page with clear section headers — your call):

**Page 1 — Overview.** Six card visuals across the top: Ticket Volume, Avg CSAT, NPS, Avg First Response, Avg Resolution, FCR Rate — each with its delta measure underneath (see `DAX_MEASURES.md` §3) and a small multiple/sparkline line chart if you want to match the original's per-tile trend lines. Below that, two line charts: Ticket Volume and Avg CSAT, both by `dim_date[MonthKey]`, with a category slicer.

**Page 2 — Channel performance.** Two clustered bar charts (Ticket Volume, Avg CSAT) by `dim_channel[Channel]`, both filtered to the trailing 3 months using the measures in `DAX_MEASURES.md` §5. A stacked area or 100% stacked bar chart for channel mix over time, by `dim_date[MonthKey]` and `dim_channel[Channel]`.

**Page 3 — Feedback patterns.** A bar chart for category mix (§6), sorted descending. A column chart for NPS by `dim_date[QuarterLabel]` (§2) — color the bars by sign (positive vs. negative) using a conditional formatting rule on the column color, not two separate series, so it stays one clean measure.

**Page 4 — Team scorecard.** A table or matrix visual per §4, filtered to `[Is Latest Month] = 1`.

## 7. Match the visual style (optional, but worth doing)

The HTML dashboard uses a deliberately minimal single-hue blue palette (chosen after the earlier "too many colors" feedback), validated against WCAG contrast and colorblind-safety checks. Reuse the same hex values for report-level theming so the two artifacts look like one project, not two:

```json
{
  "name": "Cedarbrook CX Pulse",
  "dataColors": ["#86b6ef", "#5598e7", "#2a78d6", "#1c5cab"],
  "background": "#f9f9f7",
  "foreground": "#0b0b0b",
  "tableAccent": "#2a78d6"
}
```

Save that as `cedarbrook_theme.json` and load it via **View → Themes → Browse for themes**. Series order matches `dim_channel[ChannelSortOrder]`: Phone gets the lightest tint, Social the darkest — that's the same "one hue, light-to-dark" ordinal ramp used for the channel charts in the HTML version, not four unrelated colors.

## 8. Save, then verify against the tables in `DAX_MEASURES.md`

Save as `CX_Analytics_PowerBI.pbix` into this `powerbi/` folder. Before you call it done, go through every validation table in `DAX_MEASURES.md` and confirm your build's numbers match. Any mismatch means something in the model — a relationship, a filter, a blank-vs-zero issue — is off, and it's much better to find that now than in an interview.

## 9. Commit it

```
git add powerbi/CX_Analytics_PowerBI.pbix
git commit -m "Add Power BI Desktop model backing the dashboard"
git push
```

`.pbix` is a binary file — git will store it as a blob (no meaningful diffs), which is normal and fine for a single portfolio file. If you iterate on it a lot, consider Power BI's newer `.pbip` project format (**File → Save As → Power BI project**) instead, which saves the model and report as readable text/JSON — genuinely diffable in git, and increasingly the standard way BI teams source-control Power BI work. Not required here, just worth knowing it exists.

## 10. Update the README

Once the `.pbix` exists, replace the current README wording (which correctly, but only, claims "Power BI-*style*" reporting) with something that names the real file, e.g.:

> `powerbi/CX_Analytics_PowerBI.pbix` — the Power BI Desktop report: data model, DAX measures, and report pages built directly on the same fact/dimension tables in `data/`. See `powerbi/DATA_MODEL.md` and `powerbi/DAX_MEASURES.md` for the model and measure definitions.

And add a screenshot or two of the actual Power BI report pages to `screenshots/`, the same way the HTML dashboard's screenshots are handled.
