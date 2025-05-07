/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Load existing YouTube data as a hypertable.
 */



-- IMPORT YOUTUBE DATA INTO NEW TABLE

DROP TABLE IF EXISTS youtube_ts;

CREATE TABLE youtube_ts AS
SELECT * FROM youtube;

ALTER TABLE youtube_ts
DROP CONSTRAINT IF EXISTS youtube_ts_pkey,
-- The "timestamp" column is required for partitioning
ADD PRIMARY KEY ("timestamp", videostatsid);



-- DETERMINE TEMPORAL CHUNK SIZE

-- Video count range per day, week and month, and average row size in MB
-- We only look at the last 6 months of data, to simulate what we would
-- do with larger data.
WITH recent_months AS (
    SELECT DISTINCT date_trunc('month', "timestamp")::date AS month_start
    FROM youtube_ts
    ORDER BY month_start DESC
    LIMIT 6
),
yt_sample AS (
    SELECT *
    FROM youtube_ts
    WHERE date_trunc('month', "timestamp")::date IN (
        SELECT month_start FROM recent_months
    )
),
stats AS (
    SELECT
        0 AS ord,
        'day' AS "period",
        min(n) AS min_n,
        max(n) AS max_n,
        round(avg(size_mb)::numeric, 4) AS avg_size_mb
    FROM (
        SELECT
            "timestamp"::date AS "date",
            count(*) AS n,
            sum(pg_column_size(y)) / power(1024, 2) AS size_mb
        FROM yt_sample y
        GROUP BY "date"
    )

    UNION

    SELECT
        1 AS ord,
        'week' AS "period",
        min(n) AS min_n,
        max(n) AS max_n,
        round(avg(size_mb)::numeric, 4) AS avg_size_mb
    FROM (
        SELECT
            date_trunc('week', "timestamp") AS week_start,
            count(*) AS n,
            sum(pg_column_size(y)) / power(1024, 2) AS size_mb
        FROM yt_sample y
        GROUP BY week_start
    )

    UNION

    SELECT
        2 AS ord,
        'month' AS "period",
        min(n) AS min_n,
        max(n) AS max_n,
        round(avg(size_mb)::numeric, 4) AS avg_size_mb
    FROM (
        SELECT
            date_trunc('month', "timestamp") AS month_start,
            count(*) AS n,
            sum(pg_column_size(y)) / power(1024, 2) AS size_mb
        FROM yt_sample y
        GROUP BY month_start
    )
)
SELECT "period", min_n, max_n, avg_size_mb
FROM stats
ORDER BY ord;



-- ADJUST TABLE TYPES FOR PERFORMANCE

ALTER TABLE youtube_ts
    -- Switch to bigints to integers to save memory (range allows it)
    ALTER COLUMN videostatsid TYPE integer,
    ALTER COLUMN views TYPE integer,
    ALTER COLUMN comments TYPE integer,
    ALTER COLUMN likes TYPE integer,
    ALTER COLUMN dislikes TYPE integer,

    -- Switch to fixed size text types
    ALTER COLUMN ytvideoid TYPE char(11),

    -- Switch to timestamp with time zone set to UTC
    ALTER COLUMN "timestamp" TYPE timestamp with time zone
        USING "timestamp" AT TIME ZONE 'UTC';



-- CREATE HYPERTABLE

-- We partition by month, which results in tiny chunk sizes of
-- approximately 10 MiB, as rows in the sample data only contain
-- a few columns.

-- The official recommendation is to prioritize an interval resulting
-- in a chunk size that fits into 25% of memory, including indexes.

SELECT create_hypertable(
    'youtube_ts',
    by_range('timestamp', INTERVAL '1 month'),
    migrate_data => TRUE
);
