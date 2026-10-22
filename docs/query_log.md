# Query log: what I ran, why, and what I found

Every query from the data-profiling and SQL-practice stages, re-run on 21 Oct
2026 so the results are exact. Each entry has four parts: **Why** I ran it, the
**query**, the **result** (as SSMS shows it, with row numbers on the left), and
**what it told me**.

Data: the SalesServiceBI database (synthetic, ERP-style). `raw.` tables are the
data as loaded, with its problems; `bi.` views are the cleaned version used for
reporting. Column meanings are in docs/data_dictionary.md.

## Index

```
+-----+-----------------------------------+------------------------------------+
| #   | Question                          | Short answer                       |
+=====+===================================+====================================+
| P1  | How big is each table, and what   | Sales and tickets: Jan 2024 to Sep |
|     | dates does it cover?              | 2026; telemetry from Jan 2025      |
+-----+-----------------------------------+------------------------------------+
| P2  | Which customer fields are empty?  | Only account_tier has gaps: 5      |
|     |                                   | customers (issue 1)                |
+-----+-----------------------------------+------------------------------------+
| P3  | Is every country written the same | 8 odd country names (issue 2)      |
|     | way?                              |                                    |
+-----+-----------------------------------+------------------------------------+
| P4  | Does any company appear twice?    | 6 companies entered twice (issue   |
|     |                                   | 3)                                 |
+-----+-----------------------------------+------------------------------------+
| P5  | Do the order line amounts make    | 7 lines with quantity 0 or less,   |
|     | sense?                            | negative amounts (issue 4)         |
+-----+-----------------------------------+------------------------------------+
| P6  | How long does a typical repair    | Remote 1.6 h vs technician visit   |
|     | take?                             | 20.6 h                             |
+-----+-----------------------------------+------------------------------------+
| P7  | Is any machine telemetry          | 45 impossible machine-days (issue  |
|     | physically impossible?            | 5)                                 |
+-----+-----------------------------------+------------------------------------+
| 2.1 | Show me the 8 badly written       | The 8 rows; 4 also sit in the      |
|     | countries                         | wrong region (2b)                  |
+-----+-----------------------------------+------------------------------------+
| 2.2 | What exactly differs between a    | The copy is in capitals and says   |
|     | duplicate pair?                   | LIMITED                            |
+-----+-----------------------------------+------------------------------------+
| 2.3 | Why are some order amounts        | Quantity -1 causes the negative    |
|     | negative?                         | amount; -$130,724                  |
+-----+-----------------------------------+------------------------------------+
| 2.4 | Does every order line point to a  | Product 999 doesn't exist; 13, 31, |
|     | real product?                     | 32 never sold                      |
+-----+-----------------------------------+------------------------------------+
| 2.5 | How many lines use product 999,   | 12 lines worth $258,988.72 (issue  |
|     | and how much money?               | 6)                                 |
+-----+-----------------------------------+------------------------------------+
| 2.6 | Does any ticket appear twice?     | 15 tickets appear twice (issue 7)  |
+-----+-----------------------------------+------------------------------------+
| 2.7 | Which tickets have no close time? | 54 open tickets: not an error      |
+-----+-----------------------------------+------------------------------------+
| 2.8 | Was any ticket closed before it   | 6 tickets, always 5 h early (issue |
|     | was opened?                       | 8)                                 |
+-----+-----------------------------------+------------------------------------+
| 3.1 | Do the automatic rules agree with | All 9 rules match my counts        |
|     | what I found?                     |                                    |
+-----+-----------------------------------+------------------------------------+
| Q1  | How much did we earn from each    | Aftermarket is biggest and grows   |
|     | type of sale, each year?          | about 7-8% a year                  |
+-----+-----------------------------------+------------------------------------+
| Q2a | Who were our 10 biggest customers | Horizon Polymers Ltd leads with    |
|     | in 2025?                          | $4.68 M                            |
+-----+-----------------------------------+------------------------------------+
| Q2b | What share of 2025 revenue does   | #1 brings 1.5%, top 10 bring 12%:  |
|     | each top customer bring?          | low risk                           |
+-----+-----------------------------------+------------------------------------+
| Q3  | Is spare-parts revenue growing    | Noisy month to month; trend +23%   |
|     | month by month?                   |                                    |
+-----+-----------------------------------+------------------------------------+
| Q4  | Do remotely monitored machines    | OEE rises from 77.4% (no contract) |
|     | run better (OEE)?                 | to 83.7% (Platinum)                |
+-----+-----------------------------------+------------------------------------+
| Q5  | Are monitored machines repaired   | Monitored: MTTR 7.1 h vs 19.5 h;   |
|     | faster, and more often remotely?  | 45% vs 10% remote                  |
+-----+-----------------------------------+------------------------------------+
| Q6  | Which unmonitored machines had    | Top unmonitored machine lost 261 h |
|     | the most downtime last year?      | (about 11 days)                    |
+-----+-----------------------------------+------------------------------------+
| Q7  | How is each region's 2026 revenue | Sep 2026 YTD: EU leads ($61.3 M),  |
|     | building up month by month?       | CNA lowest                         |
+-----+-----------------------------------+------------------------------------+
| Q8  | Which index makes queries on the  | Columnstore for aggregates,        |
|     | big telemetry table faster?       | row-store index for lookups        |
+-----+-----------------------------------+------------------------------------+
| C1  | Does the amount rule hold for     | Amount rule holds on all 30,775    |
|     | every order line?                 | lines                              |
+-----+-----------------------------------+------------------------------------+
| C2  | Are the duplicate tickets         | All 15 duplicate pairs are         |
|     | identical copies?                 | identical                          |
+-----+-----------------------------------+------------------------------------+
| C3  | Are the tickets with no close     | All 54 are Open, opened in the     |
|     | time really still open?           | last 10 days                       |
+-----+-----------------------------------+------------------------------------+
| C4  | Which products were never sold?   | 3 products never sold              |
+-----+-----------------------------------+------------------------------------+
| C5  | After cleaning, does any country  | 4 countries sat in two regions;    |
|     | sit in two regions?               | fixed (DQ09)                       |
+-----+-----------------------------------+------------------------------------+
| C6  | Why did one query take 29         | Waited 29 s for memory; the SQL    |
|     | seconds?                          | was fine                           |
+-----+-----------------------------------+------------------------------------+
```

---

## Part 1 · Data profiling: the sql/03 blocks

First look at the raw tables: size, gaps, spellings, duplicates and impossible
values.

### P1 · How big is each table, and what dates does it cover?

**Why:** Before analysing anything, know the volume and the time window of each
table.

```sql
SELECT 'sales_order' AS tbl, COUNT(*) AS rows,
       MIN(order_date) AS min_dt, MAX(order_date) AS max_dt
FROM raw.sales_order
UNION ALL
SELECT 'service_ticket', COUNT(*),
       MIN(CAST(opened_at AS DATE)), MAX(CAST(opened_at AS DATE))
FROM raw.service_ticket
UNION ALL
SELECT 'machine_daily_performance', COUNT(*),
       MIN(perf_date), MAX(perf_date)
FROM raw.machine_daily_performance;
```

**Result:**

