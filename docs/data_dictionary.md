# Data dictionary: SalesServiceBI raw tables

A plain-English guide to every table and column in the `raw` schema. **All data
is synthetic**: it imitates what a global industrial-machinery maker would hold
in its ERP (its main business system) and its machine-monitoring platform.

## Two kinds of tables

```
+--------------+--------------------------+----------------------------------+
| Kind         | What it is               | Tables                           |
+==============+==========================+==================================+
| Master data  | The lists: who and what. | dim_region, dim_customer,        |
| (dim_...)    | Changes rarely.          | dim_product, dim_machine         |
+--------------+--------------------------+----------------------------------+
| Transactions | The events: what         | sales_order, sales_order_line,   |
|              | happened. Grows every    | service_ticket,                  |
|              | day.                     | machine_daily_performance        |
+--------------+--------------------------+----------------------------------+
```

Every transaction row points back to the lists by an **ID**. An order says
"customer 43" instead of repeating the customer's name, country and tier on
every order.

## How the tables connect

```
dim_region
 └─< dim_customer
      ├─< sales_order
      │    └─< sales_order_line >── dim_product
      └─< dim_machine >── dim_product
           ├─< service_ticket
           └─< machine_daily_performance
```

`A ─< B` means **one A has many B**. They are linked by the ID column they
share:

```
+--------------+---------------------------+-------------+
| One...       | has many...               | Linked by   |
+==============+===========================+=============+
| dim_region   | dim_customer              | region_code |
+--------------+---------------------------+-------------+
| dim_customer | sales_order               | customer_id |
+--------------+---------------------------+-------------+
| sales_order  | sales_order_line          | order_id    |
+--------------+---------------------------+-------------+
| dim_product  | sales_order_line          | product_id  |
+--------------+---------------------------+-------------+
| dim_customer | dim_machine               | customer_id |
+--------------+---------------------------+-------------+
| dim_product  | dim_machine               | product_id  |
+--------------+---------------------------+-------------+
| dim_machine  | service_ticket            | machine_id  |
+--------------+---------------------------+-------------+
| dim_machine  | machine_daily_performance | machine_id  |
+--------------+---------------------------+-------------+
```

## dim_region: the company's sales regions

**One row = one region.** 7 rows.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| region_code         | Short code; links to customers | IND                |
+---------------------+--------------------------------+--------------------+
| region_name         | Full name                      | India & SAARC      |
+---------------------+--------------------------------+--------------------+
| super_region        | Bigger grouping of regions     | APAC               |
+---------------------+--------------------------------+--------------------+
| service_center_tz   | Time zone of the region's      | Asia/Kolkata       |
|                     | service centre                 |                    |
+---------------------+--------------------------------+--------------------+
```

```
+-------+----------------------+--------------+
| Code  | Region               | Super region |
+=======+======================+==============+
| NA    | North America        | Americas     |
+-------+----------------------+--------------+
| LATAM | Latin America        | Americas     |
+-------+----------------------+--------------+
| EU    | Europe               | EMEA         |
+-------+----------------------+--------------+
| MEA   | Middle East & Africa | EMEA         |
+-------+----------------------+--------------+
| IND   | India & SAARC        | APAC         |
+-------+----------------------+--------------+
| SEA   | Southeast Asia       | APAC         |
+-------+----------------------+--------------+
| CNA   | China & North Asia   | APAC         |
+-------+----------------------+--------------+
```

## dim_customer: companies that buy from us (customer master)

**One row = one customer company.** 326 rows.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| customer_id         | Internal ID; links to orders,  | 1                  |
|                     | machines and tickets           |                    |
+---------------------+--------------------------------+--------------------+
| customer_number     | The number people see in the   | C100001            |
|                     | ERP                            |                    |
+---------------------+--------------------------------+--------------------+
| customer_name       | Company name                   | Delta Packaging    |
|                     |                                | Pvt Ltd            |
+---------------------+--------------------------------+--------------------+
| industry_segment    | What the customer produces     | Beverage           |
+---------------------+--------------------------------+--------------------+
| account_tier        | How important the account is   | Strategic          |
+---------------------+--------------------------------+--------------------+
| country             | Where the customer is          | United Kingdom     |
+---------------------+--------------------------------+--------------------+
| region_code         | Which sales region looks after | EU                 |
|                     | them                           |                    |
+---------------------+--------------------------------+--------------------+
| created_date        | When the customer was set up   | 2021-04-03         |
|                     | in the ERP                     |                    |
+---------------------+--------------------------------+--------------------+
```

