SELECT
    date_trunc('week', timestamp)::date AS week,
    avg(likes)
FROM lakehouse.youtube
GROUP BY week;