```
+---+---------------------------+--------+------------+------------+
|   | tbl                       | rows   | min_dt     | max_dt     |
+===+===========================+========+============+============+
| 1 | sales_order               |  11337 | 2024-01-01 | 2026-09-30 |
+---+---------------------------+--------+------------+------------+
| 2 | service_ticket            |  10677 | 2024-01-01 | 2026-09-30 |
+---+---------------------------+--------+------------+------------+
| 3 | machine_daily_performance | 382639 | 2025-01-01 | 2026-09-30 |
+---+---------------------------+--------+------------+------------+
```

**What it told me:** Sales and tickets cover Jan 2024 to Sep 2026, but machine
telemetry only starts in Jan 2025, so OEE trends begin in 2025 with no prior
year to compare against. Row counts differ because each table has a different
grain (one order, one ticket, one machine-day).

### P2 · Which customer fields are empty?

**Why:** Completeness check on the customer master: % of NULLs in each important
column.

```sql
SELECT COUNT(*) AS total_rows,
  100.0 * SUM(CASE WHEN industry_segment IS NULL THEN 1 ELSE 0 END)
        / COUNT(*) AS pct_null_segment,
  100.0 * SUM(CASE WHEN account_tier IS NULL THEN 1 ELSE 0 END)
        / COUNT(*) AS pct_null_tier,
  100.0 * SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END)
        / COUNT(*) AS pct_null_country,
  100.0 * SUM(CASE WHEN region_code IS NULL THEN 1 ELSE 0 END)
        / COUNT(*) AS pct_null_region
FROM raw.dim_customer;
```

**Result:**

```
+---+------------+---------------+-------------+---------------+---------------+
|   | total_rows | pct_null_     | pct_null_   | pct_null_     | pct_null_     |
|   |            | segment       | tier        | country       | region        |
+===+============+===============+=============+===============+===============+
| 1 |        326 |          0.00 |        1.53 |          0.00 |          0.00 |
+---+------------+---------------+-------------+---------------+---------------+
```

**What it told me:** Only account_tier has gaps: 1.53% = 5 of 326 customers. A
report filtered by tier would silently miss them, so they should show as
"Unassigned" and go back to the data owner. (Issue 1)

### P3 · Is every country written the same way?

**Why:** List each country with its region and customer count, to spot odd
spellings.

```sql
SELECT country, region_code, COUNT(*) AS customers
FROM raw.dim_customer
GROUP BY country, region_code
ORDER BY region_code, country;
```

**Result:**

```
+----+----------------+-------------+-----------+
|    | country        | region_code | customers |
+====+================+=============+===========+
|  1 | China          | CNA         |        11 |
+----+----------------+-------------+-----------+
|  2 | Japan          | CNA         |        11 |
+----+----------------+-------------+-----------+
|  3 | South Korea    | CNA         |        18 |
+----+----------------+-------------+-----------+
|  4 | France         | EU          |        10 |
+----+----------------+-------------+-----------+
|  5 | Germany        | EU          |         9 |
+----+----------------+-------------+-----------+
|  6 | Italy          | EU          |        10 |
+----+----------------+-------------+-----------+
|  7 | Poland         | EU          |        10 |
+----+----------------+-------------+-----------+
|  8 | Spain          | EU          |         6 |
+----+----------------+-------------+-----------+
|  9 | UK             | EU          |         1 |
+----+----------------+-------------+-----------+
| 10 | United Kingdom | EU          |        16 |
+----+----------------+-------------+-----------+
```

Showing the first 10 of 37 rows.

**What it told me:** Rows with only 1 customer stand out (UK, Viet Nam,
Deutschland, KSA, india, U.S.A., UAE, USA): 8 non-standard country names. Query
2.1 lists them all. (Issue 2)

### P4 · Does any company appear twice?

**Why:** Uniqueness check: group customers by a normalised name (capitals,
LIMITED -> LTD) so differently typed copies land in the same group.

```sql
SELECT UPPER(REPLACE(customer_name, 'LIMITED', 'LTD'))
           AS normalised_name,
       COUNT(*) AS records,
       STRING_AGG(customer_number, ', ') AS customer_numbers
FROM raw.dim_customer
GROUP BY UPPER(REPLACE(customer_name, 'LIMITED', 'LTD'))
HAVING COUNT(*) > 1;
```

**Result:**

```
+---+-----------------------+---------+------------------+
|   | normalised_name       | records | customer_numbers |
+===+=======================+=========+==================+
| 1 | BLUE PACKAGING LLC    |       2 | C100081, C900002 |
+---+-----------------------+---------+------------------+
| 2 | HORIZON FOODS PVT LTD |       2 | C100124, C900000 |
+---+-----------------------+---------+------------------+
| 3 | JADE MEDTECH CO.      |       2 | C100133, C900004 |
+---+-----------------------+---------+------------------+
| 4 | MERIDIAN BOTTLING LTD |       2 | C100248, C900005 |
+---+-----------------------+---------+------------------+
| 5 | ORION FOODS S.A.      |       2 | C900001, C100111 |
+---+-----------------------+---------+------------------+
| 6 | SUMMIT MEDTECH SPA    |       2 | C900003, C100132 |
+---+-----------------------+---------+------------------+
```

**What it told me:** 6 companies exist twice: a normal C100... record plus a
C900... copy. Their revenue is split across two records, so they can drop out of
a Top 10 list. Fix: map each copy to one golden record (bi.customer_master_map).
(Issue 3)

### P5 · Do the order line amounts make sense?

**Why:** Smallest, average and largest line amount per order type, plus a count
of quantities of 0 or less.

```sql
SELECT o.order_type,
       COUNT(*) AS lines,
       MIN(l.net_amount_usd) AS min_amt,
       AVG(l.net_amount_usd) AS avg_amt,
       MAX(l.net_amount_usd) AS max_amt,
       SUM(CASE WHEN l.quantity <= 0 THEN 1 ELSE 0 END)
           AS non_positive_qty
FROM raw.sales_order_line l
JOIN raw.sales_order o ON o.order_id = l.order_id
GROUP BY o.order_type;
```

**Result:**

```
+---+-------------+-------+-----------+------------+------------+--------------+
|   | order_type  | lines | min_amt   | avg_amt    | max_amt    | non_         |
|   |             |       |           |            |            | positive_qty |
+===+=============+=======+===========+============+============+==============+
| 1 | Aftermarket | 27239 |  -3199.40 |   16877.88 |  257964.00 |            5 |
+---+-------------+-------+-----------+------------+------------+--------------+
| 2 | HotRunner   |  2238 | -62016.00 |   92592.37 |  220000.00 |            2 |
+---+-------------+-------+-----------+------------+------------+--------------+
| 3 | Service     |  1077 |  16200.00 |   36313.59 |   72000.00 |            0 |
+---+-------------+-------+-----------+------------+------------+--------------+
| 4 | Capital     |   221 | 255440.00 | 1056602.26 | 2191900.00 |            0 |
+---+-------------+-------+-----------+------------+------------+--------------+
```

**What it told me:** Sanity check passes for averages (a machine line averages
about $1 M, a service line about $36 K). But Aftermarket and HotRunner have
negative minimums and 7 lines with quantity 0 or less. Query 2.3 zooms in.
(Issue 4)

### P6 · How long does a typical repair take?

**Why:** Median (middle value) hours from opened to closed, per way of fixing
it. Median, not average, so a few very long tickets don't distort it.

