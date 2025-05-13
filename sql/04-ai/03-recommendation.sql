/*
 * Category: Vectors and AI
 * Extension: pgvector/pgvectorscale/pgai
 * Task: Recommend similar movies.
 */

-- POOL OF MOVIES TO RECOMMEND FROM

-- This brings movie data from the pg_mooncake context into the
-- postgres context, which would otherwise cause errors during
-- planning, for unsupported cross-engine queries.

DROP MATERIALIZED VIEW IF EXISTS trusted_movies;

CREATE MATERIALIZED VIEW trusted_movies AS
SELECT
    id::bigint,
    title::varchar(50),
    genres::varchar(50),
    original_language::varchar(2),
    overview::varchar,
    popularity::float,
    production_companies::varchar(1000),
    release_date::date,
    budget::bigint,
    revenue::bigint,
    runtime::bigint,
    status::varchar(50),
    tagline::varchar,
    vote_average::float,
    vote_count::integer,
    credits::varchar,
    keywords::varchar,
    poster_path::varchar(50),
    backdrop_path::varchar(50),
    recommendations::varchar(200)
FROM lakehouse.movies
WHERE vote_count > 10;


-- CREATE AN EXAMPLE USER PROFILE
-- Likes mostly time travel movies, with a few oddballs

DROP TABLE IF EXISTS user_profile;

CREATE TEMPORARY TABLE user_profile AS
SELECT 1 AS user_id, id AS movie_id, title, "year", v_content
FROM movies
WHERE title ~~* '%pope%exorcist%'
    OR title ~~* '%crocodile dundee%'
        AND title !~~* '%in los angeles%'
    OR title ~ '^Back to the Future( (Part III?))?$'
        AND year IS NOT NULL
    OR title = 'Time Trap' AND "year" = 2017
    OR title IN ('The Terminator', 'Terminator 2: Judgment Day')
ORDER BY year;

SELECT * FROM user_profile;


-- COMPUTE RECOMMENDATIONS

CREATE TABLE IF NOT EXISTS movie_recommendations (
    user_id integer,
    movie_id integer,
    title text,
    year integer,
    genres text,
    tagline text,
    overview text,
    vote_average float,
    vote_count integer,
    distance float
);

DELETE FROM movie_recommendations
WHERE user_id = (SELECT user_id FROM user_profile);

INSERT INTO movie_recommendations
WITH user_taste AS (
    SELECT
        max(user_id) AS user_id,
        avg(v_content) AS avg_v_content
    FROM user_profile
)
SELECT
    ut.user_id,
    m.id AS movie_id,
    m.title,
    "year",
    genres,
    tagline,
    overview,
    vote_average,
    vote_count,
    -- <==> for cosine distance (used here)
    -- <-> for L2/Euclidean distance
    -- <#> for negative inner product
    v_content <=> avg_v_content AS distance
FROM user_taste ut, trusted_movies tm
JOIN movies m
USING (id)
WHERE NOT m.id IN (SELECT movie_id FROM user_profile)
ORDER BY distance
LIMIT 10000;


-- View top recommendations
SELECT *
FROM movie_recommendations
ORDER BY distance
LIMIT 100;

-- Apply a personal filter:
-- 1. Lesser known (low vote counts)
-- 2. Not too old (>1970s)
SELECT *
FROM movie_recommendations
WHERE vote_count < 100 AND year >= 1970
ORDER BY distance
LIMIT 100;
