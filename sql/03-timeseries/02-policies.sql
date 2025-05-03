/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Specify storage policies.
 */



-- ENABLE COMPRESSION

-- Setting timescaledb.compress_segmentby is usually recommended as well,
-- but we don't have a column we can segment by, as records are independent
-- here.
ALTER TABLE youtube_ts
SET (timescaledb.compress);

-- This will trigger compression when the latest timestamp in a chunk
-- is older than 1 month.
SELECT add_compression_policy('youtube_ts', INTERVAL '1 month');



-- SET A RETENTION POLICY

-- Check records before changing the retention
SELECT
    count(*) AS n,
    min("timestamp") AS since,
    max("timestamp") AS until
FROM youtube_ts;

-- Our data is from 2019, so if it's not 2029 yet, it will be kept.
SELECT remove_retention_policy('youtube_ts', if_exists => TRUE);
SELECT add_retention_policy('youtube_ts', INTERVAL '10 years');

-- Soon after the retention policy is set, we should see a job for it.
SELECT
    j.hypertable_name,
    j.job_id,
    config,
    schedule_interval,
    job_status,
    last_run_status,
    last_run_started_at,
    js.next_start,
    total_runs,
    total_successes,
    total_failures
FROM timescaledb_information.jobs j
JOIN timescaledb_information.job_stats js
ON j.job_id = js.job_id
WHERE j.proc_name = 'policy_retention';

-- Assuming the job ran, let's make sure our data wasn't erased yet.
SELECT
    count(*) AS n,
    min("timestamp") AS since,
    max("timestamp") AS until
FROM youtube_ts;

-- Let's change the policy to delete six months of data.
SELECT remove_retention_policy('youtube_ts', if_exists => TRUE);
WITH interval AS (
    -- This just returns the proper interval for testing.
    SELECT age(now(), max("timestamp") - INTERVAL '6 months') AS val
    FROM youtube_ts
)
SELECT add_retention_policy('youtube_ts', val)
FROM interval;

-- The job should be run once recreated, but, if not, we can force it to run.
DO $$
DECLARE
    jid int;
BEGIN
    SELECT job_id
    INTO jid
    FROM timescaledb_information.jobs
    WHERE proc_name = 'policy_retention'
        AND hypertable_name = 'youtube_ts'
    LIMIT 1;

    CALL run_job(jid);
END;
$$;

-- We should have about half the data we had before.
SELECT
    count(*) AS n,
    min("timestamp") AS since,
    max("timestamp") AS until
FROM youtube_ts;

-- Disable the retention policy.
SELECT remove_retention_policy('youtube_ts', if_exists => TRUE);

-- Insert missing data back.
INSERT INTO youtube_ts (
    videostatsid,
    ytvideoid,
    views,
    comments,
    likes,
    dislikes,
    "timestamp"
)
SELECT
    videostatsid::integer,
    ytvideoid::character(11),
    views::integer,
    comments::integer,
    likes::integer,
    dislikes::integer,
    "timestamp" AT TIME ZONE 'UTC'
FROM youtube
ON CONFLICT DO NOTHING;

-- We should be back to the original dataset
SELECT
    count(*) AS n,
    min("timestamp") AS since,
    max("timestamp") AS until
FROM youtube_ts;