```sql
SELECT DISTINCT resolution_type,
       PERCENTILE_CONT(0.5) WITHIN GROUP (
           ORDER BY DATEDIFF(MINUTE, opened_at, closed_at) / 60.0)
           OVER (PARTITION BY resolution_type) AS median_hours
FROM raw.service_ticket
WHERE status = 'Closed';
```

**Result:**

```
+---+------------------+--------------+
|   | resolution_type  | median_hours |
+===+==================+==============+
| 1 | Remote           |         1.63 |
+---+------------------+--------------+
| 2 | Phone Support    |         4.00 |
+---+------------------+--------------+
| 3 | Technician Visit |        20.61 |
+---+------------------+--------------+
```

**What it told me:** Remote 1.6 h, Phone 4 h, Technician visit 20.6 h. Every
ticket fixed remotely instead of on site saves about 19 hours, which supports
selling remote-monitoring contracts. Not an error: a business insight.

### P7 · Is any machine telemetry physically impossible?

**Why:** Count machine-days that break physical limits.

```sql
SELECT
  SUM(CASE WHEN run_hours IS NULL THEN 1 ELSE 0 END)
      AS null_run_hours,
  SUM(CASE WHEN run_hours > planned_hours THEN 1 ELSE 0 END)
      AS run_gt_planned,
  SUM(CASE WHEN good_parts > total_parts THEN 1 ELSE 0 END)
      AS good_gt_total
FROM raw.machine_daily_performance;
```

**Result:**

```
+---+----------------+----------------+---------------+
|   | null_run_hours | run_gt_planned | good_gt_total |
+===+================+================+===============+
| 1 |             25 |              0 |            20 |
+---+----------------+----------------+---------------+
```

**What it told me:** 45 bad machine-days: 25 with no run hours (Availability
drops) and 20 with more good parts than total parts (Quality above 100%, so OEE
looks too good). Excluded from OEE in bi.fact_machine_daily: 382,639 - 45 =
382,594 rows. (Issue 5)

---

## Part 2 · My own follow-up queries

Zooming in on what the 03 blocks hinted at, and finding the 3 issues 03 doesn't
cover.

### 2.1 · Show me the 8 badly written countries

**Why:** P3 hinted at odd country names; pull exactly those rows. COLLATE ...
CS_AS makes the comparison case-sensitive, because SQL Server normally treats
'india' = 'India'.

```sql
SELECT customer_number, customer_name, country, region_code
FROM raw.dim_customer
WHERE country COLLATE Latin1_General_CS_AS
      IN ('india', 'Viet Nam', 'USA', 'U.S.A.',
          'UK', 'UAE', 'KSA', 'Deutschland');
```

**Result:**

```
+---+-----------------+----------------------------+-------------+-------------+
|   | customer_number | customer_name              | country     | region_code |
+===+=================+============================+=============+=============+
| 1 | C100008         | Evergreen Polymers LLC     | UAE         | NA          |
+---+-----------------+----------------------------+-------------+-------------+
| 2 | C100066         | Blue Pack Solutions Inc    | UK          | EU          |
+---+-----------------+----------------------------+-------------+-------------+
| 3 | C100128         | Evergreen Polymers Co.     | Deutschland | IND         |
+---+-----------------+----------------------------+-------------+-------------+
| 4 | C100191         | Jade Healthcare Pvt Ltd    | KSA         | MEA         |
+---+-----------------+----------------------------+-------------+-------------+
| 5 | C100257         | Falcon Bottling SpA        | Viet Nam    | EU          |
+---+-----------------+----------------------------+-------------+-------------+
| 6 | C100311         | Kestrel Pack Solutions Inc | india       | NA          |
+---+-----------------+----------------------------+-------------+-------------+
| 7 | C100316         | Jade Packaging S.A.        | U.S.A.      | NA          |
+---+-----------------+----------------------------+-------------+-------------+
| 8 | C100320         | Horizon Industries PLC     | USA         | NA          |
+---+-----------------+----------------------------+-------------+-------------+
```

**What it told me:** Exactly 8 rows = all found. Two kinds: 4 are just written
differently (UK, KSA, USA, U.S.A.), and 4 also sit in the wrong region (UAE in
NA, Deutschland in IND, Viet Nam in EU, india in NA). The wrong regions would
put customers in front of the wrong regional manager. (Issues 2 and 2b)

### 2.2 · What exactly differs between a duplicate pair?

**Why:** P4 found duplicates; compare one pair letter by letter (Horizon Foods).

```sql
SELECT customer_number, customer_name, country, region_code
FROM raw.dim_customer
WHERE customer_number IN ('C100124', 'C900000');
```

**Result:**

```
+---+----------------+---------------------------+---------------+-------------+
|   | customer_      | customer_name             | country       | region_code |
|   | number         |                           |               |             |
+===+================+===========================+===============+=============+
| 1 | C100124        | Horizon Foods Pvt Ltd     | United States | NA          |
+---+----------------+---------------------------+---------------+-------------+
| 2 | C900000        | HORIZON FOODS PVT LIMITED | United States | NA          |
+---+----------------+---------------------------+---------------+-------------+
```

**What it told me:** Same company, two differences: the copy is ALL CAPITALS and
says LIMITED instead of Ltd. That's why P4 normalises the name before grouping.
Keep C100124 as the golden record (normal number series, typed properly, lowest
ID).

### 2.3 · Why are some order amounts negative?

**Why:** Zoom in on the lines with quantity 0 or less, and test the amount rule:
quantity x price x (1 - discount).

```sql
SELECT product_id, quantity, unit_list_price_usd,
       discount_pct, net_amount_usd,
       quantity * unit_list_price_usd
         * (1 - discount_pct) AS my_calc
FROM raw.sales_order_line
WHERE quantity <= 0;
```

**Result:**

```
+---+-----------+----------+-----------+-------------+-------------+-----------+
|   | product_  | quantity | unit_     | discount_   | net_amount_ | my_calc   |
|   | id        |          | list_     | pct         | usd         |           |
|   |           |          | price_usd |             |             |           |
+===+===========+==========+===========+=============+=============+===========+
| 1 |        16 |       -1 |  64000.00 |       0.033 |   -61888.00 | -61888.00 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
| 2 |        16 |       -1 |  64000.00 |       0.031 |   -62016.00 | -62016.00 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
| 3 |        25 |       -1 |   3400.00 |       0.059 |    -3199.40 |  -3199.40 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
| 4 |        20 |       -1 |   1200.00 |       0.019 |    -1177.20 |  -1177.20 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
| 5 |        24 |       -1 |    620.00 |       0.028 |     -602.64 |   -602.64 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
| 6 |        20 |       -1 |   1200.00 |       0.076 |    -1108.80 |  -1108.80 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
| 7 |        23 |       -1 |    780.00 |       0.062 |     -731.64 |   -731.64 |
+---+-----------+----------+-----------+-------------+-------------+-----------+
```

**What it told me:** All 7 lines have quantity -1, and my_calc equals
net_amount_usd on every row, so the bad quantity causes the negative amount: one
problem seen twice. Total -$130,724, so revenue is understated. Ask finance
whether these are errors or real returns before removing them. (Issue 4)

### 2.4 · Does every order line point to a real product?

**Why:** dim_product holds products 1 to 32. List every different product_id
used on order lines and look for anything outside that range.

