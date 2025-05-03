/*
 * Category: Time Series
 * Extension: timescaledb
 * Task: Detecting anomalous days, view-wise.
 */


SELECT min("timestamp"), max("timestamp")
FROM youtube_ts;


SELECT
    time_bucket_gapfill('1 day', "timestamp") AS bucket_time,
    avg(norm_views) AS avg_norm_views
FROM youtube_ts
WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
GROUP BY bucket_time
ORDER BY bucket_time;


SELECT
    time_bucket_gapfill('1 day', "timestamp") AS bucket_time,
    interpolate(
        avg(norm_views),
        (
            SELECT ("timestamp", norm_views)
            FROM youtube_ts
            WHERE "timestamp" >= '2019-04-15'
            ORDER BY "timestamp"
            LIMIT 1
        ),
        (
            SELECT ("timestamp", norm_views)
            FROM youtube_ts
            WHERE "timestamp" <= '2020-04-15'
            ORDER BY "timestamp" DESC
            LIMIT 1
        )

    ) AS avg_norm_views
FROM youtube_ts
WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
GROUP BY bucket_time
ORDER BY bucket_time;


WITH filled_gaps AS (
    SELECT
        time_bucket_gapfill('1 day', "timestamp") AS bucket_time,
        interpolate(
            avg(norm_views),
            (
                SELECT ("timestamp", norm_views)
                FROM youtube_ts
                WHERE "timestamp" >= '2019-04-15'
                ORDER BY "timestamp"
                LIMIT 1
            ),
            (
                SELECT ("timestamp", norm_views)
                FROM youtube_ts
                WHERE "timestamp" <= '2020-04-15'
                ORDER BY "timestamp" DESC
                LIMIT 1
            )

        ) AS avg_norm_views
    FROM youtube_ts
    WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
    GROUP BY bucket_time
    ORDER BY bucket_time
)
SELECT
    bucket_time,
    avg_norm_views
FROM filled_gaps
WHERE date_trunc('month', "bucket_time") = '2019-04-01';


-- Inspiration: https://medium.com/booking-com-development/anomaly-detection-in-time-series-using-statistical-analysis-cc587b21d008
--
-- Steps for a single day of the current week being tested:
--
-- 0. Compute mean and stdev for each existing week.
-- 1. Compute four z-scores, based on the previous four weeks.
-- 2. Normalize absolute z-scores and exclude weeks with a normalized z-score outside of a 0.6 range of the median normalized z-score.
-- 3. Compute a single absolute z-score based on the mean/stdev of the selected weeks.
-- 4. Signal an anomaly when the absolute z-score is larger than 3.
