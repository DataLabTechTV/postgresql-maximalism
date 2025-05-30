/*
 * Category: Search
 * Extension: pg_search
 * Task: Create BM25 index and query.
 */


-- CREATE INDEX

DROP INDEX IF EXISTS idx_doc_bm25;

CREATE INDEX idx_doc_bm25 ON doc
USING bm25 (id, content, rating, publish_date)
WITH (
    key_field='id',
    text_fields='{
        "content": {
            "tokenizer": {
                "type": "ngram",
                "min_gram": 2,
                "max_gram": 3,
                "prefix_only": false
            },
            "stemmer": "English"
        }
    }',
    numeric_fields = '{
        "rating": {"fast": true}
    }'
);


-- INSPECT INDEX

SELECT name, field_type
FROM paradedb.schema('idx_doc_bm25');

SELECT pg_size_pretty(pg_relation_size('idx_doc_bm25'));


-- QUERY

-- Basic matching
SELECT id, content, rating, publish_date
FROM doc
WHERE content @@@ 'postgresql performance';

-- Field matching and boolean operators
SELECT id, content, rating, publish_date
FROM doc
WHERE id @@@ 'content:postgresql AND rating:5';

-- Ranked matching (BM25)
SELECT id, content, rating, publish_date
FROM doc
WHERE content @@@ 'postgresql performance'
ORDER BY paradedb.score(id) DESC;

-- Range filtering
SELECT id, content, rating, publish_date
FROM doc
WHERE
    content @@@ 'postgresql performance'
    AND rating @@@ '[3 TO 5]'
ORDER BY paradedb.score(id) DESC;

-- Set filtering (rating) and range filtering (publish_date)
SELECT id, content, rating, publish_date
FROM doc
WHERE
    content @@@ 'postgresql performance'
    AND rating @@@ 'IN [3 4 5]'
    AND publish_date @@@ '[2000-01-01T00:00:00Z TO 2024-12-31T23:59:59Z]'
ORDER BY paradedb.score(id) DESC;

-- Equivalent to previous query
SELECT id, content, rating, publish_date
FROM doc
WHERE
    content @@@ $$
        (postgresql performance)
        AND rating:IN [3 4 5]
        AND publish_date:[2000-01-01T00:00:00Z TO 2024-12-31T23:59:59Z]
    $$
ORDER BY paradedb.score(id) DESC;


-- (1/2) Without term boosting
SELECT id, content, rating, publish_date
FROM doc
WHERE content @@@ 'postgresql rating:5'
ORDER BY paradedb.score(id) DESC;

-- (2/2) With term boosting
SELECT id, content, rating, publish_date
FROM doc
WHERE content @@@ 'postgresql^10 rating:5'
ORDER BY paradedb.score(id) DESC;