```sql
SELECT DISTINCT product_id
FROM raw.sales_order_line
ORDER BY product_id;
```

**Result:**

```
+--------------------------------------------------------------+
| product_id values returned (30 rows)                         |
+==============================================================+
| 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 16, 17, 18,   |
| 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 999          |
+--------------------------------------------------------------+
```

**What it told me:** 999 appears, but no product 999 exists: "orphan" lines.
Also 13, 31 and 32 are missing: products never sold (see C4). (Issue 6)

### 2.5 · How many lines use product 999, and how much money?

**Why:** Size the problem found in 2.4: count the lines and add up their value.

```sql
SELECT COUNT(*) AS lines, SUM(net_amount_usd) AS revenue
FROM raw.sales_order_line
WHERE product_id = 999;
```

**Result:**

```
+---+-------+-----------+
|   | lines | revenue   |
+===+=======+===========+
| 1 |    12 | 258988.72 |
+---+-------+-----------+
```

**What it told me:** 12 lines worth $258,988.72 have no product. A
revenue-by-product chart shows them as (Blank) or loses them from the total.
(Issue 6)

### 2.6 · Does any ticket appear twice?

**Why:** Uniqueness check on tickets, using the same GROUP BY + HAVING pattern
as P4.

```sql
SELECT ticket_id, COUNT(*) AS copies
FROM raw.service_ticket
GROUP BY ticket_id
HAVING COUNT(*) > 1
ORDER BY ticket_id;
```

**Result:**

```
+----+-----------+--------+
|    | ticket_id | copies |
+====+===========+========+
|  1 |       399 |      2 |
+----+-----------+--------+
|  2 |       520 |      2 |
+----+-----------+--------+
|  3 |      1068 |      2 |
+----+-----------+--------+
|  4 |      1803 |      2 |
+----+-----------+--------+
|  5 |      2147 |      2 |
+----+-----------+--------+
|  6 |      3212 |      2 |
+----+-----------+--------+
|  7 |      3933 |      2 |
+----+-----------+--------+
|  8 |      5183 |      2 |
+----+-----------+--------+
|  9 |      5190 |      2 |
+----+-----------+--------+
| 10 |      5982 |      2 |
+----+-----------+--------+
| 11 |      6060 |      2 |
+----+-----------+--------+
| 12 |      6504 |      2 |
+----+-----------+--------+
| 13 |      7891 |      2 |
+----+-----------+--------+
| 14 |      9094 |      2 |
+----+-----------+--------+
| 15 |     10607 |      2 |
+----+-----------+--------+
```

**What it told me:** 15 tickets appear twice, so the ticket count is 15 too high
(10,677 rows vs 10,662 real tickets), a 0.1% overcount, and those tickets count
double in the average repair time. C2 shows the copies are identical, so keep
one of each. (Issue 7)

### 2.7 · Which tickets have no close time?

**Why:** Check whether empty closed_at values are errors.

```sql
SELECT ticket_id, opened_at, closed_at
FROM raw.service_ticket
WHERE closed_at IS NULL
ORDER BY ticket_id;
```

**Result:**

```
+----+-----------+---------------------+-----------+
|    | ticket_id | opened_at           | closed_at |
+====+===========+=====================+===========+
|  1 |       148 | 2026-09-28 13:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  2 |       269 | 2026-09-26 21:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  3 |       444 | 2026-09-24 11:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  4 |       517 | 2026-09-24 06:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  5 |       735 | 2026-09-23 10:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  6 |       738 | 2026-09-21 06:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  7 |       846 | 2026-09-21 10:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  8 |       853 | 2026-09-28 01:00:00 | NULL      |
+----+-----------+---------------------+-----------+
|  9 |       949 | 2026-09-23 04:00:00 | NULL      |
+----+-----------+---------------------+-----------+
| 10 |      2076 | 2026-09-25 14:00:00 | NULL      |
+----+-----------+---------------------+-----------+
```

Showing the first 10 of 54 rows.

**What it told me:** 54 tickets. Not an error: all 54 are status Open and were
opened in the last 10 days of the data (see C3). NULL here means "not happened
yet". They stay out of MTTR and belong on an "open tickets" count.

### 2.8 · Was any ticket closed before it was opened?

**Why:** Common sense: closed_at must be later than opened_at.

```sql
SELECT ticket_id, opened_at, closed_at
FROM raw.service_ticket
WHERE closed_at < opened_at;
```

**Result:**

```
+---+-----------+---------------------+---------------------+
|   | ticket_id | opened_at           | closed_at           |
+===+===========+=====================+=====================+
| 1 |        68 | 2024-06-09 19:00:00 | 2024-06-09 14:00:00 |
+---+-----------+---------------------+---------------------+
| 2 |       273 | 2025-06-02 14:00:00 | 2025-06-02 09:00:00 |
+---+-----------+---------------------+---------------------+
| 3 |      5083 | 2025-07-18 14:00:00 | 2025-07-18 09:00:00 |
+---+-----------+---------------------+---------------------+
| 4 |      7508 | 2024-05-30 09:00:00 | 2024-05-30 04:00:00 |
+---+-----------+---------------------+---------------------+
| 5 |      7670 | 2025-07-09 18:00:00 | 2025-07-09 13:00:00 |
+---+-----------+---------------------+---------------------+
| 6 |      7878 | 2024-12-25 15:00:00 | 2024-12-25 10:00:00 |
+---+-----------+---------------------+---------------------+
```

**What it told me:** 6 tickets, each closed exactly 5 hours before opening. The
same gap every time points to a system cause (likely a time-zone mix-up), not
typos. Negative repair times pull MTTR down, so the service team looks faster
than it is. (Issue 8)

---

## Part 3 · Checking my findings against sql/04

The automatic data-quality rules, compared with what I found by hand.

### 3.1 · Do the automatic rules agree with what I found?

**Why:** sql/04 turns each finding into a repeatable data-quality rule. Run it
and compare the counts with my own.

```sql
SELECT rule_id, dq_dimension, rule_desc, failed_rows,
       total_rows,
       CAST(100.0 * (total_rows - failed_rows)
            / NULLIF(total_rows, 0) AS DECIMAL(6,2))
           AS pass_rate_pct
FROM bi.vw_data_quality_results
ORDER BY rule_id;
```

**Result:**

```
+---+-------+-------------------+-------------------+---------+--------+-------+
|   | rule_ | dq_dimension      | rule_desc         | failed_ | total_ | pass_ |
|   | id    |                   |                   | rows    | rows   | rate_ |
|   |       |                   |                   |         |        | pct   |
+===+=======+===================+===================+=========+========+=======+
| 1 | DQ01  | Uniqueness        | Duplicate         |       6 |    326 | 98.16 |
|   |       |                   | customer (same    |         |        |       |
|   |       |                   | normalised name)  |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 2 | DQ02  | Validity          | Country not in    |       8 |    326 | 97.55 |
|   |       |                   | approved list     |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 3 | DQ03  | Completeness      | Missing account   |       5 |    326 | 98.47 |
|   |       |                   | tier              |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 4 | DQ04  | Referential       | Product not in    |      12 |  30775 | 99.96 |
|   |       | integrity         | product master    |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 5 | DQ05  | Validity          | Quantity <= 0     |       7 |  30775 | 99.98 |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 6 | DQ06  | Uniqueness        | Duplicate         |      15 |  10677 | 99.86 |
|   |       |                   | ticket_id rows    |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 7 | DQ07  | Consistency       | Closed before     |       6 |  10677 | 99.94 |
|   |       |                   | opened            |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 8 | DQ08  | Validity          | good_parts >      |      45 | 382639 | 99.99 |
|   |       |                   | total_parts or    |         |        |       |
|   |       |                   | null run_hours    |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
| 9 | DQ09  | Consistency       | Region does not   |       4 |    326 | 98.77 |
|   |       |                   | match the country |         |        |       |
+---+-------+-------------------+-------------------+---------+--------+-------+
```

