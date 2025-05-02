WITH youtube_stats AS (
    SELECT
        "timestamp",
        views,
        likes,
        dislikes,
        likes / (likes + dislikes) AS likes_share,
        dislikes / (likes + dislikes) AS dislikes_share
    FROM youtube
)
SELECT
    date_trunc('month', "timestamp") AS "month",
    'all' AS subset,

    count(*) AS n,
    round(avg(likes_share), 2) AS avg_likes_share,

    round(percentile_cont(0.1) WITHIN GROUP (ORDER BY views)) AS p10_views,
    round(percentile_cont(0.5) WITHIN GROUP (ORDER BY views)) AS median_views,
    round(percentile_cont(0.9) WITHIN GROUP (ORDER BY views)) AS p90_views
FROM youtube_stats
GROUP BY "month"

UNION

SELECT
    date_trunc('month', "timestamp") AS "month",
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
GROUP BY "month"

UNION

SELECT
    date_trunc('month', "timestamp") AS "month",
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
GROUP BY "month"

ORDER BY "month", subset;
