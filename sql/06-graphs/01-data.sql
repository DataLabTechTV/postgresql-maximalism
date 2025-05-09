/*
 * Category: Vectors and AI
 * Extension: pgrouting
 * Task: Load a Twitch gamers reciprocal-follow graph.
 */

-- EXTERNAL: Run scripts/graph_load.sh data/

-- Let's check if the data was properly loaded.

SELECT
    'num_nodes' AS stat,
    count(*) AS val
FROM twitch.nodes

UNION

SELECT
    'num_edges' AS stat,
    count(*) AS val
FROM twitch.edges

UNION

SELECT
    'num_linked_nodes' AS stat,
    count(*) AS val
FROM (
    SELECT DISTINCT numeric_id_1
    FROM twitch.edges

    UNION

    SELECT DISTINCT numeric_id_2
    FROM twitch.edges
);

SELECT * FROM twitch.nodes LIMIT 100;

SELECT * FROM twitch.edges LIMIT 100;
