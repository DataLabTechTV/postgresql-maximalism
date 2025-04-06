/*
 * Extension: pg_mooncake
 * Task: Extract, Load, Transform
 */

-- Due to incompatibility
DROP EXTENSION IF EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS youtube (
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
