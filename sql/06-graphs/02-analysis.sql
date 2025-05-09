/*
 * Category: Vectors and AI
 * Extension: pgrouting
 * Task: Network analysis with pgrouting and vanilla postgres.
 */


-- COMPUTE NODE DEGREE

-- Auxiliary table for efficiency

DROP TABLE IF EXISTS graph.node_info;

CREATE TABLE graph.node_info AS
SELECT id, in_edges, out_edges
FROM pgr_extractVertices(
    $$
        SELECT
            edge_id AS id,
            source_id AS source,
            target_id AS target
        FROM graph.edges
    $$
);

SELECT * FROM graph.node_info LIMIT 100;


-- Node degree

DROP TABLE IF EXISTS graph.node_degree;

CREATE TABLE graph.node_degree AS
SELECT node AS node_id, degree
FROM pgr_degree(
    $$SELECT edge_id AS id FROM graph.edges$$,
    $$SELECT id, in_edges, out_edges FROM graph.node_info$$
);

SELECT node_id, degree
FROM graph.node_degree
ORDER BY degree DESC;

-- Select two nodes

BEGIN;
    -- Ensure reproducibility
    SELECT setseed(0.5);

    SELECT node_id, degree
    FROM graph.node_degree
    WHERE degree > 1 AND degree < 10
    ORDER BY random()
    LIMIT 2;
END;


-- SHORTEST PATH BETWEEN TWO HIGHEST-DEGREE NODES

WITH shortest_path AS (
    SELECT edge
    FROM pgr_dijkstra(
        $$
            SELECT
                edge_id AS id,
                source_id AS source,
                target_id AS target,
                1 AS cost -- required
            FROM graph.edges
        $$,
        1963, -- start_vid
        17529,  -- end_vid
        directed => false
    )
)
SELECT e.*
FROM graph.edges e, shortest_path
WHERE edge_id IN (edge);



-- TEST FOR A SMALL WORLD

-- Compute average shortest path
-- Note: approximated by a small node sample due to RAM limitations
-- and also due to performance for demoing purposes.

DROP TABLE IF EXISTS graph.node_sample;

CREATE TABLE graph.node_sample AS
SELECT node_id
FROM graph.nodes
ORDER BY random()
LIMIT 5;

-- How many shortest paths will we compute for 5 sources?
SELECT count(*) AS n_paths
FROM (
    SELECT
        ns.node_id AS source,
        n.node_id AS target
    FROM graph.node_sample ns
    CROSS JOIN graph.nodes n
);

-- Compute sample-to-all shortest paths

DROP TABLE IF EXISTS graph.sample_shortest_path_cost;

CREATE TABLE graph.sample_shortest_path_cost AS
SELECT *
FROM pgr_dijkstraCost(
    $$
        SELECT
            edge_id AS id,
            source_id AS source,
            target_id AS target,
            1 AS cost -- required
        FROM graph.edges
    $$,
    $$
        SELECT
            ns.node_id AS source,
            n.node_id AS target
        FROM graph.node_sample ns
        CROSS JOIN graph.nodes n
    $$,
    directed => false
);

-- Inspect computed shortest path lengths
SELECT *
FROM graph.sample_shortest_path_cost
ORDER BY random()
LIMIT 100;

-- How many source nodes?
SELECT count(DISTINCT start_vid)
FROM graph.sample_shortest_path_cost;

-- How many target nodes?
SELECT count(DISTINCT end_vid)
FROM graph.sample_shortest_path_cost;

-- How many nodes in total?
SELECT count(DISTINCT vid)
FROM (
    SELECT DISTINCT start_vid AS vid
    FROM graph.sample_shortest_path_cost

    UNION

    SELECT DISTINCT end_vid AS vid
    FROM graph.sample_shortest_path_cost
);

-- Compute number of edges between neighbors of sample nodes
-- Note: again, we downsample the neighbors to analyze (first 5).

CREATE INDEX IF NOT EXISTS edges_source_id_idx
ON graph.edges (source_id);

CREATE INDEX IF NOT EXISTS edges_target_id_idx
ON graph.edges (target_id);

CREATE INDEX IF NOT EXISTS node_sample_node_id_idx
ON graph.node_sample (node_id);

CREATE INDEX IF NOT EXISTS edges_source_id_target_id_idx
ON graph.edges (source_id, target_id);

DROP TABLE IF EXISTS graph.sample_neighbor_edge_count;

CREATE TABLE graph.sample_neighbor_edge_count AS
WITH neighbors AS (
    SELECT DISTINCT node_id, neighbor_id
    FROM (
        SELECT node_id, target_id AS neighbor_id
        FROM graph.node_sample ns
        JOIN graph.edges e
        ON e.source_id = ns.node_id

        UNION

        SELECT node_id, source_id AS neighbor_id
        FROM graph.node_sample ns
        JOIN graph.edges e
        ON e.target_id = ns.node_id
    )
)
SELECT node_id, count(*) AS n_neighbor_edges
FROM neighbors n
JOIN graph.edges e
ON e.source_id IN (
        SELECT neighbor_id
        FROM neighbors
        WHERE node_id = n.node_id
        LIMIT 5
    )
    AND e.target_id IN (
        SELECT neighbor_id
        FROM neighbors
        WHERE node_id = n.node_id
        LIMIT 5
    )
GROUP BY node_id;

SELECT * FROM graph.sample_neighbor_edge_count;

-- Compute local clustering coefficients for sample

DROP TABLE IF EXISTS graph.sample_clustering_coefficient;

CREATE TABLE graph.sample_clustering_coefficient AS
SELECT node_id, (2 * n_neighbor_edges::numeric) / (degree * (degree - 1)) AS lcc
FROM graph.node_degree nd
JOIN graph.sample_neighbor_edge_count ec
USING (node_id);

SELECT * FROM graph.sample_clustering_coefficient;

-- Is it a small world?
-- Note: the reference value for the CC baseline is computed in
-- the notebook.
WITH small_world_properties AS (
    SELECT
        avg(spc.agg_cost) AS aspl,
        avg(scc.lcc) AS cc
    FROM graph.sample_shortest_path_cost spc
    JOIN graph.sample_clustering_coefficient scc
    ON spc.start_vid = scc.node_id
)
SELECT
    aspl,
    aspl <= 6 AS is_short_aspl,
    cc,
    cc > 0.0006346085927083137 AS is_high_cc,
    (aspl <= 6 AND cc > 0.0006346085927083137) AS is_small_world
FROM small_world_properties;
