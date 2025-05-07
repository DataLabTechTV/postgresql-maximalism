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
-- 2. Normalize absolute z-scores and exclude weeks with a normalized z-score outside
--    of a 0.6 range of the median normalized z-score.
-- 3. Compute a single absolute z-score based on the mean/stdev of the selected weeks
--    and signal an anomaly when the absolute z-score is larger than 2.5.



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



-- STEP 1: ABSOLUTE Z-SCORES

DROP TABLE IF EXISTS week_selection;

CREATE TABLE week_selection (
    videostatsid integer,
    "timestamp" timestamp with time zone,
    norm_views double precision,
    ref_week_start date,
    abs_z_score double precision
);

-- week_start := '2020-01-06'

WITH ref_weeks AS (
    SELECT
        bucket::date AS ref_week_start,
        avg_norm_views,
        std_norm_views
    FROM youtube_ts_stats
    WHERE bucket
        BETWEEN '2020-01-06'::date - INTERVAL '8 weeks'
        AND '2020-01-06'::date - INTERVAL '1 week'
)
INSERT INTO week_selection (
    videostatsid,
    "timestamp",
    norm_views,
    ref_week_start,
    abs_z_score
)
SELECT
    y.videostatsid,
    y."timestamp",
    y.norm_views,
    r.ref_week_start,
    abs((y.norm_views - r.avg_norm_views) / r.std_norm_views) AS abs_z_score
FROM youtube_ts y
CROSS JOIN ref_weeks AS r
WHERE date_trunc('week', "timestamp") = '2020-01-06';


SELECT *
FROM week_selection
ORDER BY videostatsid, ref_week_start;



-- STEP 2: MEDIAN-NORMALIZED ABSOLUTE Z-SCORES TO SELECT WEEKS

SELECT count(*) FROM week_selection;

WITH median_z_scores AS (
    SELECT
        max(videostatsid) AS videostatsid,
        percentile_cont(0.5)
            WITHIN GROUP (ORDER BY abs_z_score)
            AS median_abs_z_score
    FROM week_selection
    GROUP BY videostatsid
),
norm_z_scores AS (
    SELECT
        videostatsid,
        abs(abs_z_score - median_abs_z_score) AS norm_abs_z_score
    FROM week_selection
    JOIN median_z_scores
    USING (videostatsid)
)
DELETE FROM week_selection w
USING norm_z_scores n
WHERE w.videostatsid = n.videostatsid
    AND n.norm_abs_z_score >= 0.6;

SELECT count(*) FROM week_selection;



-- STEP 3: STATS FOR SELECTED WEEKS, ABSOLUTE Z-SCORE, SIGNAL ANOMALY

WITH week_stats AS (
    SELECT
        videostatsid,
        average(stats_agg(y.norm_views)) AS avg_norm_views,
        stddev(stats_agg(y.norm_views)) AS std_norm_views
    FROM youtube_ts y
    JOIN week_selection w
    USING (videostatsid)
    WHERE date_trunc('week', y."timestamp") = '2020-01-06'
    GROUP BY videostatsid
),
z_scores AS (
    SELECT
        videostatsid,
        (
            CASE
                WHEN std_norm_views = 0 THEN 0
                ELSE abs(norm_views - avg_norm_views) / std_norm_views
            END
        ) AS abs_z_score
    FROM youtube_ts y
    JOIN week_stats s
    USING (videostatsid)
    WHERE date_trunc('week', y."timestamp") = '2020-01-06'
)
SELECT
    videostatsid,
    abs_z_score,
    (abs_z_score > 2.5) AS is_anomaly
FROM z_scores
WHERE abs_z_score > 0;
