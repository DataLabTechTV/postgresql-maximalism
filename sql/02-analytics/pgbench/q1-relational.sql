SELECT
    date_trunc('week', timestamp)::date AS week,
    avg(likes)
FROM youtube
GROUP BY week;
