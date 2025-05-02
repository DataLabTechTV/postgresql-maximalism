SELECT
    date_trunc('week', "timestamp")::date AS week_start,
    round(avg(likes)) AS avg_likes,
    round(avg(dislikes)) AS avg_dislikes
FROM youtube
GROUP BY week_start;
