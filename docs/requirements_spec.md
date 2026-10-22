# Requirements specification: Sales & Service Analytics

Business-analyst view of the prototype: who it is for, which questions it
answers, and exactly how each KPI is defined. **All data is synthetic**
(ERP-style sales, service and machine-monitoring data, Jan 2024 to Sep 2026;
telemetry from Jan 2025).

## 1. Business goal

Give sales and service leaders one trusted view of revenue, service performance
and machine health, and show the value of the remote-monitoring service so that
more customers can be moved onto (higher) monitoring contracts.

## 2. Stakeholders (personas)

```
+--------------------------+--------------------------------+------------------+
| Persona                  | Main question                  | Report page      |
+==========================+================================+==================+
| VP Sales / Aftermarket   | How are we doing, and where    | Executive Sales  |
|                          | does revenue come from?        |                  |
+--------------------------+--------------------------------+------------------+
| Regional Service Manager | Are we fixing machines fast,   | Service          |
|                          | and remotely?                  |                  |
+--------------------------+--------------------------------+------------------+
| Remote Monitoring /      | Do monitored machines run      | Machine Health   |
| Plant Ops lead           | better?                        |                  |
+--------------------------+--------------------------------+------------------+
| Data owner / BI team     | Can the numbers be trusted?    | Data Quality     |
+--------------------------+--------------------------------+------------------+
| Regional sales rep       | Which of my customers should I | Service (upsell  |
|                          | call?                          | list), filtered  |
|                          |                                | to own region by |
|                          |                                | RLS              |
+--------------------------+--------------------------------+------------------+
```

## 3. User stories and acceptance criteria

```
+-----+-------------------------------------+----------------------------------+
| #   | User story                          | Accepted when                    |
+=====+=====================================+==================================+
| US1 | As a VP Sales, I want revenue,      | Cards for Revenue, Gross Margin  |
|     | margin, YoY and backlog on one      | %, YoY %, Backlog, Aftermarket   |
|     | page, so that I can see performance | Share; year and region slicers;  |
|     | at a glance.                        | totals match SQL (Revenue        |
|     |                                     | $924,393,526).                   |
+-----+-------------------------------------+----------------------------------+
| US2 | As a Service Manager, I want MTTR   | Service page shows MTTR 7.1 h    |
|     | and % remote by monitoring status,  | monitored vs 19.5 h not          |
|     | so that I can show the value of     | monitored.                       |
|     | remote support.                     |                                  |
+-----+-------------------------------------+----------------------------------+
| US3 | As a Plant Ops lead, I want OEE by  | OEE rises from 77.4% (No         |
|     | monitoring tier, so that I can      | Contract) to 83.7% (Platinum).   |
|     | prove the monitoring benefit.       |                                  |
+-----+-------------------------------------+----------------------------------+
| US4 | As a sales rep, I want a list of    | Upsell table, top 20 by          |
|     | unmonitored machines with high      | downtime, only No Contract       |
|     | downtime in my region, so that I    | machines, filtered by RLS.       |
|     | can pitch a monitoring contract.    |                                  |
+-----+-------------------------------------+----------------------------------+
| US5 | As a data owner, I want to see      | 9 rules with failed rows and     |
|     | data-quality failures, so that I    | pass rate; not filtered by       |
|     | can fix them at source.             | region.                          |
+-----+-------------------------------------+----------------------------------+
| US6 | As a regional manager, I must only  | View as Region IND shows Revenue |
|     | see my own region.                  | $153,320,070 and 1,701 tickets.  |
+-----+-------------------------------------+----------------------------------+
```

## 4. KPI definitions

One agreed definition per KPI, so every region calculates it the same way. Grain
= the level of detail of the source table.

```
+------------------+----------------------------------+------------------------+
| KPI              | Definition (business)            | Source and grain       |
+==================+==================================+========================+
| Revenue          | Net order line value after       | bi.fact_sales, order   |
|                  | discount; cancelled orders,      | line                   |
|                  | orphan products and quantity <=  |                        |
|                  | 0 excluded                       |                        |
+------------------+----------------------------------+------------------------+
| Gross Margin %   | (Revenue - standard cost) /      | bi.fact_sales, order   |
|                  | Revenue                          | line                   |
+------------------+----------------------------------+------------------------+
| Revenue YoY %    | Year-to-date revenue vs the same | fact_sales + dim_date  |
|                  | period last year, ending at the  |                        |
|                  | last date with data              |                        |
|                  | (like-for-like)                  |                        |
+------------------+----------------------------------+------------------------+
| Backlog          | Revenue of orders with status    | bi.fact_sales          |
|                  | Open (ordered, not shipped)      |                        |
+------------------+----------------------------------+------------------------+
| Aftermarket      | Aftermarket (spare parts)        | bi.fact_sales          |
| Share %          | revenue / total revenue          |                        |
+------------------+----------------------------------+------------------------+
| Availability     | Run hours / planned hours        | bi.fact_machine_daily, |
|                  |                                  | machine-day            |
+------------------+----------------------------------+------------------------+
| Performance      | Total parts / (run hours x ideal | bi.fact_machine_daily  |
|                  | rate per hour)                   |                        |
+------------------+----------------------------------+------------------------+
| Quality          | Good parts / total parts         | bi.fact_machine_daily  |
+------------------+----------------------------------+------------------------+
| OEE              | Availability x Performance x     | bi.fact_machine_daily  |
|                  | Quality (sums first, then        |                        |
|                  | divide)                          |                        |
+------------------+----------------------------------+------------------------+
| Tickets          | Count of unique service tickets  | bi.fact_service_ticket |
|                  |                                  | , ticket               |
+------------------+----------------------------------+------------------------+
| MTTR (hrs)       | Average hours from opened to     | bi.fact_service_ticket |
|                  | closed, closed tickets only;     |                        |
|                  | negative times excluded          |                        |
+------------------+----------------------------------+------------------------+
| % Remote         | Tickets resolved remotely / all  | bi.fact_service_ticket |
| Resolution       | tickets                          |                        |
+------------------+----------------------------------+------------------------+
| Monitored        | Machines with any monitoring     | bi.dim_machine,        |
| Machines %       | tier / all machines              | machine                |
+------------------+----------------------------------+------------------------+
```

## 5. Data sources and model

- Sources (simulated): ERP sales orders and lines, customer, product and
  installed-base master data, service tickets, daily machine telemetry.
- Raw layer: SQL Server schema `raw` keeps the data exactly as loaded, problems
  included.
- Clean layer: schema `bi` views apply the data-quality fixes and form a star
  schema: 3 facts (sales line, ticket, machine-day) and 5 dimensions (date,
  customer, product, machine, region).
- Power BI imports only the `bi` views. Relationships are single-direction,
  one-to-many. Order date is the active date; ship date is inactive
  (USERELATIONSHIP).

## 6. Security and governance

- Row-level security: one role per region, filtering dim_region; filters flow to
  all facts.
- Data quality: 9 rules (sql/04) shown on the Data Quality page; issues go back
  to the data owner to fix at source.
- Master data: duplicate customers mapped to one golden record; country and
  region come from reference tables.
- Version control: SQL, docs and the Power BI project (.pbip, TMDL) in Git.

## 7. Out of scope for the prototype

- Publishing to the Power BI Service (needs a work account): workspaces, apps,
  scheduled refresh, gateway, deployment pipelines.
- Live ERP connection and an automated pipeline (would use ADF or Fabric Data
  Factory).
- Currency conversion, forecasting, MTBF.
