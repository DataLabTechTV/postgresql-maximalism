/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Time series or real-time specific query features.
 */



-- TIME BUCKET AND GAP FILLING
-- Note: we're ignoring ytvideoid for this example, but, in a real-world scenario, a
-- better approach would be to consider only the last record of the day, per video.

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

-- Create the continuous aggregates

DROP MATERIALIZED VIEW IF EXISTS youtube_ts_weekly_stats CASCADE;

CREATE MATERIALIZED VIEW youtube_ts_weekly_stats(
    bucket,
    ytvideoid,
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
    ytvideoid,
    last(views, "timestamp"),
    last(comments, "timestamp"),
    last(likes, "timestamp"),
    last(dislikes, "timestamp"),
    last(likes, "timestamp") / (
            last(likes, "timestamp") +
            last(dislikes, "timestamp")
        )::double precision,
    last(dislikes, "timestamp") / (
            last(likes, "timestamp") +
            last(dislikes, "timestamp")
        )::double precision
FROM youtube_ts
GROUP BY time_bucket('1 week', "timestamp"), ytvideoid
ORDER BY bucket, ytvideoid;

SELECT * FROM youtube_ts_weekly_stats;


DROP MATERIALIZED VIEW IF EXISTS youtube_ts_weekly_totals;

CREATE MATERIALIZED VIEW youtube_ts_weekly_totals(
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
    time_bucket('1 week', bucket) AS bucket,
    sum(views),
    sum(comments),
    sum(likes),
    sum(dislikes),
    sum(likes) / sum(likes + dislikes)::double precision,
    sum(dislikes) / sum(likes + dislikes)::double precision
FROM youtube_ts_weekly_stats
GROUP BY time_bucket('1 week', bucket)
ORDER BY bucket;

SELECT * FROM youtube_ts_weekly_totals;



-- Manual refresh for a temporal window (year 2020)
-- Note: manually refresh dependent CAs first

CALL refresh_continuous_aggregate(
    'youtube_ts_weekly_stats',
    '2020-01-01',
    '2020-12-31'
);

CALL refresh_continuous_aggregate(
    'youtube_ts_weekly_totals',
    '2020-01-01',
    '2020-12-31'
);



-- Automatic refresh for a month of data, up to the previous hour, every hour

SELECT remove_continuous_aggregate_policy(
    'youtube_ts_weekly_stats',
    if_exists => TRUE
);

SELECT add_continuous_aggregate_policy(
    'youtube_ts_weekly_stats',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

SELECT remove_continuous_aggregate_policy(
    'youtube_ts_weekly_totals',
    if_exists => TRUE
);

SELECT add_continuous_aggregate_policy(
    'youtube_ts_weekly_totals',
    start_offset => INTERVAL '1 month',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);


-- Soon after the CA policies are set, we should see a refresh job for each CA.
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


-- We can also set separate compression and retention policies for CAs.

ALTER MATERIALIZED VIEW youtube_ts_weekly_stats SET (timescaledb.compress);
SELECT remove_compression_policy('youtube_ts_weekly_stats', if_exists => TRUE);
SELECT add_compression_policy('youtube_ts_weekly_stats', INTERVAL '3 months');

SELECT remove_retention_policy('youtube_ts_weekly_stats', if_exists => TRUE);
SELECT add_retention_policy('youtube_ts_weekly_stats', INTERVAL '10 years');



-- HYPERFUNCTIONS
-- https://docs.timescale.com/api/latest/hyperfunctions/

-- Downsample/smoothing of no. comments
-- See companion notebook for plots

DROP FUNCTION IF EXISTS youtube_weekly_smoothed_comments;

CREATE OR REPLACE FUNCTION youtube_weekly_smoothed_comments()
RETURNS TABLE (
    week_start date,
    orig_comments bigint,
    lttb_comments bigint,
    asap_comments bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH yt_original AS (
        SELECT
            bucket,
            sum(comments)::integer AS comments
        FROM youtube_ts_weekly_stats
        GROUP BY bucket
    ),
    yt_lttb AS (
        SELECT
            time_bucket('1 week', "time") AS bucket,
            sum("value")::integer AS comments
        FROM unnest((
            SELECT lttb(
                bucket,
                comments,
                -- 10% sample size
                (SELECT (count(*) * 0.10)::integer FROM youtube_ts_weekly_stats)
            )
            FROM youtube_ts_weekly_stats
        ))
        GROUP BY bucket
    ),
    yt_asap AS (
        SELECT
            time_bucket('1 week', "time") AS bucket,
            sum("value")::integer AS comments
        FROM unnest((
            SELECT asap_smooth(
                bucket,
                comments,
                -- 10% sample size
                (SELECT (count(*) * 0.10)::integer FROM youtube_ts)
            )
            FROM youtube_ts_weekly_stats
        ))
        GROUP BY bucket
    )
    SELECT
        date_trunc('week', bucket)::date AS week_start,
        sum(o.comments) AS orig_comments,
        sum(l.comments) AS lttb_comments,
        sum(a.comments) AS asap_comments
    FROM yt_original o
    JOIN yt_lttb l
    USING (bucket)
    JOIN yt_asap a
    USING (bucket)
    GROUP BY week_start
    ORDER BY week_start;
END;
$$ LANGUAGE 'plpgsql';

SELECT * FROM youtube_weekly_smoothed_comments();


-- Histogram of likes
-- Returns counts for setup intervals

SELECT
    unnest(
        histogram(
            likes,
            1000,       -- (-Inf; 1000)
            1000000,    -- [3,000,000, +Inf)
            50          -- approximate no. bins
        )
    ) AS bin_count
FROM youtube_ts_weekly_stats;
