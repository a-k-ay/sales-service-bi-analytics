# Performance notes: model size and query timings

Measured on 23 Oct 2026 with DAX Studio 3.6.1 connected to the Power BI Desktop
model, using VertiPaq Analyzer (View Metrics) for storage and a Server Timings
trace for query time. Two findings were then verified against SQL Server.
SQL-side index tuning is in docs/query_log.md (question Q8); this file is about
the tabular model.

## How VertiPaq stores a table

Power BI's engine is a column store. Each column is compressed separately, so
size follows the number of DISTINCT values (cardinality), not the number of
rows. Two costs show up in the metrics:

- Data: the encoded values themselves, one entry per row, bit-packed. This grows
  with row count.
- Dictionary: the list of distinct values. This grows with cardinality, and is
  where text and timestamps get expensive.

The engine chooses an encoding per column. VALUE encoding stores the integer
directly and needs no dictionary at all. HASH encoding builds a dictionary of
distinct values and stores a small pointer per row; it is used for text, dates
and decimals.

## Model size by table

```
+-------------------------+---------+-------------+------------+
| Table                   | Rows    | Total bytes | % of model |
+=========================+=========+=============+============+
| fact_machine_daily      | 382,594 | 5,088,716   | 59.14%     |
+-------------------------+---------+-------------+------------+
| fact_service_ticket     | 10,662  | 1,601,053   | 18.61%     |
+-------------------------+---------+-------------+------------+
| fact_sales              | 30,101  | 1,270,285   | 14.76%     |
+-------------------------+---------+-------------+------------+
| dim_customer            | 320     | 182,806     | 2.12%      |
+-------------------------+---------+-------------+------------+
| dim_date                | 1,096   | 124,878     | 1.45%      |
+-------------------------+---------+-------------+------------+
| dim_machine             | 637     | 119,432     | 1.39%      |
+-------------------------+---------+-------------+------------+
| dim_product             | 32      | 93,284      | 1.08%      |
+-------------------------+---------+-------------+------------+
| vw_data_quality_results | 9       | 71,044      | 0.83%      |
+-------------------------+---------+-------------+------------+
| dim_region              | 7       | 52,494      | 0.61%      |
+-------------------------+---------+-------------+------------+
```

The model is about 8.6 MB in memory. The nine tables split into three facts that
carry 92.5% of the size and six small dimensions that are effectively free.

The two largest facts are large for OPPOSITE reasons, which is the whole lesson
of this exercise:

```
+---------------------+-----------+------------+-------------------------------+
| Table               | Data      | Dictionary | Why it is big                 |
+=====================+===========+============+===============================+
| fact_machine_daily  | 4,674,320 | 301,404    | Long table, few distinct      |
|                     |           |            | values: the cost is the rows  |
+---------------------+-----------+------------+-------------------------------+
| fact_service_ticket | 193,200   | 1,110,893  | Short table, near-unique      |
|                     |           |            | values: the cost is the       |
|                     |           |            | dictionary                    |
+---------------------+-----------+------------+-------------------------------+
| fact_sales          | 445,208   | 548,253    | Mixed: order numbers inflate  |
|                     |           |            | the dictionary                |
+---------------------+-----------+------------+-------------------------------+
```

## The biggest columns

Sorted by column size. The % column is the share of that column's own table,
which is what tells you where to aim.

```
+------------------------------------+-------------+-----------+-------+-------+
| Column                             | Cardinality | Bytes     | Enc   | % tbl |
+====================================+=============+===========+=======+=======+
| fact_machine_daily[good_parts]     | 280,297     | 1,020,528 | VALUE | 20.06 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_machine_daily[total_parts]    | 278,136     | 1,019,768 | VALUE | 20.05 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_machine_daily[ideal_parts]    | 6,908       | 907,584   | HASH  | 17.84 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_machine_daily[scrap_parts]    | 25,206      | 830,520   | VALUE | 16.33 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_machine_daily[run_hours]      | 2,374       | 678,104   | HASH  | 13.33 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_sales[order_number]           | 11,108      | 543,197   | HASH  | 42.88 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_machine_daily[perf_date]      | 638         | 537,096   | HASH  | 10.56 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_service_ticket[closed_at]     | 10,565      | 462,304   | HASH  | 28.92 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_service_ticket[opened_at]     | 8,583       | 424,948   | HASH  | 26.58 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_service_ticket[ticket_number] | 10,662      | 373,563   | HASH  | 23.37 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_sales[order_line_id]          | 30,101      | 180,888   | VALUE | 14.28 |
|                                    |             |           |       | %     |
+------------------------------------+-------------+-----------+-------+-------+
| fact_sales[net_amount_usd]         | 6,726       | 120,680   | VALUE | 9.53% |
+------------------------------------+-------------+-----------+-------+-------+
| fact_sales[order_id]               | 11,108      | 104,920   | VALUE | 8.28% |
+------------------------------------+-------------+-----------+-------+-------+
```

Three things stand out. The top five columns are all in fact_machine_daily and
together are about 4.46 MB, just over half the model. One column, order_number,
is 42.88% of fact_sales on its own: 11,108 distinct strings with a 393,981-byte
dictionary. And the two ticket timestamps are 55.5% of fact_service_ticket
between them, because a datetime recorded to the second is almost unique per row
(10,565 distinct values across 10,662 rows).

## Findings worth acting on

