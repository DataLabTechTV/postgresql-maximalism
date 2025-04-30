/*
 * Category: Analytics
 * Extension: pg_mooncake
 * Task: Extract, Load, Transform
 */

DROP TABLE IF EXISTS youtube;

CREATE TABLE youtube (
    videostatsid BIGINT,
    ytvideoid TEXT,
    views BIGINT,
    comments BIGINT,
    likes BIGINT,
    dislikes BIGINT,
    "timestamp" TIMESTAMP WITHOUT TIME ZONE
) USING columnstore;


INSERT INTO youtube
SELECT *
FROM mooncake.read_csv(
    'hf://datasets/jettisonthenet/timeseries_trending_youtube_videos_2019-04-15_to_2020-04-15/videostats.csv'
)
AS (
    videostatsid BIGINT,
    ytvideoid TEXT,
    views BIGINT,
    comments BIGINT,
    likes BIGINT,
    dislikes BIGINT,
    "timestamp" TIMESTAMP WITHOUT TIME ZONE
);