**What it told me:** All 9 rules match my counts. DQ09 (region does not match
the country) was added after my profiling found issue 2b. Lesson: pass rates
hide impact. DQ04 passes at 99.96%, yet $258,989 of revenue has no product.
Report the business impact, not just the percentage.

---

## Part 4 · SQL practice: business questions (sql/06)

Questions a sales or service manager would ask, answered from the clean bi
views.

### Q1 · How much did we earn from each type of sale, each year?

**Why:** Revenue trend by order type. Uses the clean bi.fact_sales view (already
joined and cleaned), so no JOIN is needed.

```sql
SELECT YEAR(order_date) AS yr,
       order_type,
       SUM(net_amount_usd) AS revenue
FROM bi.fact_sales
GROUP BY YEAR(order_date), order_type
ORDER BY yr, revenue DESC;
```

**Result:**

```
+----+------+-------------+--------------+
|    | yr   | order_type  | revenue      |
+====+======+=============+==============+
|  1 | 2024 | Aftermarket | 153284323.33 |
+----+------+-------------+--------------+
|  2 | 2024 | Capital     |  96496370.00 |
+----+------+-------------+--------------+
|  3 | 2024 | HotRunner   |  78605716.00 |
+----+------+-------------+--------------+
|  4 | 2024 | Service     |  12088354.00 |
+----+------+-------------+--------------+
|  5 | 2025 | Aftermarket | 164476698.12 |
+----+------+-------------+--------------+
|  6 | 2025 | HotRunner   |  69498844.00 |
+----+------+-------------+--------------+
|  7 | 2025 | Capital     |  60948570.00 |
+----+------+-------------+--------------+
|  8 | 2025 | Service     |  13217426.00 |
+----+------+-------------+--------------+
|  9 | 2026 | Aftermarket | 132698630.33 |
+----+------+-------------+--------------+
| 10 | 2026 | Capital     |  76064160.00 |
+----+------+-------------+--------------+
| 11 | 2026 | HotRunner   |  53930644.00 |
+----+------+-------------+--------------+
| 12 | 2026 | Service     |  13083790.00 |
+----+------+-------------+--------------+
```

**What it told me:** Aftermarket (spare parts) earns the most every year and
grows about 7-8% a year ($153.3 M, $164.5 M, then $132.7 M in 9 months of 2026,
on pace for about $177 M). Capital (machines) is lumpy. Steady recurring revenue
is why lifecycle services matter to a machinery maker.

### Q2a · Who were our 10 biggest customers in 2025?

**Why:** Filter to 2025 with WHERE, total per customer, sort biggest first, keep
the top 10. JOIN dim_customer to show names instead of IDs. The date range (not
YEAR() in WHERE) keeps the query able to use an index.

```sql
SELECT TOP 10 c.customer_name,
       c.region_code,
       SUM(f.net_amount_usd) AS revenue
FROM bi.fact_sales f
JOIN bi.dim_customer c ON c.customer_id = f.customer_id
WHERE f.order_date >= '2025-01-01'
  AND f.order_date < '2026-01-01'
GROUP BY c.customer_name, c.region_code
ORDER BY revenue DESC;
```

**Result:**

```
+----+----------------------------+-------------+------------+
|    | customer_name              | region_code | revenue    |
+====+============================+=============+============+
|  1 | Horizon Polymers Ltd       | MEA         | 4680762.33 |
+----+----------------------------+-------------+------------+
|  2 | Meridian MedTech SpA       | IND         | 4538196.52 |
+----+----------------------------+-------------+------------+
|  3 | Nova Foods LLC             | NA          | 4294472.37 |
+----+----------------------------+-------------+------------+
|  4 | Zenith MedTech GmbH        | LATAM       | 3812522.33 |
+----+----------------------------+-------------+------------+
|  5 | Crystal Containers LLC     | IND         | 3594379.97 |
+----+----------------------------+-------------+------------+
|  6 | Crystal Healthcare Pvt Ltd | EU          | 3584887.75 |
+----+----------------------------+-------------+------------+
|  7 | Horizon Healthcare Inc     | EU          | 3134354.97 |
+----+----------------------------+-------------+------------+
|  8 | Horizon Containers GmbH    | CNA         | 3107087.58 |
+----+----------------------------+-------------+------------+
|  9 | Indus Polymers Inc         | MEA         | 3050355.71 |
+----+----------------------------+-------------+------------+
| 10 | Summit Industries S.A.     | LATAM       | 3020036.16 |
+----+----------------------------+-------------+------------+
```

**What it told me:** Horizon Polymers Ltd (MEA) leads with $4.68 M. The top 10
are spread across 6 of the 7 regions; only SEA has none.

### Q2b · What share of 2025 revenue does each top customer bring?

**Why:** Customer-concentration risk. A CTE first totals every customer; then
SUM(...) OVER () puts the grand total on every row, so each customer's % can be
worked out.

```sql
WITH cust AS (
    SELECT f.customer_id, SUM(f.net_amount_usd) AS revenue
    FROM bi.fact_sales f
    WHERE f.order_date >= '2025-01-01'
      AND f.order_date < '2026-01-01'
    GROUP BY f.customer_id
)
SELECT TOP 10 c.customer_name,
       cust.revenue,
       100.0 * cust.revenue / SUM(cust.revenue) OVER ()
           AS pct_of_total
FROM cust
JOIN bi.dim_customer c ON c.customer_id = cust.customer_id
ORDER BY cust.revenue DESC;
```

**Result:**

```
+----+----------------------------+------------+--------------+
|    | customer_name              | revenue    | pct_of_total |
+====+============================+============+==============+
|  1 | Horizon Polymers Ltd       | 4680762.33 |         1.52 |
+----+----------------------------+------------+--------------+
|  2 | Meridian MedTech SpA       | 4538196.52 |         1.47 |
+----+----------------------------+------------+--------------+
|  3 | Nova Foods LLC             | 4294472.37 |         1.39 |
+----+----------------------------+------------+--------------+
|  4 | Zenith MedTech GmbH        | 3812522.33 |         1.24 |
+----+----------------------------+------------+--------------+
|  5 | Crystal Containers LLC     | 3594379.97 |         1.17 |
+----+----------------------------+------------+--------------+
|  6 | Crystal Healthcare Pvt Ltd | 3584887.75 |         1.16 |
+----+----------------------------+------------+--------------+
|  7 | Horizon Healthcare Inc     | 3134354.97 |         1.02 |
+----+----------------------------+------------+--------------+
|  8 | Horizon Containers GmbH    | 3107087.58 |         1.01 |
+----+----------------------------+------------+--------------+
|  9 | Indus Polymers Inc         | 3050355.71 |         0.99 |
+----+----------------------------+------------+--------------+
| 10 | Summit Industries S.A.     | 3020036.16 |         0.98 |
+----+----------------------------+------------+--------------+
```

