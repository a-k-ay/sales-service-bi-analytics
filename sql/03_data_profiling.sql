/* =====================================================================
   03 - DATA PROFILING  (Skill: "Perform Data Profiling and Data Analysis
        activities to understand data sources")
   Run each block, read the result, and write ONE sentence about what
   you learned in docs/profiling_notes.md: what you saw, and why it
   matters to the business.
   ===================================================================== */
USE SalesServiceBI;
GO

-- P1. Volume and date range of every transactional table
SELECT 'sales_order' AS tbl, COUNT(*) AS rows, MIN(order_date) AS min_dt, MAX(order_date) AS max_dt FROM raw.sales_order
UNION ALL
SELECT 'service_ticket', COUNT(*), MIN(CAST(opened_at AS DATE)), MAX(CAST(opened_at AS DATE)) FROM raw.service_ticket
UNION ALL
SELECT 'machine_daily_performance', COUNT(*), MIN(perf_date), MAX(perf_date) FROM raw.machine_daily_performance;

-- P2. Column completeness (null %) for the customer master
SELECT
    COUNT(*)                                                         AS total_rows,
    100.0 * SUM(CASE WHEN industry_segment IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS pct_null_segment,
    100.0 * SUM(CASE WHEN account_tier     IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS pct_null_tier,
    100.0 * SUM(CASE WHEN country          IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS pct_null_country,
    100.0 * SUM(CASE WHEN region_code      IS NULL THEN 1 ELSE 0 END) / COUNT(*) AS pct_null_region
FROM raw.dim_customer;

-- P3. Distinct values / cardinality - spot inconsistent spellings
SELECT country, region_code, COUNT(*) AS customers
FROM raw.dim_customer
GROUP BY country, region_code
ORDER BY region_code, country;

-- P4. Key uniqueness: is customer_name unique? (hint: it should be, per MDM)
SELECT UPPER(REPLACE(customer_name, 'LIMITED', 'LTD')) AS normalised_name,
       COUNT(*) AS records, STRING_AGG(customer_number, ', ') AS customer_numbers
FROM raw.dim_customer
GROUP BY UPPER(REPLACE(customer_name, 'LIMITED', 'LTD'))
HAVING COUNT(*) > 1;

-- P5. Numeric distribution of order line values
SELECT o.order_type,
       COUNT(*)                          AS lines,
       MIN(l.net_amount_usd)             AS min_amt,
       AVG(l.net_amount_usd)             AS avg_amt,
       MAX(l.net_amount_usd)             AS max_amt,
       SUM(CASE WHEN l.quantity <= 0 THEN 1 ELSE 0 END) AS non_positive_qty
FROM raw.sales_order_line l
JOIN raw.sales_order o ON o.order_id = l.order_id
GROUP BY o.order_type;

-- P6. Median ticket resolution hours by resolution type (PERCENTILE_CONT is a window function)
SELECT DISTINCT resolution_type,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF(MINUTE, opened_at, closed_at) / 60.0)
           OVER (PARTITION BY resolution_type) AS median_hours
FROM raw.service_ticket
WHERE status = 'Closed';

-- P7. Telemetry sanity: physical limits
SELECT
    SUM(CASE WHEN run_hours IS NULL THEN 1 ELSE 0 END)        AS null_run_hours,
    SUM(CASE WHEN run_hours > planned_hours THEN 1 ELSE 0 END) AS run_gt_planned,
    SUM(CASE WHEN good_parts > total_parts THEN 1 ELSE 0 END)  AS good_gt_total
FROM raw.machine_daily_performance;
