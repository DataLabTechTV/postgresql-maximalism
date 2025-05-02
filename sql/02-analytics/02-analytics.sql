/*
 * Category: Analytics
 * Extension: pg_mooncake
 * Task: Exploratory Data Analysis
 */


-- Count all trending YouTube videos.
SELECT count(*) FROM lakehouse.youtube;


-- Count monthly trending YouTube videos.
SELECT
    date_trunc('month', "timestamp") AS month_start,
    count(*) AS "count"
FROM lakehouse.youtube
GROUP BY month_start;


-- Average likes and dislikes for trending YouTube videos per week.
-- pgbench: q1
SELECT
    date_trunc('week', "timestamp")::date AS week_start,
    round(avg(likes)) AS avg_likes,
    round(avg(dislikes)) AS avg_dislikes
FROM lakehouse.youtube
GROUP BY week_start;


-- Compare the view counts of trending YouTube videos with a higher share of likes
-- than dislikes versus those with a lower share of likes.
-- pgbench: q2
WITH youtube_stats AS (
    SELECT
        date_trunc('month', "timestamp") AS month_start,
        views,
        likes,
        dislikes,
        likes / (likes + dislikes) AS likes_share,
        dislikes / (likes + dislikes) AS dislikes_share
    FROM lakehouse.youtube
)
SELECT
    month_start,
    'all' AS subset,

    count(*) AS n,
    round(avg(likes_share), 2) AS avg_likes_share,

    round(percentile_cont(0.1) WITHIN GROUP (ORDER BY views)) AS p10_views,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY views)) AS median_views,
    round(percentile_cont(0.9) WITHIN GROUP (ORDER BY views)) AS p90_views
FROM youtube_stats
GROUP BY month_start

UNION

SELECT
    month_start,
    'lower_likes_share' AS subset,

    count(*) FILTER (WHERE likes < dislikes) AS n,
    round(avg(likes_share)
        FILTER (WHERE likes < dislikes), 2) AS avg_likes_share,

    round(percentile_cont(0.1) WITHIN GROUP (ORDER BY views)
        FILTER (WHERE likes < dislikes)) AS p10_views,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY views)
        FILTER (WHERE likes < dislikes)) AS median_views,
    round(percentile_cont(0.9) WITHIN GROUP (ORDER BY views)
        FILTER (WHERE likes < dislikes)) AS p90_views
FROM youtube_stats
GROUP BY month_start

UNION

SELECT
    month_start,
    'higher_likes_share' AS subset,

    count(*) FILTER (WHERE likes > dislikes) AS n,
    round(avg(likes_share)
        FILTER (WHERE likes > dislikes), 2) AS avg_likes_share,

    round(percentile_cont(0.1) WITHIN GROUP (ORDER BY views)
        FILTER (WHERE likes > dislikes)) AS p10_views,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY views)
        FILTER (WHERE likes > dislikes)) AS median_views,
    round(percentile_cont(0.9) WITHIN GROUP (ORDER BY views)
        FILTER (WHERE likes > dislikes)) AS p90_views
FROM youtube_stats
GROUP BY month_start

ORDER BY month_start, subset;
