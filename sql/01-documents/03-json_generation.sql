/*
 * Category: Documents
 * Built-in: jsonb
 * Task: Manipulate rows to produce JSON valid responses.
 */


-- SELECT DATA SUBSET

SELECT *
FROM request
WHERE submit_time BETWEEN '2025-04-01 08:00:00' AND '2025-04-01 08:30:00'
ORDER BY id;


-- CONVERT DATA SUBSET TO JSON RESPONSE

SELECT array_to_json(array_agg(row_to_json(r))) AS response
FROM (
    SELECT submit_time, params, response
    FROM request
    WHERE submit_time BETWEEN '2025-04-01 08:00:00' AND '2025-04-01 08:30:00'
) r
