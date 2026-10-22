/* =====================================================================
   06 - SQL PRACTICE: business questions a sales or service manager would ask.
   Try each one YOURSELF first; a reference answer is below each question
   inside a comment block. Topics: joins, GROUP BY, CTEs, window
   functions, date logic, performance (Skill: "high-performance SQL").
   ===================================================================== */
USE SalesServiceBI;
GO

-- Q1. Net revenue by order type and year. (GROUP BY, YEAR)
/*
SELECT YEAR(order_date) AS yr, order_type, SUM(net_amount_usd) AS revenue
FROM bi.fact_sales GROUP BY YEAR(order_date), order_type ORDER BY yr, revenue DESC;
*/

-- Q2. Top 10 customers by 2025 revenue, with their share of total. (window SUM OVER ())
/*
WITH c AS (
  SELECT customer_id, SUM(net_amount_usd) AS rev
  FROM bi.fact_sales WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01'
  GROUP BY customer_id)
SELECT TOP 10 d.customer_name, c.rev, 100.0 * c.rev / SUM(c.rev) OVER () AS pct_of_total
FROM c JOIN bi.dim_customer d ON d.customer_id = c.customer_id ORDER BY c.rev DESC;
*/

-- Q3. Month-over-month aftermarket (spare parts) revenue growth. (LAG)
/*
WITH m AS (
  SELECT DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS mth, SUM(net_amount_usd) AS rev
  FROM bi.fact_sales WHERE order_type = 'Aftermarket' GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1))
SELECT mth, rev, LAG(rev) OVER (ORDER BY mth) AS prev_rev,
       100.0 * (rev - LAG(rev) OVER (ORDER BY mth)) / NULLIF(LAG(rev) OVER (ORDER BY mth), 0) AS mom_pct
FROM m ORDER BY mth;
*/

-- Q4. OEE by monitoring tier. Does remote monitoring actually help? (the business story!)
--     OEE = Availability x Performance x Quality
--     Availability = run_hours / planned_hours
--     Performance  = total_parts / ideal_parts
--     Quality      = good_parts / total_parts
/*
SELECT m.monitoring_tier,
       SUM(f.run_hours) / SUM(f.planned_hours)                    AS availability,
       1.0 * SUM(f.total_parts) / SUM(f.ideal_parts)              AS performance,
       1.0 * SUM(f.good_parts)  / SUM(f.total_parts)              AS quality,
       (SUM(f.run_hours) / SUM(f.planned_hours))
     * (1.0 * SUM(f.total_parts) / SUM(f.ideal_parts))
     * (1.0 * SUM(f.good_parts)  / SUM(f.total_parts))            AS oee
FROM bi.fact_machine_daily f JOIN bi.dim_machine m ON m.machine_id = f.machine_id
GROUP BY m.monitoring_tier, m.monitoring_tier_rank ORDER BY m.monitoring_tier_rank;
*/

-- Q5. MTTR (mean time to repair) and % remote resolution, monitored vs not. (CASE + aggregates)
/*
SELECT m.is_monitored,
       AVG(t.resolution_hours) AS mttr_hours,
       100.0 * SUM(CASE WHEN t.resolution_type = 'Remote' THEN 1 ELSE 0 END) / COUNT(*) AS pct_remote
FROM bi.fact_service_ticket t JOIN bi.dim_machine m ON m.machine_id = t.machine_id
WHERE t.status = 'Closed' GROUP BY m.is_monitored;
*/

-- Q6. Upsell list: unmonitored machines with the most downtime in the last 12 months. (RANK)
/*
WITH d AS (
  SELECT t.machine_id, SUM(t.downtime_hours) AS downtime
  FROM bi.fact_service_ticket t WHERE t.opened_date >= DATEADD(MONTH, -12, '2026-09-30')
  GROUP BY t.machine_id)
SELECT TOP 20 RANK() OVER (ORDER BY d.downtime DESC) AS rnk, m.serial_number, c.customer_name,
       c.region_code, d.downtime
FROM d JOIN bi.dim_machine m ON m.machine_id = d.machine_id
JOIN bi.dim_customer c ON c.customer_id = m.customer_id
WHERE m.monitoring_tier = 'No Contract' ORDER BY rnk;
*/

-- Q7. Running total (YTD) revenue per region for 2026. (SUM OVER PARTITION ... ROWS)
/*
WITH m AS (
  SELECT c.region_code, DATEFROMPARTS(YEAR(f.order_date), MONTH(f.order_date), 1) AS mth, SUM(f.net_amount_usd) rev
  FROM bi.fact_sales f JOIN bi.dim_customer c ON c.customer_id = f.customer_id
  WHERE f.order_date >= '2026-01-01' GROUP BY c.region_code, DATEFROMPARTS(YEAR(f.order_date), MONTH(f.order_date), 1))
SELECT region_code, mth, rev,
       SUM(rev) OVER (PARTITION BY region_code ORDER BY mth ROWS UNBOUNDED PRECEDING) AS ytd_rev
FROM m ORDER BY region_code, mth;
*/

-- Q8. PERFORMANCE TUNING: turn on the actual execution plan (Ctrl+M in SSMS), run Q4,
--     then create this index and run again. Compare logical reads with SET STATISTICS IO ON.
/*
SET STATISTICS IO, TIME ON;
CREATE NONCLUSTERED INDEX IX_perf_machine_date
    ON raw.machine_daily_performance (machine_id, perf_date)
    INCLUDE (planned_hours, run_hours, ideal_rate_per_hour, total_parts, good_parts);
-- Then try a clustered columnstore index on the big table and compare again:
-- CREATE CLUSTERED COLUMNSTORE INDEX CCI_perf ON raw.machine_daily_performance;
-- Rule of thumb: "Row-store index for point lookups, columnstore for big aggregations."
*/
