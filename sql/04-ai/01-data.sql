/*
 * Category: Vectors and AI
 * Extension: pgvector/pgvectorscale/pgai
 * Task: Load movie dataset.
 */

DROP TABLE IF EXISTS lakehouse.movies;

CREATE TABLE lakehouse.movies (
    id bigint,
    title varchar(50),
    genres varchar(50),
    original_language character(2),
    overview text,
    popularity float,
    production_companies varchar(1000),
    release_date date,
    budget bigint,
    revenue bigint,
    runtime bigint,
    status varchar(50),
    tagline text,
    vote_average float,
    vote_count integer,
    credits text,
    keywords text,
    poster_path varchar(50),
    backdrop_path varchar(50),
    recommendations varchar(200)
) USING columnstore;

INSERT INTO lakehouse.movies
SELECT DISTINCT ON (id) *
FROM mooncake.read_csv('hf://datasets/wykonos/movies/movies_dataset.csv')
AS (
    id bigint,
    title varchar(50),
    genres varchar(50),
    original_language character(2),
    overview text,
    popularity float,
    production_companies varchar(1000),
    release_date date,
    budget bigint,
    revenue bigint,
    runtime bigint,
    status varchar(50),
    tagline text,
    vote_average float,
    vote_count integer,
    credits text,
    keywords text,
    poster_path varchar(50),
    backdrop_path varchar(50),
    recommendations varchar(200)
);

SELECT * FROM lakehouse.movies LIMIT 100;