```
+--------------------------+----------+-----------------------------------+
| Finding                  | Saving   | Fix                               |
+==========================+==========+===================================+
| scrap_parts repeats what | 830 KB   | Drop the column; add a measure    |
| two other columns        |          | Scrap Parts = SUM ( total_parts ) |
| already say              |          | - SUM ( good_parts )              |
+--------------------------+----------+-----------------------------------+
| order_number is not used | 543 KB   | Drop it, or keep it only if       |
| by any measure or visual |          | drill-through to a single order   |
|                          |          | is a real requirement             |
+--------------------------+----------+-----------------------------------+
| opened_at and closed_at  | ~500 KB  | Split each into a date column and |
| are datetimes down to    |          | a time column, or round to the    |
| the second               |          | minute                            |
+--------------------------+----------+-----------------------------------+
```

Together these are roughly 20% of the model. They are recorded here rather than
applied, because the report and its 44 visuals are validated against the model
as it stands; the point of the exercise was to find them and be able to justify
the trade-off.

The first one was not a guess. scrap_parts looked derivable, so it was checked
across every row:

```sql
SELECT COUNT(*) AS rows_total,
       SUM(CASE WHEN scrap_parts = total_parts - good_parts
                THEN 1 ELSE 0 END) AS rows_derivable
FROM bi.fact_machine_daily;
```

Result: rows_total 382,594, rows_derivable 382,594. The column is redundant in
100% of rows, and costs 9.65% of the model.

## Referential integrity: the blank date

VertiPaq Analyzer flags one RI violation on dim_date. That means a fact column
feeding a relationship holds values the date table does not have. It was traced
in SQL:

```sql
SELECT COUNT(*) FROM bi.fact_sales WHERE ship_date IS NULL;
-- 1,123

SELECT COUNT(*) FROM bi.fact_sales f
WHERE f.ship_date IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM bi.dim_date d
                  WHERE d.[date] = f.ship_date);
-- 0
```

Every real ship date is covered by dim_date (2024-01-01 to 2026-12-31, 1,096
days). The violation is 1,123 order lines that are still OPEN and so have no
ship date at all. That is correct business data, not a defect: those same rows
are the $60.0 M backlog. The right response is to handle the blank in the
measure and in the report, not to invent a ship date.

## Query timing: OEE and MTTR by monitoring tier

The heaviest question in the report, measured with a cold cache:

```dax
EVALUATE
SUMMARIZECOLUMNS (
    dim_machine[monitoring_tier],
    "OEE", [OEE],
    "MTTR (hrs)", [MTTR (hrs)]
)
```

```
+-----------------+--------+------------+
| monitoring_tier |    OEE | MTTR (hrs) |
+=================+========+============+
| No Contract     |  77.4% |       19.5 |
+-----------------+--------+------------+
| Bronze          |  79.0% |        7.2 |
+-----------------+--------+------------+
| Silver          |  79.2% |        7.0 |
+-----------------+--------+------------+
| Gold            |  81.3% |        7.1 |
+-----------------+--------+------------+
| Platinum        |  83.7% |        7.2 |
+-----------------+--------+------------+
```

The same five numbers come out of SQL, the Power BI report and this raw DAX
query, which is the consistency check that matters: one definition of OEE, in
the model, not three in three places.

```
+--------------------------+------------+----------------------------------+
| Metric                   | Value      | What it means                    |
+==========================+============+==================================+
| Total                    | 120 ms     | The whole query, start to finish |
+--------------------------+------------+----------------------------------+
| FE (formula engine)      | 44 ms      | Single-threaded DAX logic: the   |
|                          | (36.7%)    | three divisions and the          |
|                          |            | multiplication                   |
+--------------------------+------------+----------------------------------+
| SE (storage engine)      | 76 ms      | Multi-threaded scan of the       |
|                          | (63.3%)    | compressed columns               |
+--------------------------+------------+----------------------------------+
| SE queries               | 2          | One scan per fact table: the     |
|                          |            | optimal plan                     |
+--------------------------+------------+----------------------------------+
| SE cache                 | 0 (0.0%)   | Cold cache, so this is a         |
|                          |            | worst-case time                  |
+--------------------------+------------+----------------------------------+
| Scan 1 result            | 8 rows, 1  | What fact_machine_daily handed   |
|                          | KB         | back to the formula engine       |
+--------------------------+------------+----------------------------------+
| Scan 2 result            | 8 rows, 1  | What fact_service_ticket handed  |
|                          | KB         | back                             |
+--------------------------+------------+----------------------------------+
```

This is the shape a healthy query has. The storage engine scanned about 393,000
rows and handed back 8 rows and 1 KB; the formula engine then did arithmetic on
those 8 rows. The warning signs would be the reverse: a large datacache, many
small SE queries, or CallbackDataID in the xmSQL, which means the storage engine
had to call back to the formula engine row by row.

Parallelism was x0.8, effectively one thread. That is expected here: each table
fits in a single segment, and the engine only splits a scan across threads above
roughly 8 million rows per table.

## What I would do next

- Apply the three column findings above and re-measure, expecting the model to
  drop by about a fifth.
- Re-run this query after Clear Cache versus warm, to show the SE cache hit rate
  moving from 0% and the total time falling.
- Add a date/time split on the ticket timestamps in sql/05 rather than in Power
  BI, so the saving is in the source view and every consumer gets it.
- Watch fact_machine_daily as the date range grows: it is the only table whose
  cost scales with rows rather than with cardinality.
