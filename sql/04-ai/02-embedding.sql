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
        (popularity - avg(popularity) OVER ()) /
            (stddev(popularity) OVER ()),
        0
    ) AS norm_popularity,

    COALESCE(
        (extract(YEAR FROM release_date)::float -
            avg(extract(YEAR FROM release_date)) OVER ()) /
            (stddev(extract(YEAR FROM release_date)) OVER ()),
        0
    ) AS norm_release_date,

    COALESCE(
        (budget::float - avg(budget) OVER ()) /
            (stddev(budget) OVER ()),
        0
    ) AS norm_budget,

    COALESCE(
        (revenue::float - avg(revenue) OVER ()) /
            (stddev(revenue) OVER ()),
        0
    ) AS norm_revenue,

    COALESCE(
        (runtime::float - avg(runtime) OVER ()) /
            (stddev(runtime) OVER ()),
        0
    ) AS norm_runtime,

    COALESCE(
        (vote_average::float - avg(vote_average) OVER ()) /
            (stddev(vote_average) OVER ()),
        0
    ) AS norm_vote_average,

    COALESCE(
        (vote_count::float - min(vote_count) OVER ()) /
            (stddev(vote_count) OVER ()),
        0
    ) AS norm_vote_count,

    COALESCE(
        (length(recommendations)::float -
            avg(length(recommendations)) OVER ()) /
            (stddev(length(recommendations)) OVER ()),
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
UPDATE movies m
SET v_features = e.v_features
FROM embeddings e
WHERE m.id = e.id;

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

-- This takes a few hours, so let's stop the job and drop the embeddings
-- table, so we can restore from a previously computed dump instead.
SELECT ai.drop_vectorizer(
    (
        SELECT id FROM ai.vectorizer
        WHERE target_table = 'movie_embeddings_store'
    ),
    drop_all => TRUE
);

-- EXTERNAL: Restore dump using scripts/restore_embeddings.sh

-- Update movies with content embeddings
-- Note: in a normal scenario, we could query the movie_embeddings view
UPDATE movies m
SET v_content = e.embedding
FROM movie_embeddings_store e
WHERE m.id = e.id;

-- We can now drop the movie_embeddings_store, to save space
DROP TABLE IF EXISTS movie_embeddings_store CASCADE;

-- Let's also combine the v_content and v_features vectors
UPDATE movies m
SET v_combined = v_features || v_content;

-- Let's check the final result.
SELECT * FROM movies LIMIT 100;

-- Index v_combined for cosine similarity search
CREATE INDEX IF NOT EXISTS movie_embeddings_v_combined_cos_idx
ON movies USING diskann (v_combined vector_cosine_ops);
