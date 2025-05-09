/*
 * Category: Vectors and AI
 * Extension: pgvector/pgvectorscale/pgai
 * Task: RAG (Retrieval Augmented Generation).
 */

DROP TABLE IF EXISTS textual_results;

CREATE TEMPORARY TABLE textual_results AS
WITH ranked_results AS (
    SELECT
        row_number() OVER () AS "rank",
        title,
        "year",
        genres,
        tagline,
        overview
    FROM recommendations
    WHERE vote_count < 100 AND year >= 1970
    ORDER BY distance
    LIMIT 100
)
SELECT
    concat(
        rank, '. ', '"', title, '" (', "year",
        ') [', replace(genres, '-', ', '), '] - "', tagline, '"'
    ) AS result
FROM ranked_results;

WITH ollama_result AS (
    SELECT ai.ollama_generate(
        model => 'deepseek-r1:1.5b',
        prompt => (
            SELECT E'Below is a ranked list of movies. Based on the provided information, write a single global summary, in a paragraph or two, focusing on the overall genre and topics:\n\n' || string_agg(result, E'\n\n')
            FROM textual_results
        ),
        host => 'ollama'
    ) AS result
)
SELECT
    trim(
        E'\t\n\r '
        FROM regexp_replace(
            result->>'response',
            '<think>.*</think>',
            ''
        )
    ) AS summary
FROM ollama_result;
