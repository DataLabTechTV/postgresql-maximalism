/*
 * Category: Search
 * Task: Prepare example documents.
 */

DROP TABLE IF EXISTS doc;

CREATE TABLE doc (
    id integer,
    content text,
    rating integer,
    publish_date date
);

INSERT INTO doc (id, content, rating, publish_date)
VALUES
    (1, 'PostgreSQL is a powerful, open-source object-relational database system. It has a strong reputation for reliability, feature robustness, and performance. Common use cases include web applications, data warehousing, and geospatial data processing.', 3, '2024-01-01'),
    (2, 'Full-text search allows you to efficiently search natural-language documents. PostgreSQL supports full-text search with features like tokenization, dictionaries, ranking, and highlighting. It is useful for applications like document search, product catalogs, and knowledge bases.', 5, '1999-06-06'),
    (3, 'When dealing with large-scale applications, PostgreSQL can be scaled vertically by adding more resources, or horizontally using replication and partitioning. Tools like connection pooling, caching, and indexing strategies help maintain performance under high load.', 2, '2001-11-12');
