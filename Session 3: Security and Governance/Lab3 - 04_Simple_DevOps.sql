/***************************************************************************************************
| S | N | O | W | F | L | A | K | E |   | E | V | A | L |   | S | I | M | P | L | E |   | D | E | V | O | P | S |

Demo:         Snowflake Evaluation - Simple DevOps with Cloning and Time Travel
Create Date:  2025-06-15
Purpose:      Demonstrate Snowflake zero-copy cloning and Time Travel for development workflows
Target Table: SNOWFLAKE_EVAL.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE
****************************************************************************************************

****************************************************************************************************
SUMMARY OF FEATURES
- Zero-Copy Database Cloning for Development Environment
- Developer Role and Privilege Management
- Time Travel for Data Recovery
- Query History Analysis
- Development Workflow Best Practices
***************************************************************************************************/

/*----------------------------------------------------------------------------------
Step 1 - Create Development Environment Using Zero-Copy Cloning

Zero-copy cloning creates a copy of a database, schema or table without duplicating 
the actual data. A snapshot of data present in the source object is taken when the 
clone is created and is made available to the cloned object.

Key Benefits:
- Instant database duplication
- No additional storage cost initially
- Independent writable copy for development
- Safe testing environment
----------------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

-- Create development database as clone of production
CREATE OR REPLACE DATABASE SNOWFLAKE_EVAL_DEV CLONE SNOWFLAKE_EVAL;
    /*---
         • ZERO COPY CLONING: Creates a copy of a database, schema or table. A snapshot of data present in
            the source object is taken when the clone is created and is made available to the cloned object. 
           
            The cloned object is writable and is independent of the clone source. That is, changes made to
            either the source object or the clone object are not part of the other. Cloning a database will
            clone all the schemas and tables within that database. Cloning a schema will clone all the
            tables in that schema.
      ---*/

-- ****** 
-- here we are showing the sizes of the tables that we've just created, as well as the cloned table
-- we can see that the cloned tables takes up no storage!
SELECT Table_name, clone_group_id, TABLE_CREATED,
((ACTIVE_BYTES/1024)) AS STORAGE_USAGE_KB
FROM SNOWFLAKE_EVAL_DEV.INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE TABLE_NAME like 'TA_APPLICATION_DATA_BRONZE'
order by TABLE_CREATED desc
limit 1;

/*---------------------------------------------------------
1. Create the developer role
---------------------------------------------------------*/
CREATE ROLE IF NOT EXISTS EVAL_DEV;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE EVAL_DEV;

GRANT USAGE ON DATABASE SNOWFLAKE_EVAL_DEV                TO ROLE EVAL_DEV;
GRANT USAGE ON ALL SCHEMAS    IN DATABASE SNOWFLAKE_EVAL_DEV  TO ROLE EVAL_DEV;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE SNOWFLAKE_EVAL_DEV  TO ROLE EVAL_DEV;
-- Existing objects
GRANT SELECT ON ALL TABLES      IN DATABASE SNOWFLAKE_EVAL_DEV TO ROLE EVAL_DEV;
GRANT ALL PRIVILEGES ON ALL TABLES      IN DATABASE SNOWFLAKE_EVAL_DEV TO ROLE EVAL_DEV;
GRANT ALL PRIVILEGES ON ALL VIEWS       IN DATABASE SNOWFLAKE_EVAL_DEV TO ROLE EVAL_DEV;

-- Capture the current Snowflake user in a session variable
SET CURRENT_EXEC_USER = CURRENT_USER();
GRANT ROLE EVAL_DEV TO USER IDENTIFIER($CURRENT_EXEC_USER);

use role eval_dev;
select top 10 * from SNOWFLAKE_EVAL.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE;
select top 10 * from SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE;
TRUNCATE SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE;
-- oh no! we made a mistake on the TRUNCATION.
-- thankfully we can use Time Travel to revert our table back to before that second update. 

     /*---
        TIME-TRAVEL: enables accessing historical data (i.e. data that has been changed or deleted) at any point within
          a defined period. It serves as a powerful tool for performing the following tasks:
          - Restoring data-related objects (tables, schemas, and databases) that might have been accidentally or intentionally deleted.
          - Duplicating and backing up data from key points in the past.
          - Analyzing data usage/manipulation over specified periods of time.
      ---*/

-- to retrieve the query_id for the bad TRUNCATE statement, let's use the QUERY_HISTORY() function 
USE ROLE ACCOUNTADMIN;
SELECT 
    query_id,
    query_text,
    user_name,
    query_type,
    start_time
FROM TABLE(SNOWFLAKE_EVAL_DEV.information_schema.query_history())
WHERE 1=1
    AND query_type = 'TRUNCATE_TABLE'
    AND query_text LIKE '%SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE%'
ORDER BY start_time DESC;

-- now we will create a SQL variable and SET it to the QUERY_ID for the TRUNCATE statement 
SET query_id = 
    (
    SELECT TOP 1
        query_id
    FROM TABLE(SNOWFLAKE_EVAL_DEV.information_schema.query_history())
    WHERE 1=1
        AND query_type = 'TRUNCATE_TABLE'
        AND query_text LIKE '%SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE%'
    ORDER BY start_time DESC
    );

-- using our QUERY_ID variable we will now use the BEFORE(STATEMENT =>) function to revert our table
-- to what it looked like before the TRUNCATION statement
CREATE OR REPLACE TABLE SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE
    AS 
SELECT * FROM SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE
BEFORE(STATEMENT => $query_id); -- revert to before a specified QUERY_ID ran

SELECT TOP 10 * FROM SNOWFLAKE_EVAL_DEV.DATA_ENGINEERING.TA_APPLICATION_DATA_BRONZE;

-- ******
SELECT Table_name, clone_group_id, TABLE_CREATED,
((ACTIVE_BYTES/1024)) AS STORAGE_USAGE_KB
FROM SNOWFLAKE_EVAL_DEV.INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE TABLE_NAME like 'TA_APPLICATION_DATA_BRONZE'
order by TABLE_CREATED desc
limit 1;