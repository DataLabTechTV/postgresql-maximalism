/*
 * Category: Search
 * Built-In: GIN, tsvector, tsquery, ts_rank
 * Task: Create inverted index and query.
 */


-- CREATE INDEX

DROP INDEX IF EXISTS idx_doc_gin;

-- Needs to use 'english' to make sure it's immutable,
-- i.e., can't use default function parameters.
CREATE INDEX idx_doc_gin ON doc
USING GIN (to_tsvector('english', content));


-- QUERY

-- Be sure to use 'english' explicitly,
-- or the query won't hit the index!
WITH search AS (
    SELECT
        id,
        content,
        to_tsvector('english', content) AS d,
        to_tsquery('english', 'postgresql | performance') AS q
    FROM
        doc
)
SELECT ts_rank(d, q, 1) AS score, id, content
FROM search
WHERE d @@ q
ORDER BY score DESC;
