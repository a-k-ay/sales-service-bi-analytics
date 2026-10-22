/* =====================================================================
   02 - Load the CSV files
   1. Change @path below to the folder where the CSVs are on YOUR laptop.
   2. The SQL Server service account must be able to read that folder.
      If BULK INSERT says "access denied", copy the data folder to
      C:\SalesServiceBI\data\ (simplest) or use the SSMS Import Flat File wizard.
   ===================================================================== */
USE SalesServiceBI;
GO
DECLARE @path NVARCHAR(260) = N'C:\SalesServiceBI\data\';   -- <<< change if needed (keep the trailing \)
DECLARE @t TABLE (tbl SYSNAME);
INSERT @t VALUES ('dim_region'),('dim_customer'),('dim_product'),('dim_machine'),
                 ('sales_order'),('sales_order_line'),('service_ticket'),('machine_daily_performance');

DECLARE @tbl SYSNAME, @sql NVARCHAR(MAX);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT tbl FROM @t;
OPEN c; FETCH NEXT FROM c INTO @tbl;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'TRUNCATE TABLE raw.' + QUOTENAME(@tbl) + N';
BULK INSERT raw.' + QUOTENAME(@tbl) + N'
FROM ''' + @path + @tbl + N'.csv''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', CODEPAGE = ''65001'',
      FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0a'', KEEPNULLS, TABLOCK);';
    EXEC sp_executesql @sql;
    FETCH NEXT FROM c INTO @tbl;
END
CLOSE c; DEALLOCATE c;
GO

-- quick row-count check (expected numbers are in README.md)
SELECT 'dim_region' AS tbl, COUNT(*) AS rows_loaded FROM raw.dim_region UNION ALL
SELECT 'dim_customer', COUNT(*) FROM raw.dim_customer UNION ALL
SELECT 'dim_product', COUNT(*) FROM raw.dim_product UNION ALL
SELECT 'dim_machine', COUNT(*) FROM raw.dim_machine UNION ALL
SELECT 'sales_order', COUNT(*) FROM raw.sales_order UNION ALL
SELECT 'sales_order_line', COUNT(*) FROM raw.sales_order_line UNION ALL
SELECT 'service_ticket', COUNT(*) FROM raw.service_ticket UNION ALL
SELECT 'machine_daily_performance', COUNT(*) FROM raw.machine_daily_performance;
