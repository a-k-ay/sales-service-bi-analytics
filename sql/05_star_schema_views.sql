/* =====================================================================
   05 - STAR SCHEMA for Power BI  (Skill: "analytical data modeling",
        "semantic layer", "report curation")
   Clean, conformed views in schema [bi]. Power BI imports ONLY these.

   Facts                       Dimensions
   ---------------------       -------------------------------
   bi.fact_sales               bi.dim_date
   bi.fact_service_ticket      bi.dim_customer (dedup + clean country)
   bi.fact_machine_daily       bi.dim_product
                               bi.dim_machine
                               bi.dim_region
   ===================================================================== */
USE SalesServiceBI;
GO

/* ---------- date dimension (a real table, so Power BI can mark it) ---------- */
DROP TABLE IF EXISTS bi.dim_date;
GO
WITH n AS (
    SELECT TOP (DATEDIFF(DAY, '2024-01-01', '2026-12-31') + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS i
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
SELECT
    d                                       AS [date],
    CONVERT(INT, FORMAT(d, 'yyyyMMdd'))     AS date_key,
    YEAR(d)                                 AS [year],
    DATEPART(QUARTER, d)                    AS [quarter],
    'Q' + CAST(DATEPART(QUARTER, d) AS VARCHAR(1)) + ' ' + CAST(YEAR(d) AS VARCHAR(4)) AS quarter_label,
    MONTH(d)                                AS month_num,
    FORMAT(d, 'MMM yyyy')                   AS month_label,
    CONVERT(INT, FORMAT(d, 'yyyyMM'))       AS year_month,
    DATENAME(WEEKDAY, d)                    AS weekday_name,
    CASE WHEN DATEPART(WEEKDAY, d) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
INTO bi.dim_date
FROM (SELECT DATEADD(DAY, i, CAST('2024-01-01' AS DATE)) AS d FROM n) x;
-- SELECT ... INTO creates [date] as NULL-able (SQL Server can't prove DATEADD never
-- returns NULL), and a primary key needs NOT NULL, so tighten the column first.
ALTER TABLE bi.dim_date ALTER COLUMN [date] DATE NOT NULL;
GO
-- Own batch: SQL Server checks a whole batch before running it, so in the batch above it
-- would still see the NULL-able column and refuse the key.
ALTER TABLE bi.dim_date ADD CONSTRAINT PK_dim_date PRIMARY KEY ([date]);
GO

/* ---------- region ---------- */
CREATE OR ALTER VIEW bi.dim_region AS
SELECT region_code, region_name, super_region FROM raw.dim_region;
GO

/* ---------- customer: clean countries + collapse duplicates (MDM "golden record") ---------- */
CREATE OR ALTER VIEW bi.customer_master_map AS
-- maps every source customer_id to one surviving (golden) customer_id
SELECT customer_id AS source_customer_id,
       MIN(customer_id) OVER (PARTITION BY UPPER(REPLACE(customer_name, 'LIMITED', 'LTD'))) AS golden_customer_id
FROM raw.dim_customer;
GO

-- Country spellings and regions come from the reference tables created in 04
-- (bi.ref_country_alias, bi.ref_country_region): region is derived from the country.
CREATE OR ALTER VIEW bi.dim_customer AS
SELECT c.customer_id,
       c.customer_number,
       c.customer_name,
       ISNULL(c.industry_segment, 'Unknown') AS industry_segment,
       ISNULL(c.account_tier, 'Unassigned')  AS account_tier,
       COALESCE(a.country, c.country)        AS country,
       COALESCE(r.region_code, c.region_code) AS region_code,
       c.region_code                         AS source_region_code,   -- as typed in the ERP
       CASE WHEN r.region_code IS NULL            THEN 'Country not in reference list'
            WHEN r.region_code <> c.region_code   THEN 'Region corrected from country'
            ELSE 'OK' END                    AS region_check          -- DQ09, for the DQ page
FROM raw.dim_customer c
LEFT JOIN bi.ref_country_alias  a ON a.alias = c.country COLLATE Latin1_General_CS_AS
LEFT JOIN bi.ref_country_region r ON r.country = COALESCE(a.country, c.country)
WHERE c.customer_id IN (SELECT golden_customer_id FROM bi.customer_master_map);
GO

/* ---------- product ---------- */
CREATE OR ALTER VIEW bi.dim_product AS
SELECT product_id, product_code, product_name, product_family, product_type,
       industry, list_price_usd, std_cost_usd
FROM raw.dim_product;
GO

/* ---------- machine (installed base) ---------- */
CREATE OR ALTER VIEW bi.dim_machine AS
SELECT m.machine_id, m.serial_number,
       mm.golden_customer_id AS customer_id,
       m.product_id, m.install_date, m.monitoring_tier,
       CASE m.monitoring_tier WHEN 'No Contract' THEN 0 WHEN 'Bronze' THEN 1
            WHEN 'Silver' THEN 2 WHEN 'Gold' THEN 3 WHEN 'Platinum' THEN 4 END AS monitoring_tier_rank,
       CASE WHEN m.monitoring_tier = 'No Contract' THEN 'Not Monitored' ELSE 'Monitored' END AS is_monitored
FROM raw.dim_machine m
JOIN bi.customer_master_map mm ON mm.source_customer_id = m.customer_id;
GO

/* ---------- FACT: sales (order-line grain) ---------- */
CREATE OR ALTER VIEW bi.fact_sales AS
SELECT l.order_line_id,
       o.order_id, o.order_number, o.order_date, o.ship_date,
       mm.golden_customer_id AS customer_id,
       l.product_id, o.sales_rep_id, o.order_type, o.order_status,
       l.quantity,
       l.net_amount_usd,
       CAST(l.quantity * p.std_cost_usd AS DECIMAL(16,2)) AS std_cost_amount_usd
FROM raw.sales_order_line l
JOIN raw.sales_order o          ON o.order_id = l.order_id
JOIN bi.customer_master_map mm  ON mm.source_customer_id = o.customer_id
JOIN raw.dim_product p          ON p.product_id = l.product_id      -- drops orphan lines (DQ04)
WHERE l.quantity > 0                                                 -- drops invalid qty (DQ05)
  AND o.order_status <> 'Cancelled';
GO

/* ---------- FACT: service tickets (ticket grain, deduplicated) ---------- */
CREATE OR ALTER VIEW bi.fact_service_ticket AS
SELECT ticket_id, ticket_number, machine_id, customer_id,
       CAST(opened_at AS DATE) AS opened_date, opened_at, closed_at,
       issue_category, priority, channel, resolution_type, status, downtime_hours,
       CASE WHEN closed_at >= opened_at
            THEN DATEDIFF(MINUTE, opened_at, closed_at) / 60.0 END AS resolution_hours  -- NULL for DQ07
FROM (
    SELECT t.ticket_id, t.ticket_number, t.machine_id,
           mm.golden_customer_id AS customer_id,
           t.opened_at, t.closed_at, t.issue_category, t.priority, t.channel,
           t.resolution_type, t.status, t.downtime_hours,
           ROW_NUMBER() OVER (PARTITION BY t.ticket_id ORDER BY t.ticket_id) AS rn       -- DQ06
    FROM raw.service_ticket t
    JOIN bi.customer_master_map mm ON mm.source_customer_id = t.customer_id
) x
WHERE rn = 1;
GO

/* ---------- FACT: machine daily performance (machine x day grain) ---------- */
CREATE OR ALTER VIEW bi.fact_machine_daily AS
SELECT machine_id, perf_date, planned_hours, run_hours, ideal_rate_per_hour,
       total_parts, good_parts, scrap_parts,
       CAST(run_hours * ideal_rate_per_hour AS BIGINT) AS ideal_parts
FROM raw.machine_daily_performance
WHERE run_hours IS NOT NULL AND good_parts <= total_parts;            -- DQ08
GO

-- smoke test
SELECT 'fact_sales' v, COUNT(*) n FROM bi.fact_sales UNION ALL
SELECT 'fact_service_ticket', COUNT(*) FROM bi.fact_service_ticket UNION ALL
SELECT 'fact_machine_daily', COUNT(*) FROM bi.fact_machine_daily UNION ALL
SELECT 'dim_customer', COUNT(*) FROM bi.dim_customer;
