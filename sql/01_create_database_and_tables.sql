/* =====================================================================
   01 - Create database and RAW tables (SQL Server 2019+/2022, Express OK)
   Raw tables mirror the ERP extracts exactly: no foreign keys, because
   the source data has quality issues we want to FIND, not hide.
   ===================================================================== */
IF DB_ID('SalesServiceBI') IS NULL
    CREATE DATABASE SalesServiceBI;
GO
USE SalesServiceBI;
GO
IF SCHEMA_ID('raw') IS NULL EXEC('CREATE SCHEMA raw');
GO
IF SCHEMA_ID('bi')  IS NULL EXEC('CREATE SCHEMA bi');
GO

DROP TABLE IF EXISTS raw.dim_region, raw.dim_customer, raw.dim_product, raw.dim_machine,
                     raw.sales_order, raw.sales_order_line, raw.service_ticket,
                     raw.machine_daily_performance;
GO

CREATE TABLE raw.dim_region (
    region_code        VARCHAR(10)   NOT NULL,
    region_name        VARCHAR(50)   NOT NULL,
    super_region       VARCHAR(20)   NOT NULL,
    service_center_tz  VARCHAR(40)   NULL
);

CREATE TABLE raw.dim_customer (
    customer_id        INT           NOT NULL,
    customer_number    VARCHAR(20)   NOT NULL,
    customer_name      NVARCHAR(120) NOT NULL,
    industry_segment   VARCHAR(30)   NULL,
    account_tier       VARCHAR(20)   NULL,
    country            NVARCHAR(60)  NULL,
    region_code        VARCHAR(10)   NULL,
    created_date       DATE          NULL
);

CREATE TABLE raw.dim_product (
    product_id         INT           NOT NULL,
    product_code       VARCHAR(20)   NOT NULL,
    product_name       NVARCHAR(80)  NOT NULL,
    product_family     VARCHAR(30)   NULL,
    product_type       VARCHAR(20)   NULL,   -- System, Mold, HotRunner, Controller, Part, Service
    industry           VARCHAR(30)   NULL,
    list_price_usd     DECIMAL(14,2) NULL,
    std_cost_usd       DECIMAL(14,2) NULL,
    is_active          BIT           NULL
);

CREATE TABLE raw.dim_machine (               -- installed base
    machine_id         INT           NOT NULL,
    serial_number      VARCHAR(20)   NOT NULL,
    customer_id        INT           NULL,
    product_id         INT           NULL,
    install_date       DATE          NULL,
    monitoring_tier    VARCHAR(20)   NULL    -- No Contract / Bronze / Silver / Gold / Platinum
);

CREATE TABLE raw.sales_order (
    order_id           INT           NOT NULL,
    order_number       VARCHAR(20)   NOT NULL,
    order_date         DATE          NOT NULL,
    customer_id        INT           NULL,
    sales_rep_id       VARCHAR(10)   NULL,
    order_type         VARCHAR(20)   NULL,   -- Capital, HotRunner, Aftermarket, Service
    order_status       VARCHAR(20)   NULL,
    ship_date          DATE          NULL
);

CREATE TABLE raw.sales_order_line (
    order_line_id       INT           NOT NULL,
    order_id            INT           NOT NULL,
    line_number         INT           NOT NULL,
    product_id          INT           NULL,
    quantity            INT           NULL,
    unit_list_price_usd DECIMAL(14,2) NULL,
    discount_pct        DECIMAL(6,3)  NULL,
    net_amount_usd      DECIMAL(16,2) NULL
);

CREATE TABLE raw.service_ticket (
    ticket_id          INT           NOT NULL,
    ticket_number      VARCHAR(20)   NOT NULL,
    machine_id         INT           NULL,
    customer_id        INT           NULL,
    opened_at          DATETIME2(0)  NULL,
    closed_at          DATETIME2(0)  NULL,
    issue_category     VARCHAR(40)   NULL,
    priority           VARCHAR(5)    NULL,
    channel            VARCHAR(30)   NULL,
    resolution_type    VARCHAR(30)   NULL,
    status             VARCHAR(10)   NULL,
    downtime_hours     DECIMAL(8,2)  NULL
);

CREATE TABLE raw.machine_daily_performance (  -- telemetry from the remote-monitoring service
    machine_id          INT           NOT NULL,
    perf_date           DATE          NOT NULL,
    planned_hours       DECIMAL(5,2)  NULL,
    run_hours           DECIMAL(5,2)  NULL,
    ideal_rate_per_hour INT           NULL,
    total_parts         BIGINT        NULL,
    good_parts          BIGINT        NULL,
    scrap_parts         BIGINT        NULL
);
GO
