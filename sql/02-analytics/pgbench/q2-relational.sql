WITH monthly_recency AS (
    SELECT *, row_number() OVER (
        PARTITION BY
            ytvideoid,
            date_trunc('month', "timestamp")
        ORDER BY "timestamp" DESC
    ) AS recency
    FROM youtube
),
youtube_stats AS (
    SELECT
        date_trunc('month', "timestamp") AS month_start,
        views,
        likes,
        dislikes,
        likes / (likes + dislikes) AS likes_share,
        dislikes / (likes + dislikes) AS dislikes_share
    FROM monthly_recency
    WHERE recency = 1
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
