/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Detecting anomalous days in terms of views.
 */

-- Inspiration: https://medium.com/booking-com-development/anomaly-detection-in-time-series-using-statistical-analysis-cc587b21d008
--
-- Steps for a single day of the current week being tested:
--
-- 0. Compute mean and stdev for each existing week.
-- 1. Compute four z-scores, based on the previous four weeks.
-- 2. Normalize absolute z-scores and exclude weeks with a normalized z-score outside of a 0.6 range of the median normalized z-score.
-- 3. Compute a single absolute z-score based on the mean/stdev of the selected weeks.
-- 4. Signal an anomaly when the absolute z-score is larger than 3.



-- STEP 0: MEAN/STDEV PER WEEK

DROP MATERIALIZED VIEW IF EXISTS youtube_ts_stats;

CREATE MATERIALIZED VIEW youtube_ts_stats(
    bucket,
    avg_views,
    std_views,
    avg_norm_views,
    std_norm_views
)
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 week', "timestamp") AS bucket,
    average(stats_agg(views)),
    stddev(stats_agg(views)),
    average(stats_agg(norm_views)),
    stddev(stats_agg(norm_views))
FROM youtube_ts
GROUP BY bucket;

SELECT * FROM youtube_ts_stats;



-- STEP 1: Z-SCORES

DROP TABLE IF EXISTS week_selection;

CREATE TABLE week_selection (
    videostatsid integer PRIMARY KEY,
    "timestamp" timestamp with time zone,
    norm_views double precision,
    ref_week_start date,
    z_score double precision
);

-- week_start := '2020-01-06'

INSERT INTO week_selection (
    videostatsid,
    "timestamp",
    norm_views
)
SELECT
    videostatsid,
    "timestamp",
    norm_views
FROM youtube_ts
WHERE date_trunc('week', "timestamp") = '2020-01-06';

-- TODO: issue with update overwriting instead of adding the four weeks
-- If possible, add the ref_week_start in the INSERT above, or integrate all.
WITH ref_weeks AS (
    SELECT
        bucket::date AS ref_week_start,
        avg_norm_views,
        std_norm_views
    FROM youtube_ts_stats
    WHERE bucket
        BETWEEN '2020-01-06'::date - INTERVAL '4 weeks'
        AND '2020-01-06'::date - INTERVAL '1 week'
),
z_scores AS (
    SELECT
        s.videostatsid,
        r.ref_week_start,
        (s.norm_views - r.avg_norm_views) / r.std_norm_views AS z_score
    FROM week_selection s
    CROSS JOIN ref_weeks r
)
UPDATE week_selection w
SET
    ref_week_start = z.ref_week_start,
    z_score = z.z_score
FROM z_scores z
WHERE w.videostatsid = z.videostatsid;

SELECT *
FROM week_selection
ORDER BY videostatsid, ref_week_start;
