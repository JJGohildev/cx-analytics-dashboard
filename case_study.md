# Customer Experience Analytics Dashboard

**Tools:** SQL &middot; Excel (Power Query) &middot; Power BI-style interactive reporting
**Role:** CX/Data Analyst (solo project)
**Timeline:** Data covers Jan 2024 &ndash; Aug 2026, modeled on a monthly support-operations reporting cycle

### The problem

Cedarbrook Home Goods' CX team tracked customer satisfaction, feedback patterns, and service performance across separate ticketing-system exports and spreadsheets that didn't always agree with each other. A rough week in support was hard to tell apart from a real trend, nobody could say with confidence which feedback categories were actually driving dissatisfaction, and by the time a monthly report was assembled the numbers it described were already stale. There was no single source of truth for "how is support actually performing," and no structured way to measure whether an intervention &mdash; more staffing, a new self-service tool &mdash; had moved the needle.

### Approach

I rebuilt the reporting workflow from the raw data up:

**Data cleaning (SQL + Power Query).** Ticketing-system exports arrive messy &mdash; inconsistent category and channel text, missing response-time values, duplicate rows, and the occasional keying error (a custom CSAT field that let a rep enter "6" on a 1&ndash;5 scale). I documented a repeatable Power Query cleaning pass (trim/normalize text, enforce data types, remove duplicates, range-check CSAT, fill gaps from category-month medians) so a bad export surfaces as an error at cleaning time rather than quietly skewing a KPI six steps downstream.

**Data validation.** Cleaning isn't trusted on faith &mdash; the SQL layer closes with nine explicit checks: orphan foreign keys, duplicate interaction IDs, CSAT/NPS scores outside their valid range, survey fields populated on interactions where no survey was sent, and resolution times that are logically impossible (shorter than the first-response time that preceded them). Every check returns zero against the cleaned data; a nonzero count is the trigger to go fix the upstream step before anyone reports off the numbers.

**KPI modeling (SQL).** With clean data landing in an interaction-grain fact table, a set of SQL queries computes the metrics that matter: company-wide monthly trend, feedback-category variance month over month, channel performance, a quarterly Net Promoter Score rollup, an agent/team scorecard, category volume mix, and a pre/post-launch variance summary comparing the self-service initiative's before and after.

**Dashboard.** The KPIs feed an interactive report modeled on a Power BI layout: six headline KPI tiles with 12-month sparklines, a feedback-category filter across three pages of trend charts (volume/CSAT, response/resolution time, first-contact-resolution/escalation), channel performance and channel-mix-over-time views, a feedback-category breakdown, a quarterly NPS chart, and a team scorecard &mdash; with hover tooltips on every chart so a value is never locked behind a color.

### What the data showed

Two events fell out of the KPIs once they were trustworthy and visible:

A regional shipping-carrier outage during the Nov&ndash;Dec 2024 holiday peak pushed monthly ticket volume from a baseline of ~610 to 1,274 &mdash; more than double &mdash; concentrated in Shipping & Delivery and Returns & Refunds. Average CSAT dropped from 4.12 to 3.77, first-response time climbed from 12.9 to 22.8 minutes, and quarterly NPS fell from -28.7 to a trough of -45.7. The category-level breakdown made it immediately obvious the outage, not a company-wide service problem, was the driver: Shipping & Delivery's own CSAT fell to 3.65 in December while Billing & Payments barely moved.

A self-service returns portal and chatbot triage launched in March 2025 shows up as a clean, immediate step change in the opposite direction: first-contact resolution jumped from 62.7% in February to 75.0% in March and has held in the low-to-mid 70s% since; average first-response time dropped to 8.2 minutes, below its pre-outage baseline, driven largely by Chat conversations the bot now resolves near-instantly; and CSAT settled into a new high around 4.4&ndash;4.5. Quarterly NPS crossed from negative to positive within two quarters of launch and has hovered near breakeven since &mdash; a real recovery, even if the sample size is too small for the month-to-month wiggle to mean much on its own.

### Outcome

- A single, validated source of truth for ticket volume, CSAT, NPS, response/resolution time, and first-contact resolution, refreshed from one cleaned fact table instead of reconciled spreadsheets.
- A feedback-category and channel view that shows precisely where a service disruption is concentrated, instead of a company-wide average that would have buried it for weeks.
- A documented before/after read on the self-service launch &mdash; first-contact resolution up roughly 12 points, first-response time down several minutes and below its pre-outage baseline, CSAT up over two tenths of a point &mdash; that a team can put in front of stakeholders to justify the investment and plan the next one.

*Note: Cedarbrook Home Goods is a fictional company and this dataset is synthetically generated to demonstrate the workflow above &mdash; the pipeline, queries, and validation checks are built exactly as they would be against a real ticketing-system export.*
