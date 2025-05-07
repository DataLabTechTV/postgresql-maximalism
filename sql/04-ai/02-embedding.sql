/*
 * Category: Vectors and AI
 * Extension: pgvector/pgvectorscale/pgai
 * Task: Compute embeddings.
 */

DROP TABLE IF EXISTS lakehouse.movie_features;

CREATE TABLE lakehouse.movie_features
USING columnstore AS
SELECT
    id,

    COALESCE(
        (popularity - min(popularity) OVER ()) /
            (((max(popularity) OVER ()) - (min(popularity) OVER ()))),
        0.5
    ) AS norm_popularity,

    COALESCE(
        (extract(YEAR FROM release_date)::float -
         min(extract(YEAR FROM release_date)) OVER ()) /
            (((max(extract(YEAR FROM release_date)) OVER ()) -
            (min(extract(YEAR FROM release_date)) OVER ()))),
        0.5
    ) AS norm_release_date,

    COALESCE(
        (budget::float - min(budget) OVER ()) /
            (((max(budget) OVER ()) - (min(budget) OVER ()))),
        0.5
    ) AS norm_budget,

    COALESCE(
        (revenue::float - min(revenue) OVER ()) /
            (((max(revenue) OVER ()) - (min(revenue) OVER ()))),
        0.5
    ) AS norm_revenue,

    COALESCE(
        (runtime::float - min(runtime) OVER ()) /
            (((max(runtime) OVER ()) - (min(runtime) OVER ()))),
        0.5
    ) AS norm_runtime,

    COALESCE(
        (vote_average::float - min(vote_average) OVER ()) /
            (((max(vote_average) OVER ()) - (min(vote_average) OVER ()))),
        0.5
    ) AS norm_vote_average,

    COALESCE(
        (vote_count::float - min(vote_count) OVER ()) /
            (((max(vote_count) OVER ()) - (min(vote_count) OVER ()))),
        0
    ) AS norm_vote_count,

    COALESCE(
        (length(recommendations)::float -
         min(length(recommendations)) OVER ()) /
        (((max(length(recommendations)) OVER ()) -
          (min(length(recommendations)) OVER ()))),
        0
    ) AS norm_len_recommendations
FROM lakehouse.movies;

SELECT * FROM lakehouse.movie_features LIMIT 100;


DROP TABLE IF EXISTS movies CASCADE;

CREATE TABLE movies AS
SELECT
    id,
    title,
    extract(YEAR FROM release_date) AS "year",

    norm_popularity,
    norm_release_date,
    norm_budget,
    norm_revenue,
    norm_runtime,
    norm_vote_average,
    norm_vote_count,
    norm_len_recommendations,

    concat(original_language, ' ', genres, ' ', production_companies, ' ',
        credits, ' ', keywords, ' ', recommendations, ' ',
        title, ' ', tagline, ' ', overview) AS content
FROM lakehouse.movies
JOIN lakehouse.movie_features
USING (id);

ALTER TABLE movies ADD PRIMARY KEY (id);

ALTER TABLE movies
    ADD COLUMN v_features vector(8),
    ADD COLUMN v_content vector(768),
    ADD COLUMN v_combined vector(776);

WITH embeddings AS (
    SELECT
        id,
        array[
            norm_popularity,
            norm_release_date,
            norm_budget,
            norm_revenue,
            norm_runtime,
            norm_vote_average,
            norm_vote_count,
            norm_len_recommendations
        ]::vector AS v_features
    FROM movies
)
UPDATE movies me
SET v_features = e.v_features
FROM embeddings e
WHERE me.id = e.id;

SELECT * FROM movies LIMIT 100;


DROP TABLE IF EXISTS movie_embeddings_store CASCADE;

-- https://github.com/timescale/pgai/blob/pgai-v0.9.2/docs/vectorizer/overview.md
SELECT ai.create_vectorizer(
    'movies'::regclass,
    destination => 'movie_embeddings',
    embedding => ai.embedding_ollama(
        model => 'nomic-embed-text',
        -- Must be set correctly or pgai-worker will crash.
        -- Had to install v0.10.2 and look at the logs.
        dimensions => 768
    ),
    chunking => ai.chunking_character_text_splitter(
        chunk_column => 'content',
        chunk_size => 128,
        chunk_overlap => 10
    )
);

-- If ollama and the pgai-worker docker services are running,
-- you should see an entry in the following table.
--
-- Note: the job will take a while on first run, as ollama will
-- need to download the deepseek-r1 model and/or load it.
SELECT * FROM ai.vectorizer_status;

-- Results will appear in the <destination table>_store when finished.
-- The destination table is actually a view.
SELECT * FROM movie_embeddings_store LIMIT 100;

-- You can check the progress as follows.
SELECT
    count(*) AS processed,
    max(total) - count(*) AS remaining,
    max(total) AS total,
    count(*) / max(total::double precision) * 100 AS progress_pct
FROM movie_embeddings_store, (
    SELECT count(*) AS total
    FROM movies
);

-- TODO: index final embedding, after combining vectors
CREATE INDEX IF NOT EXISTS movie_embeddings_v_combined_cos_idx
ON movie_embeddings
USING diskann (v_combined vector_cosine_ops);
