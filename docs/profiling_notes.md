# Profiling notes: SalesServiceBI raw tables

Each finding is one sentence: **what I saw**, then **why it matters**. Together
they answer the question "What is data profiling, and what did you find?"

## Summary: data-quality issues found

```
+----+----------------------------+------------------+------+----------------+
| #  | Issue                      | Table            | Rows | Found with     |
+====+============================+==================+======+================+
| 1  | No account tier            | dim_customer     |    5 | P2             |
+----+----------------------------+------------------+------+----------------+
| 2  | Non-standard country name  | dim_customer     |    8 | P3 + own query |
+----+----------------------------+------------------+------+----------------+
| 2b | Country in wrong region    | dim_customer     |    4 | Own query      |
|    | (bonus)                    |                  |      |                |
+----+----------------------------+------------------+------+----------------+
| 3  | Same company twice         | dim_customer     |    6 | P4             |
+----+----------------------------+------------------+------+----------------+
| 4  | Quantity -1                | sales_order_line |    7 | P5 + own query |
+----+----------------------------+------------------+------+----------------+
| 5  | Impossible telemetry       | machine_daily_   |   45 | P7             |
|    |                            | performance      |      |                |
+----+----------------------------+------------------+------+----------------+
| 6  | Product not in product     | sales_order_line |   12 | Own query      |
|    | list                       |                  |      |                |
+----+----------------------------+------------------+------+----------------+
| 7  | Same ticket twice          | service_ticket   |   15 | Own query      |
+----+----------------------------+------------------+------+----------------+
| 8  | Closed before opened       | service_ticket   |    6 | Own query      |
+----+----------------------------+------------------+------+----------------+
```

All 8 planted issues found. Issue 2b is a bonus finding on top of them.

## Checked against sql/04 (the automatic rules)

```
+------+----------------------+-----------------------+------+------+-------+
| Rule | What it checks       | Dimension             | Rows | My # | Match |
+======+======================+=======================+======+======+=======+
| DQ01 | Same customer twice  | Uniqueness            |    6 |    3 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ02 | Country spelling     | Validity              |    8 |    2 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ03 | Account tier missing | Completeness          |    5 |    1 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ04 | Product exists       | Referential integrity |   12 |    6 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ05 | Quantity above 0     | Validity              |    7 |    4 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ06 | Ticket appears once  | Uniqueness            |   15 |    7 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ07 | Closed after opened  | Consistency           |    6 |    8 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ08 | Telemetry possible   | Validity              |   45 |    5 | Yes   |
+------+----------------------+-----------------------+------+------+-------+
| DQ09 | Region fits country  | Consistency           |    4 |   2b | Yes   |
+------+----------------------+-----------------------+------+------+-------+
```

- **Added after profiling:** issue 2b became rule DQ09. 04 now holds reference
  tables (bi.ref_country_region, bi.ref_country_alias), and 05 derives each
  customer's region from the country, so the 4 customers are corrected in the
  clean data.
- **Pass rates hide impact:** every rule passes above 97%, yet DQ04 (99.96%)
  still leaves $258,989 of revenue without a product. Report the business
  impact, not just the percentage.

## Findings from sql/03, block by block