**What it told me:** The #1 customer brings 1.5% of 2025 revenue ($308.1 M in
total); the top 10 together bring 12%. Revenue is spread out, so concentration
risk is low. (Real B2B companies are often closer to 80/20; this even spread
comes from the synthetic data.)

### Q3 · Is spare-parts revenue growing month by month?

**Why:** Monthly Aftermarket revenue, with LAG() bringing last month's value
onto each row to work out the % change.

```sql
WITH m AS (
  SELECT DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
             AS mth,
         SUM(net_amount_usd) AS rev
  FROM bi.fact_sales
  WHERE order_type = 'Aftermarket'
  GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
)
SELECT mth, rev,
       LAG(rev) OVER (ORDER BY mth) AS prev_rev,
       100.0 * (rev - LAG(rev) OVER (ORDER BY mth))
         / NULLIF(LAG(rev) OVER (ORDER BY mth), 0) AS mom_pct
FROM m
ORDER BY mth;
```

**Result:**

```
+----+------------+-------------+-------------+---------+
|    | mth        | rev         | prev_rev    | mom_pct |
+====+============+=============+=============+=========+
|  1 | 2024-01-01 | 13066179.67 |        NULL |    NULL |
+----+------------+-------------+-------------+---------+
|  2 | 2024-02-01 | 11964044.21 | 13066179.67 |   -8.44 |
+----+------------+-------------+-------------+---------+
|  3 | 2024-03-01 | 10982532.30 | 11964044.21 |   -8.20 |
+----+------------+-------------+-------------+---------+
|  4 | 2024-04-01 | 13333613.90 | 10982532.30 |   21.41 |
+----+------------+-------------+-------------+---------+
|  5 | 2024-05-01 | 11642873.94 | 13333613.90 |  -12.68 |
+----+------------+-------------+-------------+---------+
|  6 | 2024-06-01 | 13373082.57 | 11642873.94 |   14.86 |
+----+------------+-------------+-------------+---------+
|  7 | 2024-07-01 | 12918317.82 | 13373082.57 |   -3.40 |
+----+------------+-------------+-------------+---------+
|  8 | 2024-08-01 | 14316521.04 | 12918317.82 |   10.82 |
+----+------------+-------------+-------------+---------+
|  9 | 2024-09-01 | 13551994.34 | 14316521.04 |   -5.34 |
+----+------------+-------------+-------------+---------+
| 10 | 2024-10-01 | 13686077.20 | 13551994.34 |    0.99 |
+----+------------+-------------+-------------+---------+
```

Showing the first 10 of 33 rows.

**What it told me:** Month to month it's noisy: 17 months up, 15 down, swings
from -27% to +28%. The trend is clearly up: an average month rose from $12.4 M
(first half of 2024) to $15.3 M (Apr-Sep 2026), +23%. Lesson: judge a trend with
year-over-year or a rolling average, not single months.

### Q4 · Do remotely monitored machines run better (OEE)?

**Why:** The core business story: compare OEE (Availability x Performance x
Quality) across monitoring tiers. Sum first, then divide, so big and small
machines are weighted correctly.

```sql
SELECT m.monitoring_tier,
       SUM(f.run_hours) / SUM(f.planned_hours) AS availability,
       1.0 * SUM(f.total_parts) / SUM(f.ideal_parts)
           AS performance,
       1.0 * SUM(f.good_parts) / SUM(f.total_parts) AS quality,
       (SUM(f.run_hours) / SUM(f.planned_hours))
     * (1.0 * SUM(f.total_parts) / SUM(f.ideal_parts))
     * (1.0 * SUM(f.good_parts) / SUM(f.total_parts)) AS oee
FROM bi.fact_machine_daily f
JOIN bi.dim_machine m ON m.machine_id = f.machine_id
GROUP BY m.monitoring_tier, m.monitoring_tier_rank
ORDER BY m.monitoring_tier_rank;
```

**Result:**

```
+---+-----------------+--------------+-------------+---------+------+
|   | monitoring_tier | availability | performance | quality | oee  |
+===+=================+==============+=============+=========+======+
| 1 | No Contract     |         0.87 |        0.90 |    0.99 | 0.77 |
+---+-----------------+--------------+-------------+---------+------+
| 2 | Bronze          |         0.88 |        0.91 |    0.98 | 0.79 |
+---+-----------------+--------------+-------------+---------+------+
| 3 | Silver          |         0.88 |        0.92 |    0.99 | 0.79 |
+---+-----------------+--------------+-------------+---------+------+
| 4 | Gold            |         0.90 |        0.92 |    0.99 | 0.81 |
+---+-----------------+--------------+-------------+---------+------+
| 5 | Platinum        |         0.91 |        0.93 |    0.99 | 0.84 |
+---+-----------------+--------------+-------------+---------+------+
```

**What it told me:** OEE rises with the tier: 77.4% with no contract, 79.0%
Bronze, 79.2% Silver, 81.3% Gold, 83.7% Platinum (+6.3 points). The gain comes
from Availability (86.8% to 91.4%) and Performance (90.5% to 93.0%); Quality is
flat (about 98.6%). Monitoring catches problems early, so machines stop less and
run faster: an argument for upselling higher tiers. (Correlation, not proof of
cause: better-run plants may also buy higher tiers.)

### Q5 · Are monitored machines repaired faster, and more often remotely?

**Why:** Service side of the remote-monitoring story: MTTR (average repair
hours) and % of tickets fixed remotely, monitored vs not. Closed tickets only,
because open ones have no repair time yet.

```sql
SELECT m.is_monitored,
       COUNT(*) AS tickets,
       AVG(t.resolution_hours) AS mttr_hours,
       100.0 * SUM(CASE WHEN t.resolution_type = 'Remote'
                        THEN 1 ELSE 0 END) / COUNT(*) AS pct_remote
FROM bi.fact_service_ticket t
JOIN bi.dim_machine m ON m.machine_id = t.machine_id
WHERE t.status = 'Closed'
GROUP BY m.is_monitored;
```

**Result:**

```
+---+---------------+---------+------------+------------+
|   | is_monitored  | tickets | mttr_hours | pct_remote |
+===+===============+=========+============+============+
| 1 | Monitored     |    5845 |       7.11 |      45.00 |
+---+---------------+---------+------------+------------+
| 2 | Not Monitored |    4763 |      19.51 |       9.55 |
+---+---------------+---------+------------+------------+
```

**What it told me:** Monitored machines are repaired in 7.1 h on average vs 19.5
h without monitoring (64% faster), and 45% of their tickets are fixed remotely
vs under 10%. They also raise fewer tickets per machine: 5,845 tickets over 403
machines (14.5 each) vs 4,763 over 234 (20.4 each). Faster, cheaper fixes and
less downtime: the service half of the remote-monitoring story.

### Q6 · Which unmonitored machines had the most downtime last year?

**Why:** An upsell list for sales: machines with no monitoring contract, ranked
by downtime hours from tickets in the last 12 months of data. RANK() numbers
them 1, 2, 3 ...

