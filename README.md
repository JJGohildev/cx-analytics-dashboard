# Customer Experience Analytics in Power BI

I built this project to explore customer satisfaction and support performance using Power BI, SQL, and Excel. The report brings together service KPIs, monthly trends, feedback categories, and support channels.

Cedarbrook Home Goods is fictional. This portfolio project uses synthetic data covering January 2024 to August 2026.

[Download Power BI report](powerbi/CX_Analytics_PowerBI.pbix) · [Read case study](case_study.md) · [View SQL](sql/cx_kpi_queries.sql)

## Power BI report previews

These images were exported from the actual Power BI Desktop report.

### Overview

The Overview page presents ticket volume, CSAT, NPS, response time, resolution time, and first-contact resolution. This export shows August 2026; NPS uses the report's latest-quarter measure.

![Power BI Overview page showing customer support KPI cards](screenshots/CX_Overview.png)

### Trends

The Trends page compares ticket volume and average CSAT over time. This preview has **Billing & Payments** selected, so it represents that category rather than company-wide results.

![Power BI Trends page with Billing and Payments selected](screenshots/CX_Trends.png)

## What I worked on

- Prepared support data using SQL and Excel Power Query.
- Organized interaction records and supporting dimensions for reporting.
- Used DAX measures to calculate service KPIs.
- Built pages for Overview, Trends, Channel performance, Feedback patterns, and Team scorecard.
- Documented the data model, measures, and data-quality checks.

## Explore the project

| Resource | Contents |
| --- | --- |
| [Power BI report](powerbi/CX_Analytics_PowerBI.pbix) | Native Power BI Desktop file |
| [Case study](case_study.md) | Approach, report design, and limitations |
| [Data model](powerbi/DATA_MODEL.md) | Tables and relationships |
| [DAX measures](powerbi/DAX_MEASURES.md) | Definitions and reference values |
| [Build guide](powerbi/BUILD_GUIDE.md) | Report reconstruction steps |
| [SQL](sql/cx_kpi_queries.sql) | KPI queries and validation checks |
| [Excel workbook](excel/CX_Analytics_KPI_Workbook.xlsx) | Data preparation workbook |
| [Data](data/) | Source tables and dataset documentation |

## Open the report

Download the PBIX file and open it in Power BI Desktop. If refreshing prompts for missing local files, update the source paths to your downloaded data folder. The build guide describes the expected tables and types.

## Scope 

This is a personal portfolio project, not a client engagement. Simulated service events support analysis practice; changes in these KPIs do not establish real business impact or prove causation.