```
+-------+--------------------+------------------------------------------------+
| Block | What it checks     | What I learned                                 |
+=======+====================+================================================+
| P1    | Row count and date | Sales orders and service tickets run from Jan  |
|       | range              | 2024 to Sep 2026, but machine telemetry only   |
|       |                    | starts in Jan 2025, so OEE trends begin in     |
|       |                    | 2025 and have no prior year to compare         |
|       |                    | against.                                       |
+-------+--------------------+------------------------------------------------+
| P2    | Missing values in  | Account tier is the only incomplete customer   |
|       | the customer       | field (5 of 326 customers), so a report        |
|       | master (issue 1)   | filtered by tier would silently miss them;     |
|       |                    | show them as "Unassigned" and send them back   |
|       |                    | to the data owner to fix at source.            |
+-------+--------------------+------------------------------------------------+
| P3    | Countries per      | 8 customers have a non-standard country name   |
|       | region (issues 2,  | and 4 of them also sit in the wrong region, so |
|       | 2b)                | a revenue-by-country chart would split one     |
|       |                    | country into several bars, and regional totals |
|       |                    | and region-based security would show those     |
|       |                    | customers to the wrong manager.                |
+-------+--------------------+------------------------------------------------+
| P4    | Duplicate customer | 6 companies exist twice under different        |
|       | names (issue 3)    | customer numbers, so their revenue is split    |
|       |                    | across two records and they can drop out of a  |
|       |                    | "Top 10 customers" ranking; map each copy to   |
|       |                    | one golden record.                             |
+-------+--------------------+------------------------------------------------+
| P5    | Order line amounts | 7 order lines (5 Aftermarket, 2 HotRunner)     |
|       | (issue 4)          | have a quantity of -1, which makes their       |
|       |                    | amounts negative (-$130,724 in total), so      |
|       |                    | revenue is understated; confirm with sales     |
|       |                    | operations or finance whether they are entry   |
|       |                    | errors or real returns before excluding them.  |
+-------+--------------------+------------------------------------------------+
| P6    | Median repair time | A typical ticket takes 1.6 h when fixed        |
|       | (business insight) | remotely, 4 h by phone and 20.6 h with a       |
|       |                    | technician visit, so each ticket solved        |
|       |                    | remotely saves roughly 19 hours, which         |
|       |                    | supports selling remote-monitoring contracts.  |
|       |                    | The median is used, not the average, so a few  |
|       |                    | very long tickets don't distort the typical    |
|       |                    | time.                                          |
+-------+--------------------+------------------------------------------------+
| P7    | Telemetry sanity   | 45 machine-days have impossible telemetry (25  |
|       | (issue 5)          | with no run hours, 20 with more good parts     |
|       |                    | than total parts), so OEE would be wrong:      |
|       |                    | Quality goes above 100% and Availability       |
|       |                    | drops. Exclude them from OEE and report them   |
|       |                    | to the monitoring-data team.                   |
+-------+--------------------+------------------------------------------------+
```

## Details behind the findings

### P3 · The 8 country names

```
+-------------+----------------------+----------------+-------------------+
| Written as  | Should be            | Region in data | Region right?     |
+=============+======================+================+===================+
| USA         | United States        | NA             | Yes               |
+-------------+----------------------+----------------+-------------------+
| U.S.A.      | United States        | NA             | Yes               |
+-------------+----------------------+----------------+-------------------+
| UK          | United Kingdom       | EU             | Yes               |
+-------------+----------------------+----------------+-------------------+
| KSA         | Saudi Arabia         | MEA            | Yes               |
+-------------+----------------------+----------------+-------------------+
| UAE         | United Arab Emirates | NA             | No, should be MEA |
+-------------+----------------------+----------------+-------------------+
| Deutschland | Germany              | IND            | No, should be EU  |
+-------------+----------------------+----------------+-------------------+
| india       | India                | NA             | No, should be IND |
+-------------+----------------------+----------------+-------------------+
| Viet Nam    | Vietnam              | EU             | No, should be SEA |
+-------------+----------------------+----------------+-------------------+
```

SQL Server ignores upper/lower case by default (`india` = `India`), so this
query compares case-sensitively to return exactly these 8 rows:

```sql
SELECT *
FROM raw.dim_customer
WHERE country COLLATE Latin1_General_CS_AS
      IN ('india', 'Viet Nam', 'USA', 'U.S.A.',
          'UK', 'UAE', 'KSA', 'Deutschland');
```

### P4 · One duplicate pair

```
+--------+-----------------------+---------------------------+
| Field  | Original              | Copy                      |
+========+=======================+===========================+
| Number | C100124               | C900000                   |
+--------+-----------------------+---------------------------+
| Name   | Horizon Foods Pvt Ltd | HORIZON FOODS PVT LIMITED |
+--------+-----------------------+---------------------------+
```

Keep the `C100…` record: it's in the normal number series, typed properly, and
has the lowest ID.

### P5 · Zoom in and test the amount rule

The amount rule is quantity × price × (1 − discount). This query shows the 7
rows and recalculates each amount:

```sql
SELECT order_line_id, product_id, quantity,
       unit_list_price_usd, discount_pct, net_amount_usd,
       quantity * unit_list_price_usd
         * (1 - discount_pct) AS my_calculation
FROM raw.sales_order_line
WHERE quantity <= 0;
```

### P6 · Median hours by resolution type

