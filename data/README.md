# Data generation

Everything in this folder is synthetically generated — no real customer data. `cedarbrook_cx_csv_tables.zip` is the shipped deliverable (import straight into Power BI Desktop); the loose CSVs alongside it are the same tables unzipped for convenience.

**Company:** Cedarbrook Home Goods (fictional multichannel home-goods retailer) · **Period:** Jan 2024 – Aug 2026 (32 months) · **Feedback categories:** Shipping & Delivery, Returns & Refunds, Product Quality, Billing & Payments, Website/App Experience, Customer Service · **Channels:** Phone, Chat, Email, Social

**Method:** Python (pandas/numpy/Faker) builds a customer pool and an agent roster, then simulates 19,944 support interactions month by month (`fact_interaction`), rolling them up into category-, channel-, and company-level monthly KPI tables. Two intentional events are seeded into the generation logic itself — not bolted on afterward — so every downstream table, query and chart derives from the same cause:

- A **regional shipping-carrier outage** during the Nov–Dec 2024 holiday peak spikes Shipping & Delivery (and, to a lesser extent, Returns & Refunds) ticket volume, blows out response and resolution time, and drags CSAT and NPS down.
- A **self-service returns portal + chatbot triage**, launched March 2025, deflects routine Shipping/Returns/Website inquiries, cuts first-response time (Chat especially — the bot answers instantly), and lifts CSAT, first-contact resolution, and NPS to a new baseline.

**A measurement-accuracy note:** NPS is collected as a per-interaction relationship pulse (~18% of tickets), not an account-level relationship survey, so it runs lower than typical NPS benchmarks — that's expected, not a data error. It's also reported quarterly rather than monthly in the dashboard: at ~250–400 responses/quarter company-wide, a monthly promoter-minus-detractor swing of ±10 points is mostly sampling noise. The underlying `NPSScore` field is still monthly-grain in the raw fact table; the quarterly rollup is a reporting choice, documented in `sql/cx_kpi_queries.sql` query 5.

**Tables**

| File | Contents |
|---|---|
| `dim_customer.csv` | One row per customer who contacted support in the window: name, gender, region, customer segment (New/Returning/Loyalty), signup date. |
| `dim_agent.csv` | One row per support agent: name, team, location, hire date. |
| `dim_category.csv` | The 6 feedback categories with primary team and baseline CSAT/FCR targets. |
| `fact_interaction.csv` | One row per support interaction: channel, category, first-response time, resolution time, first-contact resolution, escalation, CSAT/NPS survey fields. |
| `fact_monthly_category_kpi.csv` | `fact_interaction` rolled up to category + month. |
| `fact_monthly_channel_kpi.csv` | `fact_interaction` rolled up to channel + month. |
| `company_monthly_kpi.csv` | `fact_interaction` rolled up to company + month — feeds the headline KPI tiles. |
| `dim_date.csv` | Daily date dimension, Jan 2024 – Aug 2026 (974 rows), with month/quarter labels and `IsOutageMonth`/`IsPostLaunch` flags. Not used by the HTML dashboard — added for the Power BI model in [`../powerbi/`](../powerbi), which needs a table marked as a date table for time intelligence. |
| `dim_channel.csv` | The 4 channels with a `ChannelSortOrder` column, so Power BI (and any other tool that doesn't know the intended order) sorts Phone → Chat → Email → Social instead of alphabetically. Also added for the Power BI model. |

Regenerate `dim_date.csv`/`dim_channel.csv` with the snippet in [`../powerbi/DATA_MODEL.md`](../powerbi/DATA_MODEL.md) if the date range ever changes. Regenerate everything else from scratch with `generate_data.py` (raw tables) followed by `prep_dashboard_data.py` (the compact JSON payload the dashboard reads).
