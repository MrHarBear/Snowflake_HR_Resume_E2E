use role accountadmin;
use database snowflake_eval;
use schema data_engineering;

create or replace table snowflake_eval.data_engineering.doc_ai_resume as
SELECT
    RELATIVE_PATH,
    '@DATA_ENGINGEERING.CVS/Product Managers' AS STAGE,
    SNOWFLAKE_EVAL.DATA_ENGINEERING.DOC_AI_RESUME!PREDICT(
        GET_PRESIGNED_URL(
            '@DATA_ENGINEERING.CVS',
            RELATIVE_PATH
        ),
        1
    ) METADATA
FROM
    DIRECTORY ('@CVS')
    where startswith(relative_path, 'Product Managers/');

select * from snowflake_eval.data_engineering.doc_ai_resume;