```
+------------------+--------------+
| Fixed by         | Median hours |
+==================+==============+
| Remote           |          1.6 |
+------------------+--------------+
| Phone Support    |          4.0 |
+------------------+--------------+
| Technician Visit |         20.6 |
+------------------+--------------+
```

### P7 · Telemetry checks

```
+----------------------------------+------+
| Check                            | Rows |
+==================================+======+
| No run hours                     |   25 |
+----------------------------------+------+
| Ran more hours than planned      |    0 |
+----------------------------------+------+
| More good parts than total parts |   20 |
+----------------------------------+------+
| Total impossible machine-days    |   45 |
+----------------------------------+------+
```

## Issues found with my own queries

```
+----+------------------+----------------------------------------------------+
| #  | Issue            | What I found and why it matters                    |
+====+==================+====================================================+
| 6  | Product not in   | 12 order lines worth $258,988.72 point to product  |
|    | the product list | 999, which doesn't exist ("orphan" lines), so a    |
|    |                  | revenue-by-product chart shows them as (Blank) or  |
|    |                  | drops them from the total.                         |
+----+------------------+----------------------------------------------------+
| 7  | Same ticket      | 15 tickets appear twice as identical copies, so    |
|    | twice            | the ticket count is overstated (10,677 rows vs     |
|    |                  | 10,662 real tickets) and those tickets count       |
|    |                  | double in the average repair time; keep one copy   |
|    |                  | of each.                                           |
+----+------------------+----------------------------------------------------+
| 8  | Closed before    | 6 tickets are closed exactly 5 hours before they   |
|    | opened           | were opened (a time-zone mix-up?), so their repair |
|    |                  | time is negative and pulls MTTR down: the service  |
|    |                  | team looks faster than it really is.               |
+----+------------------+----------------------------------------------------+
```

### Issue 6 query

```sql
SELECT DISTINCT product_id
FROM raw.sales_order_line
ORDER BY product_id;

SELECT COUNT(*) AS lines,
       SUM(net_amount_usd) AS revenue
FROM raw.sales_order_line
WHERE product_id = 999;
```

### Issue 7 query

```sql
SELECT ticket_id, COUNT(*) AS copies
FROM raw.service_ticket
GROUP BY ticket_id
HAVING COUNT(*) > 1;
```

### Issue 8 query

```sql
SELECT ticket_id, opened_at, closed_at
FROM raw.service_ticket
WHERE closed_at < opened_at;
```

## Other observations (not errors, but questions for the business)

```
+--------------------+------------------------------------------------------+
| Observation        | Detail                                               |
+====================+======================================================+
| Products never     | 13 Medical Precision Mold, 31 Hot Runner             |
| sold               | Refurbishment and 32 Training Course are in the      |
|                    | product list but were never sold. Ask the product    |
|                    | team: new, discontinued, or sold under a different   |
|                    | code?                                                |
+--------------------+------------------------------------------------------+
| 54 tickets with no | All 54 have status Open and were opened in the last  |
| close time         | 10 days of the data (21-30 Sep 2026), so they simply |
|                    | aren't fixed yet. NULL here means "not happened      |
|                    | yet", not an error. Leave them out of MTTR and show  |
|                    | them as an "open tickets" count.                     |
+--------------------+------------------------------------------------------+
```

## My method when a number looks wrong

```
+------+------------------+--------------------------------------------------+
| Step | Name             | What to do                                       |
+======+==================+==================================================+
|    1 | Zoom in          | A summary tells you that something is wrong, not |
|      |                  | why. Pull the actual rows.                       |
+------+------------------+--------------------------------------------------+
|    2 | Look across      | Which values look odd, and do they sit on the    |
|      |                  | same rows?                                       |
+------+------------------+--------------------------------------------------+
|    3 | Guess and test   | Use the column names to guess how a value is     |
|      |                  | calculated, add your own calculated column, and  |
|      |                  | check it matches.                                |
+------+------------------+--------------------------------------------------+
|    4 | Count            | Does your explanation cover every case? (7 lines |
|      |                  | with quantity -1 = the same 7 lines with a       |
|      |                  | negative amount.)                                |
+------+------------------+--------------------------------------------------+
|    5 | Ask              | When the data can't tell you, read the data      |
|      |                  | dictionary or ask the system owner.              |
+------+------------------+--------------------------------------------------+
```