```
+------------------+----------------------------------------------+
| Column           | Possible values                              |
+==================+==============================================+
| industry_segment | Beverage, Food & Consumer, Medical           |
+------------------+----------------------------------------------+
| account_tier     | Strategic (most important), Key, Standard    |
+------------------+----------------------------------------------+
```

## dim_product: what the company sells (product master)

**One row = one product.** 32 rows.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| product_id          | Internal ID; links to order    | 16                 |
|                     | lines and machines             |                    |
+---------------------+--------------------------------+--------------------+
| product_code        | Catalogue code                 | HR-MOD             |
+---------------------+--------------------------------+--------------------+
| product_name        | Product name                   | Hot Runner Modular |
+---------------------+--------------------------------+--------------------+
| product_family      | Product line                   | Hot Runners        |
+---------------------+--------------------------------+--------------------+
| product_type        | Kind of product (see below)    | HotRunner          |
+---------------------+--------------------------------+--------------------+
| industry            | Market it's made for           | Multi (all         |
|                     |                                | markets)           |
+---------------------+--------------------------------+--------------------+
| list_price_usd      | Catalogue price of ONE unit    | 64,000             |
+---------------------+--------------------------------+--------------------+
| std_cost_usd        | What one unit costs to make;   | 33,280             |
|                     | used for profit margin         |                    |
+---------------------+--------------------------------+--------------------+
| is_active           | 1 = still sold                 | 1                  |
+---------------------+--------------------------------+--------------------+
```

Prices range from $450 (a heater band) to $2.3 million (a PET Preform System
400).

```
+--------------+------------------------------------+----------+
| product_type | What it is                         | Products |
+==============+====================================+==========+
| System       | A whole injection molding machine  |        9 |
+--------------+------------------------------------+----------+
| Mold         | Tooling that shapes the plastic    |        4 |
|              | part                               |          |
+--------------+------------------------------------+----------+
| HotRunner    | Keeps plastic molten inside the    |        4 |
|              | mold                               |          |
+--------------+------------------------------------+----------+
| Controller   | Controls hot-runner temperature    |        2 |
+--------------+------------------------------------+----------+
| Part         | Spare part                         |        7 |
+--------------+------------------------------------+----------+
| Service      | Monitoring contracts,              |        6 |
|              | refurbishment, training            |          |
+--------------+------------------------------------+----------+
```

## dim_machine: the installed base

**One row = one of our machines running at a customer's plant.** 637 rows.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| machine_id          | Internal ID; links to tickets  | 4                  |
|                     | and daily performance          |                    |
+---------------------+--------------------------------+--------------------+
| serial_number       | Serial number on the machine   | MCH-8900004        |
+---------------------+--------------------------------+--------------------+
| customer_id         | Who owns it -> dim_customer    | 4                  |
+---------------------+--------------------------------+--------------------+
| product_id          | Which model it is (always a    | 2 (PET Preform     |
|                     | System) -> dim_product         | System 400)        |
+---------------------+--------------------------------+--------------------+
| install_date        | When it started running        | 2024-10-09         |
|                     | (2015-10-19 to 2026-09-16)     |                    |
+---------------------+--------------------------------+--------------------+
| monitoring_tier     | Remote-monitoring contract     | No Contract        |
|                     | level                          |                    |
+---------------------+--------------------------------+--------------------+
```

```
+------------------+----------+
| monitoring_tier  | Machines |
+==================+==========+
| No Contract      |      234 |
+------------------+----------+
| Bronze           |      137 |
+------------------+----------+
| Silver           |      101 |
+------------------+----------+
| Gold             |       82 |
+------------------+----------+
| Platinum         |       83 |
| (highest)        |          |
+------------------+----------+
```

## sales_order: the top of the bill (order header)

