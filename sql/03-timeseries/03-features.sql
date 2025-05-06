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
    time_bucket_gapfill('1 day', "timestamp") AS bucket_time,
    avg(views) AS avg_views
FROM youtube_ts
WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
GROUP BY bucket_time
ORDER BY bucket_time;


-- Fill-in gaps using two different methods
SELECT
    time_bucket_gapfill('1 day', "timestamp") AS bucket_time,
    avg(views) AS avg_views,
    interpolate(
        avg(views),
        (
            SELECT ("timestamp", views)
            FROM youtube_ts
            WHERE "timestamp" >= '2019-04-15'
            ORDER BY "timestamp"
            LIMIT 1
        ),
        (
            SELECT ("timestamp", views)
            FROM youtube_ts
            WHERE "timestamp" <= '2020-04-15'
            ORDER BY "timestamp" DESC
            LIMIT 1
        )

    ) AS interpolated_anv,
    locf(avg(views)) AS carried_anv
FROM youtube_ts
WHERE "timestamp" BETWEEN '2019-04-15' AND '2020-04-15'
GROUP BY bucket_time
ORDER BY bucket_time;



-- CONTINUOUS AGGREGATES (INCREMENTAL MATERIALIZED VIEWS)



-- HYPERFUNCTIONS