```sql
WITH d AS (
  SELECT t.machine_id, SUM(t.downtime_hours) AS downtime
  FROM bi.fact_service_ticket t
  WHERE t.opened_date >= DATEADD(MONTH, -12, '2026-09-30')
  GROUP BY t.machine_id
)
SELECT TOP 20
       RANK() OVER (ORDER BY d.downtime DESC) AS rnk,
       m.serial_number, c.customer_name, c.region_code,
       d.downtime
FROM d
JOIN bi.dim_machine m ON m.machine_id = d.machine_id
JOIN bi.dim_customer c ON c.customer_id = m.customer_id
WHERE m.monitoring_tier = 'No Contract'
ORDER BY rnk;
```

**Result:**

```
+----+-----+---------------+------------------------+-------------+----------+
|    | rnk | serial_number | customer_name          | region_code | downtime |
+====+=====+===============+========================+=============+==========+
|  1 |   1 | MCH-4500435   | Crystal Containers LLC | IND         |   261.42 |
+----+-----+---------------+------------------------+-------------+----------+
|  2 |   2 | MCH-8100260   | Horizon Foods Pvt Ltd  | NA          |   257.53 |
+----+-----+---------------+------------------------+-------------+----------+
|  3 |   3 | MCH-9400579   | Meridian MedTech Inc   | LATAM       |   230.59 |
+----+-----+---------------+------------------------+-------------+----------+
|  4 |   4 | MCH-3300524   | Falcon Bottling SpA    | SEA         |   229.78 |
+----+-----+---------------+------------------------+-------------+----------+
|  5 |   5 | MCH-9000015   | Terra Bottling Ltd     | MEA         |   214.38 |
+----+-----+---------------+------------------------+-------------+----------+
|  6 |   6 | MCH-7500415   | Crystal Packaging GmbH | MEA         |   208.96 |
+----+-----+---------------+------------------------+-------------+----------+
|  7 |   7 | MCH-1900561   | Blue Closures S.A.     | EU          |   197.97 |
+----+-----+---------------+------------------------+-------------+----------+
|  8 |   8 | MCH-5800327   | Lotus Plastics Inc     | CNA         |   195.95 |
+----+-----+---------------+------------------------+-------------+----------+
|  9 |   9 | MCH-9200367   | Willow Containers SpA  | EU          |   191.35 |
+----+-----+---------------+------------------------+-------------+----------+
| 10 |  10 | MCH-3900438   | Kestrel MedTech SpA    | CNA         |   182.58 |
+----+-----+---------------+------------------------+-------------+----------+
```

Showing the first 10 of 20 rows.

**What it told me:** A ready-made call list: the top machine (Crystal Containers
LLC, IND) was down 261 hours in a year, about 11 days, and all 20 are above 155
hours, spread across every region. For scale, an unmonitored machine averaged 87
downtime hours in that year vs 23 for a monitored one (a separate check). Sales
pitch per customer: "your machine lost about 11 days; monitored machines lose
about 1." RANK gives tied values the same number; ROW_NUMBER would not.

### Q7 · How is each region's 2026 revenue building up month by month?

**Why:** Year-to-date (YTD) running total per region. SUM(...) OVER (PARTITION
BY region ORDER BY month ROWS UNBOUNDED PRECEDING) adds each month to all
earlier months, restarting for every region.

```sql
WITH m AS (
  SELECT c.region_code,
         DATEFROMPARTS(YEAR(f.order_date), MONTH(f.order_date), 1)
             AS mth,
         SUM(f.net_amount_usd) AS rev
  FROM bi.fact_sales f
  JOIN bi.dim_customer c ON c.customer_id = f.customer_id
  WHERE f.order_date >= '2026-01-01'
  GROUP BY c.region_code,
           DATEFROMPARTS(YEAR(f.order_date), MONTH(f.order_date), 1)
)
SELECT region_code, mth, rev,
       SUM(rev) OVER (PARTITION BY region_code ORDER BY mth
                      ROWS UNBOUNDED PRECEDING) AS ytd_rev
FROM m
ORDER BY region_code, mth;
```

**Result:**

```
+----+-------------+------------+------------+-------------+
|    | region_code | mth        | rev        | ytd_rev     |
+====+=============+============+============+=============+
|  1 | CNA         | 2026-01-01 | 2339561.74 |  2339561.74 |
+----+-------------+------------+------------+-------------+
|  2 | CNA         | 2026-02-01 | 4102227.80 |  6441789.54 |
+----+-------------+------------+------------+-------------+
|  3 | CNA         | 2026-03-01 | 2234236.16 |  8676025.70 |
+----+-------------+------------+------------+-------------+
|  4 | CNA         | 2026-04-01 | 2474424.66 | 11150450.36 |
+----+-------------+------------+------------+-------------+
|  5 | CNA         | 2026-05-01 | 2805534.02 | 13955984.38 |
+----+-------------+------------+------------+-------------+
|  6 | CNA         | 2026-06-01 | 3771585.23 | 17727569.61 |
+----+-------------+------------+------------+-------------+
|  7 | CNA         | 2026-07-01 | 2715789.96 | 20443359.57 |
+----+-------------+------------+------------+-------------+
|  8 | CNA         | 2026-08-01 | 2356341.54 | 22799701.11 |
+----+-------------+------------+------------+-------------+
|  9 | CNA         | 2026-09-01 | 3356638.48 | 26156339.59 |
+----+-------------+------------+------------+-------------+
| 10 | EU          | 2026-01-01 | 5514633.00 |  5514633.00 |
+----+-------------+------------+------------+-------------+
```

Showing the first 10 of 63 rows.

**What it told me:** Each region's ytd_rev climbs month by month and restarts
for the next region (the first 10 rows show China & North Asia reaching $26.2 M
by September). September YTD: EU $61.3 M leads, then MEA $43.2 M and IND $42.7
M; CNA is lowest. Caveat: region totals still include the 4 customers in the
wrong region (C5), so fix that before trusting regional numbers. Power BI does
the same with DAX TOTALYTD.

### Q8 · Which index makes queries on the big telemetry table faster?

**Why:** Performance tuning on the largest table (382,639 rows). Two typical
queries were timed on a copy of the table in tempdb: (1) an aggregate over ALL
rows, like OEE per machine, and (2) a lookup of ONE machine for one month. Each
was run with no index, with a row-store covering index, and with a clustered
columnstore index.

```sql
-- (1) aggregate over all rows       (2) one machine, one month
SELECT machine_id,                   -- SELECT perf_date, run_hours,
       SUM(run_hours) / SUM(planned_hours) AS availability,
       1.0 * SUM(good_parts) / SUM(total_parts) AS quality
FROM dbo.zz_perf                     --        total_parts
WHERE run_hours IS NOT NULL          -- FROM dbo.zz_perf
  AND good_parts <= total_parts      -- WHERE machine_id = 4
GROUP BY machine_id;                 --   AND perf_date >= '2026-09-01';

-- Option B: row-store index, sorted by machine and date
CREATE NONCLUSTERED INDEX IX_zz ON dbo.zz_perf (machine_id, perf_date)
    INCLUDE (planned_hours, run_hours, ideal_rate_per_hour,
             total_parts, good_parts);

-- Option C: columnstore (stores each column separately, compressed)
CREATE CLUSTERED COLUMNSTORE INDEX CCI_zz ON dbo.zz_perf;
```

**Result:**