**One row = one customer order.** 11,337 rows.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| order_id            | Internal ID; links to the      | 1756               |
|                     | order's lines                  |                    |
+---------------------+--------------------------------+--------------------+
| order_number        | Order number people see        | SO2001756          |
+---------------------+--------------------------------+--------------------+
| order_date          | When the customer ordered      | 2024-01-01         |
+---------------------+--------------------------------+--------------------+
| customer_id         | Who ordered -> dim_customer    | 43                 |
+---------------------+--------------------------------+--------------------+
| sales_rep_id        | Which salesperson (40 reps)    | REP009             |
+---------------------+--------------------------------+--------------------+
| order_type          | What kind of sale (see below)  | Aftermarket        |
+---------------------+--------------------------------+--------------------+
| order_status        | Where the order is now (see    | Closed             |
|                     | below)                         |                    |
+---------------------+--------------------------------+--------------------+
| ship_date           | When it left the factory;      | 2024-01-12         |
|                     | empty while Open or Cancelled  |                    |
+---------------------+--------------------------------+--------------------+
```

```
+--------------+------------------------------------+--------+
| order_type   | What is sold                       | Orders |
+==============+====================================+========+
| Capital      | Machines and molds                 |    160 |
+--------------+------------------------------------+--------+
| HotRunner    | Hot runners and controllers        |  1,100 |
+--------------+------------------------------------+--------+
| Aftermarket  | Spare parts                        |  9,000 |
+--------------+------------------------------------+--------+
| Service      | Monitoring contracts and services  |  1,077 |
+--------------+------------------------------------+--------+
```

```
+--------------+------------------------------------+--------+
| order_status | Meaning                            | Orders |
+==============+====================================+========+
| Open         | Ordered, not shipped yet (this is  |    428 |
|              | the BACKLOG)                       |        |
+--------------+------------------------------------+--------+
| Shipped      | Left the factory                   |    154 |
+--------------+------------------------------------+--------+
| Closed       | Complete                           | 10,528 |
+--------------+------------------------------------+--------+
| Cancelled    | Customer cancelled                 |    227 |
+--------------+------------------------------------+--------+
```

## sales_order_line: each item on the bill (order lines)

**One row = one product on one order.** 30,775 rows. An order has 1 to 5 lines.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| order_line_id       | Internal ID of the line        | 222                |
+---------------------+--------------------------------+--------------------+
| order_id            | Which order it belongs to ->   | 161                |
|                     | sales_order                    |                    |
+---------------------+--------------------------------+--------------------+
| line_number         | Position on that order: 1, 2,  | 1                  |
|                     | 3 ...                          |                    |
+---------------------+--------------------------------+--------------------+
| product_id          | What was sold -> dim_product   | 19 (Hot Runner     |
|                     |                                | Controller Multi)  |
+---------------------+--------------------------------+--------------------+
| quantity            | How many units                 | 2                  |
+---------------------+--------------------------------+--------------------+
| unit_list_price_usd | Catalogue price of one unit    | 56,000             |
+---------------------+--------------------------------+--------------------+
| discount_pct        | Discount as a fraction (0.038  | 0.038              |
|                     | = 3.8%)                        |                    |
+---------------------+--------------------------------+--------------------+
| net_amount_usd      | Line total = quantity x unit   | 2 x 56,000 x 0.962 |
|                     | price x (1 - discount)         | = 107,744          |
+---------------------+--------------------------------+--------------------+
```

`sales_order` + `sales_order_line` work like a shop bill: the header says *who
and when*, and each line says *what, how many and how much*.

## service_ticket: customer support cases

