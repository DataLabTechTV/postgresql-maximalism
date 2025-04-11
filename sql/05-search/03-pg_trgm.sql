/*
 * Category: Search
 * Extension: pg_trgm
 * Task: Fuzzy string matching based on character trigrams.
 */

WITH data AS (
    SELECT
        'programming' AS term1,
        'programing again' AS term2
)
SELECT
    term1,
    term2,
    similarity(term1, term2) AS sim,
    word_similarity(term1, term2) AS word_sim,
    term1 % term2 AS is_match
FROM
    data;
