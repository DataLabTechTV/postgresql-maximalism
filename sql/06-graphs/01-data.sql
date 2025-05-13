/*
 * Category: Graphs
 * Extension: pgrouting
 * Task: Load one of the supported graphs.
 */

-- EXTERNAL: Run scripts/graph_load.sh data/ <twitch|facebook>

-- Let's check if the data was properly loaded.

SELECT
    'num_nodes' AS stat,
    count(*) AS val
FROM graph.nodes

UNION

SELECT
    'num_edges' AS stat,
    count(*) AS val
FROM graph.edges

UNION

SELECT
    'num_linked_nodes' AS stat,
    count(*) AS val
FROM (
    SELECT DISTINCT source_id
    FROM graph.edges

    UNION

    SELECT DISTINCT target_id
    FROM graph.edges
);

SELECT * FROM graph.nodes LIMIT 100;

SELECT * FROM graph.edges LIMIT 100;
