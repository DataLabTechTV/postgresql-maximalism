/*
 * Category: Message Queues
 * Extension: pgmq
 * Task: Create a queue.
 */

-- Let's make sure we start from an empty state
DROP EXTENSION pgmq;
CREATE EXTENSION pgmq;

SELECT pgmq.create('requests');

SELECT * FROM pgmq.list_queues();

SELECT pgmq.drop_queue('requests');

SELECT * FROM pgmq.list_queues();

-- For high-activity queues, avoid performance degradation with
-- partitioned queues. This defaults to 10k rows per partition.
SELECT pgmq.create_partitioned('requests');

-- This uses unlogged tables for the queue, improving performance at
-- the cost of safety by not writing to WAL (Write-Ahead Log).
-- Use it when you can tolerate message loss, but need high performance.
SELECT pgmq.create_unlogged('jobs');

SELECT * FROM pgmq.list_queues();

-- Default queue tables are permanent (p), but requests is unlogged (u).
SELECT relname, relpersistence
FROM pg_class
WHERE relname IN ('q_jobs', 'q_requests');
