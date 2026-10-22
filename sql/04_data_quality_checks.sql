/* =====================================================================
   04 - DATA QUALITY RULES  (Skill: "establish data quality metrics",
        "ensuring that quality standards are met", "Master Data Management")
   Each rule returns: rule id, dimension, table, failed rows, total rows.
   Save this as a view so a Power BI "Data Quality" page can show trends.
   Eight issues were planted on purpose; can you find all eight?
   ===================================================================== */
USE SalesServiceBI;
GO

/* ---------- reference data (MDM): the single source of truth for countries ----------
   Region is DERIVED from country through this list, never typed by hand.
   05 uses these tables to clean bi.dim_customer. */
DROP TABLE IF EXISTS bi.ref_country_region;
CREATE TABLE bi.ref_country_region (
    country      NVARCHAR(60) NOT NULL PRIMARY KEY,
    region_code  VARCHAR(10)  NOT NULL
);
INSERT bi.ref_country_region (country, region_code) VALUES
    ('Canada','NA'), ('United States','NA'), ('Mexico','NA'),
    ('Brazil','LATAM'), ('Argentina','LATAM'), ('Colombia','LATAM'), ('Chile','LATAM'),
    ('Germany','EU'), ('France','EU'), ('Italy','EU'), ('Poland','EU'), ('Spain','EU'),
    ('United Kingdom','EU'),
    ('United Arab Emirates','MEA'), ('Saudi Arabia','MEA'), ('Egypt','MEA'),
    ('South Africa','MEA'), ('Nigeria','MEA'),
    ('India','IND'), ('Bangladesh','IND'), ('Sri Lanka','IND'), ('Pakistan','IND'),
    ('Thailand','SEA'), ('Vietnam','SEA'), ('Indonesia','SEA'), ('Philippines','SEA'),
    ('China','CNA'), ('Japan','CNA'), ('South Korea','CNA');

-- known non-standard spellings seen in the source, mapped to the standard name
DROP TABLE IF EXISTS bi.ref_country_alias;
CREATE TABLE bi.ref_country_alias (
    alias    NVARCHAR(60) COLLATE Latin1_General_CS_AS NOT NULL PRIMARY KEY,
    country  NVARCHAR(60) NOT NULL
);
INSERT bi.ref_country_alias (alias, country) VALUES
    ('USA','United States'), ('U.S.A.','United States'), ('UAE','United Arab Emirates'),
    ('india','India'), ('Deutschland','Germany'), ('KSA','Saudi Arabia'),
    ('Viet Nam','Vietnam'), ('UK','United Kingdom');
GO

CREATE OR ALTER VIEW bi.vw_data_quality_results AS
SELECT 'DQ01' AS rule_id, 'Uniqueness'   AS dq_dimension, 'dim_customer' AS table_name,
       'Duplicate customer (same normalised name)' AS rule_desc,
       (SELECT COUNT(*) FROM (SELECT UPPER(REPLACE(customer_name,'LIMITED','LTD')) n
                              FROM raw.dim_customer GROUP BY UPPER(REPLACE(customer_name,'LIMITED','LTD'))
                              HAVING COUNT(*) > 1) d) AS failed_rows,
       (SELECT COUNT(*) FROM raw.dim_customer) AS total_rows
UNION ALL
SELECT 'DQ02', 'Validity', 'dim_customer', 'Country not in approved list',
       (SELECT COUNT(*) FROM raw.dim_customer
        -- case-sensitive: the default collation treats 'india' = 'India', so the typo would slip through
        WHERE country COLLATE Latin1_General_CS_AS NOT IN
              (SELECT country COLLATE Latin1_General_CS_AS FROM bi.ref_country_region)),
       (SELECT COUNT(*) FROM raw.dim_customer)
UNION ALL
SELECT 'DQ03', 'Completeness', 'dim_customer', 'Missing account tier',
       (SELECT COUNT(*) FROM raw.dim_customer WHERE account_tier IS NULL),
       (SELECT COUNT(*) FROM raw.dim_customer)
UNION ALL
SELECT 'DQ04', 'Referential integrity', 'sales_order_line', 'Product not in product master',
       (SELECT COUNT(*) FROM raw.sales_order_line l
        WHERE NOT EXISTS (SELECT 1 FROM raw.dim_product p WHERE p.product_id = l.product_id)),
       (SELECT COUNT(*) FROM raw.sales_order_line)
UNION ALL
SELECT 'DQ05', 'Validity', 'sales_order_line', 'Quantity <= 0',
       (SELECT COUNT(*) FROM raw.sales_order_line WHERE quantity <= 0),
       (SELECT COUNT(*) FROM raw.sales_order_line)
UNION ALL
SELECT 'DQ06', 'Uniqueness', 'service_ticket', 'Duplicate ticket_id rows',
       (SELECT COUNT(*) - COUNT(DISTINCT ticket_id) FROM raw.service_ticket),
       (SELECT COUNT(*) FROM raw.service_ticket)
UNION ALL
SELECT 'DQ07', 'Consistency', 'service_ticket', 'Closed before opened',
       (SELECT COUNT(*) FROM raw.service_ticket WHERE closed_at < opened_at),
       (SELECT COUNT(*) FROM raw.service_ticket)
UNION ALL
SELECT 'DQ08', 'Validity', 'machine_daily_performance', 'good_parts > total_parts or null run_hours',
       (SELECT COUNT(*) FROM raw.machine_daily_performance WHERE good_parts > total_parts OR run_hours IS NULL),
       (SELECT COUNT(*) FROM raw.machine_daily_performance)
UNION ALL
SELECT 'DQ09', 'Consistency', 'dim_customer', 'Region does not match the country',
       (SELECT COUNT(*) FROM raw.dim_customer c
        LEFT JOIN bi.ref_country_alias a ON a.alias = c.country COLLATE Latin1_General_CS_AS
        JOIN bi.ref_country_region r ON r.country = COALESCE(a.country, c.country)
        WHERE r.region_code <> c.region_code),
       (SELECT COUNT(*) FROM raw.dim_customer);
GO

SELECT *, CAST(100.0 * (total_rows - failed_rows) / NULLIF(total_rows,0) AS DECIMAL(6,2)) AS pass_rate_pct
FROM bi.vw_data_quality_results
ORDER BY rule_id;
