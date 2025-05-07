WITH weekly_recency AS (
    SELECT *, row_number() OVER (
        PARTITION BY
            ytvideoid,
            date_trunc('week', "timestamp")
        ORDER BY "timestamp" DESC
    ) AS recency
    FROM youtube
)
SELECT
    date_trunc('week', "timestamp")::date AS week_start,
    round(avg(likes)) AS avg_likes,
    round(avg(dislikes)) AS avg_dislikes
FROM weekly_recency
WHERE recency = 1
GROUP BY week_start;
