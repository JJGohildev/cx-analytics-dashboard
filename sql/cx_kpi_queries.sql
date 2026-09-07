/* =====================================================================
   Customer Experience Analytics Dashboard
   SQL layer: schema + KPI queries feeding the Power BI-style dashboard
   Dialect: ANSI SQL / SQL Server flavored (works on Snowflake/Postgres
   with minor tweaks, noted inline)
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1. SCHEMA (mirrors the cleaned tables produced by the Power Query step)
-- ---------------------------------------------------------------------
CREATE TABLE dim_customer (
    CustomerID       VARCHAR(10)   PRIMARY KEY,
    FullName         VARCHAR(100),
    Gender           VARCHAR(20),
    Region           VARCHAR(30),
    CustomerSegment  VARCHAR(20),
    SignupDate       DATE
);

CREATE TABLE dim_agent (
    AgentID    VARCHAR(10)  PRIMARY KEY,
    AgentName  VARCHAR(100),
    Team       VARCHAR(30),
    Location   VARCHAR(50),
    HireDate   DATE
);

CREATE TABLE dim_category (
    Category            VARCHAR(50)   PRIMARY KEY,
    PrimaryTeam         VARCHAR(30),
    BaselineCSATTarget  DECIMAL(3,2),   -- 1.00 - 5.00
    BaselineFCRTarget   DECIMAL(5,1)    -- target first-contact-resolution %
);

CREATE TABLE fact_interaction (
    InteractionID         VARCHAR(12)    PRIMARY KEY,
    CustomerID            VARCHAR(10),
    AgentID               VARCHAR(10),
    InteractionDate       DATE,
    MonthKey              DATE,          -- first day of month
    Category              VARCHAR(50),
    Channel               VARCHAR(20),   -- Phone / Chat / Email / Social
    FirstResponseMinutes  DECIMAL(6,1),
    ResolutionHours       DECIMAL(6,2),
    FCR                   BIT,           -- first-contact resolution
    Escalated             BIT,
    SurveySent            BIT,           -- post-interaction CSAT survey offered
    CSATScore             DECIMAL(2,1) NULL,  -- 1.0 - 5.0; NULL unless SurveySent = 1
    NPSSent               BIT,           -- relationship NPS pulse offered (~18% sample)
    NPSScore              TINYINT NULL,      -- 0 - 10; NULL unless NPSSent = 1
    CONSTRAINT FK_interaction_customer FOREIGN KEY (CustomerID) REFERENCES dim_customer(CustomerID),
    CONSTRAINT FK_interaction_agent    FOREIGN KEY (AgentID)    REFERENCES dim_agent(AgentID)
);


-- ---------------------------------------------------------------------
-- 2. COMPANY-WIDE MONTHLY KPI TREND
--    -> feeds the headline KPI tiles and the volume/CSAT/response-time
--       trend lines on the dashboard
-- ---------------------------------------------------------------------
SELECT
    MonthKey,
    COUNT(*)                                                                AS TicketVolume,
    ROUND(AVG(FirstResponseMinutes), 1)                                     AS AvgFirstResponseMinutes,
    ROUND(AVG(ResolutionHours), 2)                                          AS AvgResolutionHours,
    ROUND(100.0 * SUM(CASE WHEN FCR = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS FCRRatePct,
    ROUND(100.0 * SUM(CASE WHEN Escalated = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS EscalationRatePct,
    ROUND(AVG(CASE WHEN SurveySent = 1 THEN CSATScore END), 2)              AS AvgCSAT,
    ROUND(100.0 * SUM(CASE WHEN SurveySent = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS CSATResponseRatePct
FROM fact_interaction
GROUP BY MonthKey
ORDER BY MonthKey;


-- ---------------------------------------------------------------------
-- 3. FEEDBACK CATEGORY TREND WITH MONTH-OVER-MONTH CSAT VARIANCE
--    -> flags which feedback categories are driving the Nov/Dec 2024
--       carrier-outage dip, and by how much each recovers month to month
-- ---------------------------------------------------------------------
WITH cat_month AS (
    SELECT
        Category,
        MonthKey,
        COUNT(*)                                                                AS TicketVolume,
        ROUND(AVG(ResolutionHours), 2)                                          AS AvgResolutionHours,
        ROUND(100.0 * SUM(CASE WHEN FCR = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS FCRRatePct,
        ROUND(AVG(CASE WHEN SurveySent = 1 THEN CSATScore END), 2)              AS AvgCSAT
    FROM fact_interaction
    GROUP BY Category, MonthKey
)
SELECT
    Category,
    MonthKey,
    TicketVolume,
    AvgResolutionHours,
    FCRRatePct,
    AvgCSAT,
    AvgCSAT - LAG(AvgCSAT) OVER (PARTITION BY Category ORDER BY MonthKey) AS CSAT_MoM_Variance
FROM cat_month
ORDER BY Category, MonthKey;


-- ---------------------------------------------------------------------
-- 4. CHANNEL PERFORMANCE (Phone / Chat / Email / Social) BY MONTH
--    -> shows the mix shift toward Chat and the response-time gap
--       between channels, most visible after the Mar-2025 chatbot launch
-- ---------------------------------------------------------------------
SELECT
    Channel,
    MonthKey,
    COUNT(*)                                                                AS TicketVolume,
    ROUND(AVG(FirstResponseMinutes), 1)                                     AS AvgFirstResponseMinutes,
    ROUND(AVG(ResolutionHours), 2)                                          AS AvgResolutionHours,
    ROUND(100.0 * SUM(CASE WHEN FCR = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)   AS FCRRatePct,
    ROUND(AVG(CASE WHEN SurveySent = 1 THEN CSATScore END), 2)              AS AvgCSAT
FROM fact_interaction
GROUP BY Channel, MonthKey
ORDER BY Channel, MonthKey;


-- ---------------------------------------------------------------------
-- 5. NPS — QUARTERLY, NOT MONTHLY, ON PURPOSE
--    Only ~18% of interactions carry an NPS pulse (~250-400/quarter
--    company-wide). At that sample size a monthly promoter-minus-detractor
--    swings +/-10pp on noise alone even when nothing has changed — reporting
--    it monthly would read as volatility that isn't there. Quarterly keeps
--    the standard error small enough for the trend to mean something.
-- ---------------------------------------------------------------------
WITH nps_quarter AS (
    SELECT
        DATEFROMPARTS(YEAR(MonthKey), 1 + 3 * ((MONTH(MonthKey) - 1) / 3), 1) AS QuarterStart,
        NPSScore
    FROM fact_interaction
    WHERE NPSSent = 1
)
SELECT
    QuarterStart,
    COUNT(*)                                                                   AS Responses,
    ROUND(100.0 * SUM(CASE WHEN NPSScore >= 9 THEN 1 ELSE 0 END) / COUNT(*), 1) AS PromoterPct,
    ROUND(100.0 * SUM(CASE WHEN NPSScore <= 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS DetractorPct,
    ROUND(100.0 * SUM(CASE WHEN NPSScore >= 9 THEN 1 ELSE 0 END) / COUNT(*), 1)
        - ROUND(100.0 * SUM(CASE WHEN NPSScore <= 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS NPS
FROM nps_quarter
GROUP BY QuarterStart
ORDER BY QuarterStart;


-- ---------------------------------------------------------------------
-- 6. AGENT SCORECARD (latest month) — the table behind the dashboard's
--    agent performance view, ranked by CSAT then FCR
-- ---------------------------------------------------------------------
WITH latest_month AS (
    SELECT MAX(MonthKey) AS MonthKey FROM fact_interaction
)
SELECT
    a.AgentID,
    a.AgentName,
    a.Team,
    COUNT(*)                                                                AS TicketsHandled,
    ROUND(AVG(CASE WHEN f.SurveySent = 1 THEN f.CSATScore END), 2)          AS AvgCSAT,
    ROUND(100.0 * SUM(CASE WHEN f.FCR = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS FCRRatePct,
    ROUND(AVG(f.ResolutionHours), 2)                                       AS AvgResolutionHours,
    RANK() OVER (ORDER BY AVG(CASE WHEN f.SurveySent = 1 THEN f.CSATScore END) DESC) AS CSATRank
FROM fact_interaction f
JOIN dim_agent a ON a.AgentID = f.AgentID
CROSS JOIN latest_month lm
WHERE f.MonthKey = lm.MonthKey
GROUP BY a.AgentID, a.AgentName, a.Team
HAVING COUNT(*) >= 5   -- exclude agents with too few tickets this month to rank fairly
ORDER BY CSATRank;


-- ---------------------------------------------------------------------
-- 7. FEEDBACK CATEGORY MIX (all-time volume share) — feeds the donut
--    chart behind "feedback patterns"
-- ---------------------------------------------------------------------
SELECT
    Category,
    COUNT(*)                                            AS TicketVolume,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS PctOfTotal
FROM fact_interaction
GROUP BY Category
ORDER BY TicketVolume DESC;


-- ---------------------------------------------------------------------
-- 8. VARIANCE SUMMARY: PRE-LAUNCH vs POST-LAUNCH (single-row comparison)
--    Self-service returns portal + chatbot triage launched 2025-03-01
-- ---------------------------------------------------------------------
SELECT
    ROUND(AVG(CASE WHEN MonthKey <  '2025-03-01' THEN CASE WHEN SurveySent = 1 THEN CSATScore END END), 2) AS AvgCSAT_Pre,
    ROUND(AVG(CASE WHEN MonthKey >= '2025-03-01' THEN CASE WHEN SurveySent = 1 THEN CSATScore END END), 2) AS AvgCSAT_Post,
    ROUND(AVG(CASE WHEN MonthKey <  '2025-03-01' THEN FirstResponseMinutes END), 1)                        AS AvgFirstResponse_Pre,
    ROUND(AVG(CASE WHEN MonthKey >= '2025-03-01' THEN FirstResponseMinutes END), 1)                        AS AvgFirstResponse_Post,
    ROUND(100.0 * SUM(CASE WHEN MonthKey <  '2025-03-01' AND FCR = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN MonthKey < '2025-03-01' THEN 1 ELSE 0 END), 0), 1)                          AS FCRRate_Pre,
    ROUND(100.0 * SUM(CASE WHEN MonthKey >= '2025-03-01' AND FCR = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN MonthKey >= '2025-03-01' THEN 1 ELSE 0 END), 0), 1)                         AS FCRRate_Post
FROM fact_interaction;


-- ---------------------------------------------------------------------
-- 9. DATA QUALITY CHECKS (used while validating the Power Query cleanup)
--    -> every check below should return Issue_Count = 0 on the cleaned
--       fact_interaction table; a nonzero count means a cleaning step
--       upstream needs to be revisited before the KPIs can be trusted
-- ---------------------------------------------------------------------
SELECT 'Orphan fact rows (no matching customer)' AS Check_Name, COUNT(*) AS Issue_Count
FROM fact_interaction f
LEFT JOIN dim_customer c ON c.CustomerID = f.CustomerID
WHERE c.CustomerID IS NULL

UNION ALL

SELECT 'Orphan fact rows (no matching agent)', COUNT(*)
FROM fact_interaction f
LEFT JOIN dim_agent a ON a.AgentID = f.AgentID
WHERE a.AgentID IS NULL

UNION ALL

SELECT 'Duplicate InteractionID keys', COUNT(*) - COUNT(DISTINCT InteractionID)
FROM fact_interaction

UNION ALL

SELECT 'CSATScore out of 1.0-5.0 range', COUNT(*)
FROM fact_interaction
WHERE CSATScore IS NOT NULL AND (CSATScore < 1.0 OR CSATScore > 5.0)

UNION ALL

SELECT 'NPSScore out of 0-10 range', COUNT(*)
FROM fact_interaction
WHERE NPSScore IS NOT NULL AND (NPSScore < 0 OR NPSScore > 10)

UNION ALL

SELECT 'CSATScore present without SurveySent', COUNT(*)
FROM fact_interaction
WHERE SurveySent = 0 AND CSATScore IS NOT NULL

UNION ALL

SELECT 'NPSScore present without NPSSent', COUNT(*)
FROM fact_interaction
WHERE NPSSent = 0 AND NPSScore IS NOT NULL

UNION ALL

SELECT 'ResolutionHours less than FirstResponseMinutes (impossible)', COUNT(*)
FROM fact_interaction
WHERE ResolutionHours < FirstResponseMinutes / 60.0

UNION ALL

SELECT 'Negative or null FirstResponseMinutes/ResolutionHours', COUNT(*)
FROM fact_interaction
WHERE FirstResponseMinutes IS NULL OR ResolutionHours IS NULL
   OR FirstResponseMinutes < 0 OR ResolutionHours < 0;
