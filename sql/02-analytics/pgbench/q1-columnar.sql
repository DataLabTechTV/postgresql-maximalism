SELECT
    date_trunc('week', "timestamp")::date AS week,
    round(avg(likes)) AS avg_likes,
    round(avg(dislikes)) AS avg_dislikes
FROM lakehouse.youtube
GROUP BY week;
