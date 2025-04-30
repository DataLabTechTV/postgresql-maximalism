/*
 * Category: Analytics
 * Extension: pg_mooncake
 * Task: Exploratory Data Analysis
 */

SELECT count(*) FROM lakehouse.youtube;

SELECT avg(likes) AS avg_likes FROM lakehouse.youtube;

SELECT
    date_trunc('week', timestamp)::date AS week,
    avg(likes)
FROM lakehouse.youtube
GROUP BY week;