```
+---+-----------------------------+---------------+---------------+------------+
|   | Setup                       | Aggregate:    | Aggregate:    | Lookup:    |
|   |                             | logical reads | CPU ms        | time ms    |
+===+=============================+===============+===============+============+
| 1 | A. No index (heap)          |          2602 |           517 |        208 |
+---+-----------------------------+---------------+---------------+------------+
| 2 | B. Row-store covering index |          2436 |           396 |         16 |
+---+-----------------------------+---------------+---------------+------------+
| 3 | C. Clustered columnstore    |           855 |            34 |          8 |
+---+-----------------------------+---------------+---------------+------------+
```

**What it told me:** The right index depends on the query. For the big
aggregate, columnstore cut reads by two-thirds (2,602 to 855 pages) and CPU by
15x (517 to 34 ms); the row-store index barely helped, because the query still
reads every row. For the one-machine lookup, the row-store index made it about
13x faster (208 to 16 ms) by jumping straight to that machine instead of
scanning the whole table. Rule of thumb: row-store indexes for point lookups,
columnstore for big aggregations (which is what Power BI and OEE reports do).

---

## Part 5 · Supporting checks (run by Claude to confirm findings)

Extra checks behind some of the conclusions above.

### C1 · Does the amount rule hold for every order line?

**Why:** Confirms the explanation in 2.3 across the whole table, not just the 7
bad rows.

```sql
SELECT COUNT(*) AS lines_checked,
       SUM(CASE WHEN ABS(quantity * unit_list_price_usd
                 * (1 - discount_pct) - net_amount_usd) > 0.01
                THEN 1 ELSE 0 END) AS formula_mismatches,
       SUM(CASE WHEN net_amount_usd < 0 THEN 1 ELSE 0 END)
           AS negative_amounts
FROM raw.sales_order_line;
```

**Result:**

```
+---+---------------+--------------------+------------------+
|   | lines_checked | formula_mismatches | negative_amounts |
+===+===============+====================+==================+
| 1 |         30775 |                  0 |                7 |
+---+---------------+--------------------+------------------+
```

**What it told me:** The rule matches all 30,775 lines, and the only 7 negative
amounts are the 7 lines with quantity -1.

### C2 · Are the duplicate tickets identical copies?

**Why:** If the two copies differed (e.g. different close times), someone would
have to decide which is right. If identical, it's safe to keep one.

```sql
WITH dup AS (
    SELECT ticket_id FROM raw.service_ticket
    GROUP BY ticket_id HAVING COUNT(*) > 1
), versions AS (
    SELECT ticket_id, COUNT(*) AS distinct_versions
    FROM (SELECT DISTINCT * FROM raw.service_ticket) d
    WHERE ticket_id IN (SELECT ticket_id FROM dup)
    GROUP BY ticket_id
)
SELECT COUNT(*) AS duplicated_tickets,
       SUM(CASE WHEN distinct_versions = 1 THEN 1 ELSE 0 END)
           AS identical_copies
FROM versions;
```

**Result:**

```
+---+--------------------+------------------+
|   | duplicated_tickets | identical_copies |
+===+====================+==================+
| 1 |                 15 |               15 |
+---+--------------------+------------------+
```

**What it told me:** All 15 pairs are identical in every column: the same ticket
was loaded twice. bi.fact_service_ticket keeps one copy using ROW_NUMBER().

### C3 · Are the tickets with no close time really still open?

**Why:** Supports 2.7: compare empty closed_at with the status and opening
dates.

```sql
SELECT status, COUNT(*) AS tickets,
       MIN(opened_at) AS first_opened,
       MAX(opened_at) AS last_opened
FROM raw.service_ticket
WHERE closed_at IS NULL
GROUP BY status;
```

**Result:**

```
+---+--------+---------+---------------------+---------------------+
|   | status | tickets | first_opened        | last_opened         |
+===+========+=========+=====================+=====================+
| 1 | Open   |      54 | 2026-09-21 06:00:00 | 2026-09-30 22:00:00 |
+---+--------+---------+---------------------+---------------------+
```

**What it told me:** All 54 are Open, opened between 21 and 30 Sep 2026, the
last 10 days of the data. Legitimate, not an error.

### C4 · Which products were never sold?

**Why:** Follow-up to 2.4: name the product IDs missing from the order lines.

```sql
SELECT p.product_id, p.product_name
FROM raw.dim_product p
WHERE NOT EXISTS (SELECT 1 FROM raw.sales_order_line l
                  WHERE l.product_id = p.product_id);
```

**Result:**

```
+---+------------+--------------------------+
|   | product_id | product_name             |
+===+============+==========================+
| 1 |         13 | Medical Precision Mold   |
+---+------------+--------------------------+
| 2 |         31 | Hot Runner Refurbishment |
+---+------------+--------------------------+
| 3 |         32 | Training Course          |
+---+------------+--------------------------+
```

**What it told me:** Medical Precision Mold, Hot Runner Refurbishment and
Training Course. Not a data error but a question for the product team: new,
discontinued, or sold under another code?

### C5 · After cleaning, does any country sit in two regions?

**Why:** Checks the effect of 2b on the clean bi.dim_customer view, which fixes
spellings but keeps the region code.

```sql
SELECT country, STRING_AGG(region_code, ', ') AS regions
FROM (SELECT DISTINCT country, region_code
      FROM bi.dim_customer) x
GROUP BY country
HAVING COUNT(*) > 1;
```

**Result:**

```
+---+----------------------+---------+
|   | country              | regions |
+===+======================+=========+
| 1 | Germany              | EU, IND |
+---+----------------------+---------+
| 2 | India                | IND, NA |
+---+----------------------+---------+
| 3 | United Arab Emirates | MEA, NA |
+---+----------------------+---------+
| 4 | Vietnam              | EU, SEA |
+---+----------------------+---------+
```

**What it told me:** Before the fix (result above): 4 countries appeared under
two regions, which skews revenue by region and region security. Fixed on 21 Oct
2026: reference tables in 04, region derived from country in 05, new rule DQ09
(4 rows). The query now returns 0 rows.

### C6 · Why did one query take 29 seconds?

**Why:** Q3 took 29 s, but its execution plan showed only 0.12 s of work. Wait
statistics show what a query was waiting for. (Result as seen on 21 Oct 2026; it
changes every run.)

```sql
SELECT TOP 3 wait_type, waiting_tasks_count, wait_time_ms
FROM sys.dm_exec_session_wait_stats
WHERE session_id = @@SPID
ORDER BY wait_time_ms DESC;
```

**Result:**

```
+---+-----------------------+---------------------+--------------+
|   | wait_type             | waiting_tasks_count | wait_time_ms |
+===+=======================+=====================+==============+
| 1 | RESOURCE_SEMAPHORE    |                   1 |        29012 |
+---+-----------------------+---------------------+--------------+
| 2 | PAGEIOLATCH_SH        |                  26 |           17 |
+---+-----------------------+---------------------+--------------+
| 3 | MEMORY_ALLOCATION_EXT |                 902 |            5 |
+---+-----------------------+---------------------+--------------+
```

**What it told me:** RESOURCE_SEMAPHORE: the query queued 29 s for memory. The
laptop had about 700 MB of its 8 GB free, so SQL Server had only 6 MB for
queries. The fix was memory (close other apps), not the SQL. A real
performance-troubleshooting example.
