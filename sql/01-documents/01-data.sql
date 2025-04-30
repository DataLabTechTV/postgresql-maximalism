/*
 * Category: Documents
 * Task: Prepare example JSON data.
 */

DROP TABLE IF EXISTS request;

CREATE TABLE request (
    id integer PRIMARY KEY,
    submit_time timestamp without time zone DEFAULT now(),
    params jsonb,
    response jsonb
);

INSERT INTO request (id, submit_time, params, response)
VALUES
    (1, '2025-04-01 08:00:00', '{"user_id": 1, "action": "login"}', '{"status": "success", "message": "Login successful"}'),
    (2, '2025-04-01 08:05:00', '{"user_id": 1, "action": "view_dashboard"}', '{"status": "success", "message": "Dashboard loaded successfully"}'),
    (3, '2025-04-01 08:10:00', '{"user_id": 2, "action": "create_account", "email": "user2@example.com"}', '{"status": "success", "message": "Account created successfully"}'),
    (4, '2025-04-01 08:15:00', '{"user_id": 2, "action": "login"}', '{"status": "success", "message": "Login successful"}'),
    (5, '2025-04-01 08:20:00', '{"user_id": 3, "action": "login"}', '{"status": "success", "message": "Login successful"}'),
    (6, '2025-04-01 08:25:00', '{"user_id": 3, "action": "reset_password", "email": "user3@example.com"}', '{"status": "error", "message": "Invalid email address"}'),
    (7, '2025-04-01 08:30:00', '{"user_id": 4, "action": "login"}', '{"status": "success", "message": "Login successful"}'),
    (8, '2025-04-01 08:35:00', '{"user_id": 4, "action": "update_profile", "name": "John Doe", "location": "New York"}', '{"status": "success", "message": "Profile updated successfully"}'),
    (9, '2025-04-01 08:40:00', '{"user_id": 1, "action": "logout"}', '{"status": "success", "message": "Logout successful"}'),
    (10, '2025-04-01 08:45:00', '{"user_id": 2, "action": "logout"}', '{"status": "success", "message": "Logout successful"}');
