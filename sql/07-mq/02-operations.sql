/*
 * Category: Message Queues
 * Extension: pgmq
 * Task: Queue operations and monitoring.
 */

SELECT date_trunc('day', now()) + interval '17h' +
    CASE
        WHEN now()::time >= '17:00'::time
            THEN interval '1 day'
        ELSE
            interval '0'
    END;

SELECT * from pgmq.send(
    queue_name  => 'jobs',
    msg => $${
        "action": "send_newsletter",
        "user_timezone": "UTC+1"
    }$$,
    delay => 10

    -- In a real-world scenario we might schedule it for the upcoming 5pm:
    --
    -- delay =>
    --     date_trunc('day', now()) +
    --     interval '17h' +
    --     CASE
    --         WHEN now()::time >= '17:00'::time
    --             THEN interval '1 day'
    --         ELSE
    --             interval '0'
    --     END
);

-- Wait for messages for 60 seconds.
SELECT * FROM pgmq.read_with_poll(
    queue_name => 'jobs',
    vt => 30,
    qty => 1,
    max_poll_seconds => 15
);

-- You can also directly read and delete one message
SELECT * FROM pgmq.pop('jobs');

-- Let's reset the whole queue
SELECT pgmq.purge_queue('jobs');



-- We can use send_batch to bundle multiple requests as well
SELECT * from pgmq.send_batch(
    queue_name  => 'requests',
    msgs => array[
        $${
            "customer_id": 1,
            "action": "order",
            "order": {
                "order_id": 5,
                "product_id": 300
            }
        }$$::jsonb,
        $${
            "customer_id": 1,
            "action": "set_main_address",
            "address_id": 2
        }$$::jsonb
    ]
);

SELECT * FROM pgmq.read(
    queue_name => 'requests',
    vt => 5, -- visibility timeout
    qty => 5
);

-- You can add to visibility timeout, if the job is taking longer than 5s
SELECT * FROM pgmq.set_vt(
    queue_name => 'requests',
    vt => 5,
    msg_id => 11
);

-- This removes the message from the queue, keeping history
SELECT pgmq.archive(
    queue_name => 'requests',
    msg_id     => 11 -- ID of a previous message
);

-- You can also a delete message, disregarding history
SELECT pgmq.delete(
    queue_name => 'requests',
    msg_id     => 10 -- ID of a previous message
);

SELECT * FROM pgmq.metrics_all();

SELECT * FROM pgmq.metrics('requests');



-- EXTERNAL: view pgmq notebook for python example
