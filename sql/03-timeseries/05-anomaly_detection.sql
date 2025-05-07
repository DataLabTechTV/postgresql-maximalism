/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Detecting anomalous days in terms of views.
 */



-- PICK A WEEK FOR TESTING THAT MIGHT BE ANOMALOUS
-- week_start := '2019-12-02'
SELECT
    bucket::date AS week_start,
    round(avg(dislikes)) AS avg_dislikes
FROM youtube_ts_weekly_stats
GROUP BY week_start
ORDER BY week_start;



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
    avg_dislikes,
    std_dislikes,
    avg_norm_dislikes,
    std_norm_dislikes
)
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 week', bucket) AS bucket,
    average(stats_agg(dislikes)),
    stddev(stats_agg(dislikes)),
    average(stats_agg(norm_dislikes)),
    stddev(stats_agg(norm_dislikes))
FROM youtube_ts_weekly_stats
JOIN youtube_ts_weekly_features
USING (bucket, ytvideoid)
GROUP BY time_bucket('1 week', bucket);

SELECT * FROM youtube_ts_stats;



-- STEP 1: ABSOLUTE Z-SCORES

DROP TABLE IF EXISTS week_selection;

CREATE TABLE week_selection (
    ytvideoid character(11),
    bucket timestamp with time zone,
    norm_dislikes double precision,
    ref_week_start date,
    abs_z_score double precision
);

WITH ref_weeks AS (
    SELECT
        bucket::date AS ref_week_start,
        avg_norm_dislikes,
        std_norm_dislikes
    FROM youtube_ts_stats
    WHERE bucket
        BETWEEN '2019-12-02'::date - INTERVAL '8 weeks'
        AND '2019-12-02'::date - INTERVAL '1 week'
)
INSERT INTO week_selection (
    ytvideoid,
    bucket,
    norm_dislikes,
    ref_week_start,
    abs_z_score
)
SELECT
    ytvideoid,
    bucket,
    norm_dislikes,
    ref_week_start,
    abs((norm_dislikes - avg_norm_dislikes) / std_norm_dislikes) AS abs_z_score
FROM youtube_ts_weekly_stats
JOIN youtube_ts_weekly_features
USING (bucket, ytvideoid)
CROSS JOIN ref_weeks AS r
WHERE date_trunc('week', bucket) = '2019-12-02';


SELECT *
FROM week_selection
ORDER BY ytvideoid, ref_week_start;



-- STEP 2: MEDIAN-NORMALIZED ABSOLUTE Z-SCORES TO SELECT WEEKS

SELECT count(*) FROM week_selection;

WITH median_z_scores AS (
    SELECT
        max(ytvideoid) AS ytvideoid,
        percentile_cont(0.5)
            WITHIN GROUP (ORDER BY abs_z_score)
            AS median_abs_z_score
    FROM week_selection
    GROUP BY ytvideoid
),
norm_z_scores AS (
    SELECT
        ytvideoid,
        ref_week_start,
        abs(abs_z_score - median_abs_z_score) AS norm_z_score
    FROM week_selection
    JOIN median_z_scores
    USING (ytvideoid)
)
DELETE FROM week_selection w
USING norm_z_scores n
WHERE w.ytvideoid = n.ytvideoid
    AND w.ref_week_start = n.ref_week_start
    AND n.norm_z_score >= 0.6;

SELECT count(*) FROM week_selection;



-- STEP 3: STATS FOR SELECTED WEEKS, ABSOLUTE Z-SCORE, SIGNAL ANOMALY

DROP TABLE IF EXISTS youtube_anomalies;

CREATE TABLE youtube_anomalies AS
WITH week_stats AS (
    SELECT
        ytvideoid,
        average(stats_agg(norm_dislikes)) AS avg_norm_dislikes,
        stddev(stats_agg(norm_dislikes)) AS std_norm_dislikes
    FROM youtube_ts y
    JOIN week_selection w
    USING (ytvideoid)
    WHERE date_trunc('week', bucket) = '2019-12-02'
    GROUP BY ytvideoid
),
z_scores AS (
    SELECT
        ytvideoid,
        (
            CASE
                WHEN std_norm_dislikes = 0 THEN 0
                ELSE abs(norm_dislikes - avg_norm_dislikes) / std_norm_dislikes
            END
        ) AS abs_z_score
    FROM youtube_ts_weekly_stats
    JOIN youtube_ts_weekly_features
    USING (bucket, ytvideoid)
    JOIN week_stats s
    USING (ytvideoid)
    WHERE date_trunc('week', bucket) = '2019-12-02'
)
SELECT
    ytvideoid,
    abs_z_score,
    (abs_z_score > 3) AS is_anomaly
FROM z_scores;

SELECT *
FROM youtube_anomalies
ORDER BY ytvideoid;



-- INSPECT YOUTUBE ANOMALIES

SELECT * FROM (
    SELECT
        ytvideoid,
        abs_z_score,
        'most likes' AS description,
        'likes' AS stat,
        likes AS value
    FROM youtube_ts_weekly_stats s
    JOIN youtube_anomalies a
    USING (ytvideoid)
    WHERE is_anomaly
    ORDER BY likes DESC
    LIMIT 1
)

UNION

SELECT * FROM (
    SELECT
        ytvideoid,
        abs_z_score,
        'most dislikes' AS description,
        'dislikes' AS stat,
        dislikes AS value
    FROM youtube_ts_weekly_stats s
    JOIN youtube_anomalies a
    USING (ytvideoid)
    WHERE is_anomaly
    ORDER BY dislikes DESC
    LIMIT 1
)

UNION

SELECT * FROM (
    SELECT
        ytvideoid,
        abs_z_score,
        'most comments' AS description,
        'comments' AS stat,
        comments AS value
    FROM youtube_ts_weekly_stats s
    JOIN youtube_anomalies a
    USING (ytvideoid)
    WHERE is_anomaly
    ORDER BY comments DESC
    LIMIT 1
)

UNION

SELECT * FROM (
    SELECT
        ytvideoid,
        abs_z_score,
        'least comments' AS description,
        'comments' AS stat,
        comments AS value
    FROM youtube_ts_weekly_stats s
    JOIN youtube_anomalies a
    USING (ytvideoid)
    WHERE is_anomaly
    ORDER BY comments
    LIMIT 1
);
