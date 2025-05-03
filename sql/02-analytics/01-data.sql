/*
 * Category: Analytics
 * Extension: pg_mooncake
 * Task: Extract, Load, Transform
 */


-- SETUP MINIO SECRET

SELECT mooncake.drop_secret('minio');

SELECT mooncake.create_secret(
    'minio',
    'S3',
    'datalabtech',
    'datalabtech',
    '{
        "ENDPOINT":"minio:9000",
        "REGION":"us-east-1",
        "USE_SSL": false,
        "URL_STYLE": "path"
    }'
);

-- If it's the first run, also execute the SET by itself.
ALTER DATABASE datalabtech
SET mooncake.default_bucket = 's3://lakehouse';

-- LOAD DATA INTO A MOONCAKE COLUMNSTORE

DROP SCHEMA IF EXISTS lakehouse CASCADE;

CREATE SCHEMA lakehouse;

CREATE TABLE lakehouse.youtube (
    videostatsid bigint,
    ytvideoid text,
    views bigint,
    comments bigint,
    likes bigint,
    dislikes bigint,
    "timestamp" timestamp without time zone
) USING columnstore;

INSERT INTO lakehouse.youtube
SELECT *
FROM mooncake.read_csv(
    'hf://datasets/jettisonthenet/timeseries_trending_youtube_videos_2019-04-15_to_2020-04-15/videostats.csv'
)
AS (
    videostatsid bigint,
    ytvideoid text,
    views bigint,
    comments bigint,
    likes bigint,
    dislikes bigint,
    "timestamp" timestamp without time zone
);


-- REPLICATE THE DATA IN A REGULAR TABLE

DROP TABLE IF EXISTS youtube;

CREATE TABLE youtube AS
SELECT * FROM lakehouse.youtube;
