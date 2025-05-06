/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Time series or real-time specific query features.
 */



-- TIME BUCKET AND GAP FILLING

-- Temporal coverage
SELECT min("timestamp"), max("timestamp")
FROM youtube_ts;


-- Are there any gaps on daily values?
SELECT
    time_bucket_gapfill('1 day', "timestamp") AS bucket,
    avg(views) AS avg_views
FROM youtube_ts
WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
GROUP BY bucket
ORDER BY bucket;


-- Fill-in gaps using two different methods
SELECT
    time_bucket_gapfill('1 day', "timestamp") AS bucket,
    avg(views)::double precision AS avg_views,
    interpolate(
        avg(views)::double precision,
        (
            SELECT ("timestamp", views::double precision)
            FROM youtube_ts
            WHERE "timestamp" >= '2019-04-15'
            ORDER BY "timestamp"
            LIMIT 1
        ),
        (
            SELECT ("timestamp", views::double precision)
            FROM youtube_ts
            WHERE "timestamp" <= '2020-04-15'
            ORDER BY "timestamp" DESC
            LIMIT 1
        )

    ) AS inter_avg_views,
    locf(avg(views)::double precision) AS carried_avg_views
FROM youtube_ts
WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
GROUP BY bucket
ORDER BY bucket;



-- CONTINUOUS AGGREGATES (INCREMENTAL MATERIALIZED VIEWS)

-- Create the continuous aggregate

DROP MATERIALIZED VIEW IF EXISTS weekly_totals;

CREATE MATERIALIZED VIEW weekly_totals(
    bucket,
    views,
    comments,
    likes,
    dislikes,
    likes_share,
    dislikes_share
)
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 week', "timestamp") AS bucket,
    sum(views),
    sum(comments),
    sum(likes),
    sum(dislikes),
    sum(likes) / sum(likes + dislikes)::double precision,
    sum(dislikes) / sum(likes + dislikes)::double precision
FROM youtube_ts
GROUP BY bucket
ORDER BY bucket;

SELECT * FROM weekly_totals;


-- Manual refresh for a temporal window (year 2020)

CALL refresh_continuous_aggregate('weekly_totals', '2020-01-01', '2020-12-31');


-- Automatic refresh for a month of data, up to the previous hour, every hour

SELECT remove_continuous_aggregate_policy('weekly_totals', if_exists => TRUE);

SELECT add_continuous_aggregate_policy(
    'weekly_totals',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Soon after the CA policy is set, we should see a job for it.
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
WHERE j.proc_name = 'policy_refresh_continuous_aggregate';

-- We can also set separate compression and retention policies for views.

ALTER MATERIALIZED VIEW weekly_totals SET (timescaledb.compress);
SELECT remove_compression_policy('weekly_totals', if_exists => TRUE);
SELECT add_compression_policy('weekly_totals', INTERVAL '3 months');

SELECT remove_retention_policy('weekly_totals', if_exists => TRUE);
SELECT add_retention_policy('weekly_totals', INTERVAL '1 year');



-- HYPERFUNCTIONS
-- https://docs.timescale.com/api/latest/hyperfunctions/

-- Downsample
-- TODO

WITH yt_sample AS (
    SELECT
        time_bucket('1 hour', "time") AS bucket,
        sum("value"::integer) AS comments
    FROM unnest((
        SELECT lttb(
            "timestamp",
            comments,
            -- 10% sample size
            (SELECT (count(*) * 0.10)::integer FROM youtube_ts)
        )
        FROM youtube_ts
    ))
    GROUP BY bucket
),
yt_original AS (
    SELECT
        time_bucket('1 hour', "timestamp") AS bucket,
        sum(comments) AS comments
    FROM youtube_ts
    GROUP BY bucket
)
SELECT
    date_trunc('week', bucket) AS week_start,
    sum(o.comments) AS o_comments,
    sum(s.comments) AS s_comments
FROM yt_sample s
JOIN yt_original o
USING (bucket)
GROUP BY week_start
ORDER BY week_start
LIMIT 100;