**One row = one support ticket about one machine.** 10,677 rows.

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| ticket_id           | Internal ID of the ticket      | 1                  |
+---------------------+--------------------------------+--------------------+
| ticket_number       | Ticket number people see       | TCK500001          |
+---------------------+--------------------------------+--------------------+
| machine_id          | Which machine has the problem  | 1                  |
|                     | -> dim_machine                 |                    |
+---------------------+--------------------------------+--------------------+
| customer_id         | Which customer -> dim_customer | 2                  |
+---------------------+--------------------------------+--------------------+
| opened_at           | Date and time the ticket was   | 2025-01-28 19:00   |
|                     | raised                         |                    |
+---------------------+--------------------------------+--------------------+
| closed_at           | Date and time it was solved;   | 2025-01-28 21:51   |
|                     | empty while Open (54 tickets)  |                    |
+---------------------+--------------------------------+--------------------+
| issue_category      | Type of problem (see below)    | Robot / Post-Mold  |
+---------------------+--------------------------------+--------------------+
| priority            | Urgency: P1 (urgent), P2, P3   | P1                 |
|                     | (low)                          |                    |
+---------------------+--------------------------------+--------------------+
| channel             | How the problem was reported   | Portal             |
|                     | (see below)                    |                    |
+---------------------+--------------------------------+--------------------+
| resolution_type     | How it was fixed (see below)   | Phone Support      |
+---------------------+--------------------------------+--------------------+
| status              | Open (54) or Closed (10,623)   | Closed             |
+---------------------+--------------------------------+--------------------+
| downtime_hours      | How long the machine was       | 2.33               |
|                     | stopped                        |                    |
+---------------------+--------------------------------+--------------------+
```

```
+-------------------------+----------------------------------+
| channel                 | Meaning                          |
+=========================+==================================+
| Phone                   | Customer called                  |
+-------------------------+----------------------------------+
| Email                   | Customer emailed                 |
+-------------------------+----------------------------------+
| Portal                  | Customer logged it online        |
+-------------------------+----------------------------------+
| Remote Monitoring Alert | Remote monitoring spotted the    |
|                         | problem                          |
+-------------------------+----------------------------------+
```

```
+------------------+----------------------------------------------+
| resolution_type  | Meaning                                      |
+==================+==============================================+
| Remote           | Engineer fixed it over the remote connection |
+------------------+----------------------------------------------+
| Phone Support    | Engineer talked the customer through it      |
+------------------+----------------------------------------------+
| Technician Visit | Engineer travelled to the plant              |
+------------------+----------------------------------------------+
```

```
+--------------------------+
| issue_category values    |
+==========================+
| Hot Runner Leak          |
+--------------------------+
| Heater Failure           |
+--------------------------+
| Hydraulic Pressure       |
+--------------------------+
| Robot / Post-Mold        |
+--------------------------+
| Controller Alarm         |
+--------------------------+
| Dimensional Quality      |
+--------------------------+
| Software / HMI           |
+--------------------------+
| Preventive Maintenance   |
+--------------------------+
```

Time to fix = `closed_at` − `opened_at`. The average over many tickets is
**MTTR** (mean time to repair).

## machine_daily_performance: one day of telemetry from one machine

**One row = one machine on one day.** 382,639 rows (from 2025-01-01).

```
+---------------------+--------------------------------+--------------------+
| Column              | What it means                  | Example            |
+=====================+================================+====================+
| machine_id          | Which machine -> dim_machine   | 4                  |
+---------------------+--------------------------------+--------------------+
| perf_date           | Which day                      | 2026-04-16         |
+---------------------+--------------------------------+--------------------+
| planned_hours       | Hours it was meant to run that | 24.00              |
|                     | day (usually 24)               |                    |
+---------------------+--------------------------------+--------------------+
| run_hours           | Hours it actually ran          | 20.03              |
+---------------------+--------------------------------+--------------------+
| ideal_rate_per_hour | Parts per hour at full speed   | 30,000             |
+---------------------+--------------------------------+--------------------+
| total_parts         | Parts produced                 | 529,530            |
+---------------------+--------------------------------+--------------------+
| good_parts          | Parts with no defects          | 523,581            |
+---------------------+--------------------------------+--------------------+
| scrap_parts         | Rejected parts (total - good)  | 5,949              |
+---------------------+--------------------------------+--------------------+
```

These columns feed **OEE** (overall equipment effectiveness), the standard score
for how well a machine is used. Worked example for the day above:

```
+--------------+--------------------------------+----------------------------+
| Part         | Formula                        | Example day                |
+==============+================================+============================+
| Availability | run_hours / planned_hours      | 20.03 / 24 = 83%           |
+--------------+--------------------------------+----------------------------+
| Performance  | total_parts / (run_hours x     | 529,530 / (20.03 x 30,000) |
|              | ideal_rate_per_hour)           | = 88%                      |
+--------------+--------------------------------+----------------------------+
| Quality      | good_parts / total_parts       | 523,581 / 529,530 = 99%    |
+--------------+--------------------------------+----------------------------+
| OEE          | Availability x Performance x   | 0.83 x 0.88 x 0.99 = 72%   |
|              | Quality                        |                            |
+--------------+--------------------------------+----------------------------+
```

## See it yourself in SSMS

```
+------------------------+--------------------------------------------------+
| To do this             | In SSMS                                          |
+========================+==================================================+
| List a table's columns | Object Explorer > SalesServiceBI > Tables >      |
|                        | raw.dim_customer > Columns                       |
+------------------------+--------------------------------------------------+
| See real rows          | Right-click a table > Select Top 1000 Rows       |
+------------------------+--------------------------------------------------+
```
