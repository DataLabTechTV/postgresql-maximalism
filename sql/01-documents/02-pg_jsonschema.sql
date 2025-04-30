/*
 * Category: Documents
 * Extension: pg_jsonschema
 * Task: Add schema validation to the request table.
 */



-- CREATE JSON SCHEMA TABLE

DROP SCHEMA IF EXISTS json_schema CASCADE;

CREATE SCHEMA json_schema;

CREATE TABLE json_schema.request (
    id int,
    colname text,
    schema jsonb
);

INSERT INTO json_schema.request
VALUES
    (
        1,
        'params',
        '{
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": {
                "user_id": {
                    "type": "integer"
                },
                "action": {
                    "type": "string",
                    "enum": [
                        "login",
                        "logout",
                        "create_account",
                        "reset_password",
                        "update_profile",
                        "view_dashboard",
                        "purchase_item",
                        "view_order"
                    ]
                },
                "email": {
                    "type": "string",
                    "format": "email"
                },
                "name": {
                    "type": "string"
                },
                "location": {
                    "type": "string"
                },
                "item_id": {
                    "type": "integer"
                },
                "quantity": {
                    "type": "integer"
                },
                "order_id": {
                    "type": "integer"
                }
            },
            "required": ["user_id", "action"],
            "additionalProperties": true
        }'
    ),
    (
        2,
        'response',
        '{
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": {
                "status": {
                    "type": "string",
                    "enum": ["success", "error"]
                },
                "message": {
                    "type": "string"
                }
            },
            "required": ["status", "message"],
            "additionalProperties": false
        }'
    );



-- VALIDATE JSON SCHEMA SYNTAX

SELECT colname, jsonschema_is_valid(schema::JSON)
FROM json_schema.request;



-- CREATE JSON VALIDATION TRIGGER

CREATE OR REPLACE FUNCTION validate_requests_json()
RETURNS trigger AS $$
DECLARE
  params_schema json;
  response_schema json;
BEGIN
  SELECT schema INTO params_schema
  FROM json_schema.request
  WHERE colname = 'params';

  IF NOT jsonschema_is_valid(params_schema) THEN
    RAISE invalid_schema_definition;
  END IF;

  SELECT schema INTO response_schema
  FROM json_schema.request
  WHERE colname = 'response';

  IF NOT jsonschema_is_valid(response_schema) THEN
    RAISE invalid_schema_definition;
  END IF;


  IF NOT jsonb_matches_schema(params_schema, NEW.params) THEN
    RAISE EXCEPTION
        'JSON for ''params'' does not match definition in json_schema.request';
  END IF;

  IF NOT jsonb_matches_schema(response_schema, NEW.response) THEN
    RAISE EXCEPTION
        'JSON for ''response'' does not match definition in json_schema.request';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER validate_requests_json
BEFORE INSERT OR UPDATE ON request
FOR EACH ROW
EXECUTE FUNCTION validate_requests_json();



-- TEST JSON SCHEMA VALIDATION

-- Update the request's response schema with an invalid status enum
UPDATE json_schema.request
SET schema['properties']['status']['enum'] = '10'
WHERE colname = 'response';

-- Confirm that the change was applied
SELECT schema->'properties'->'status'->'enum'
FROM json_schema.request
WHERE colname = 'response';

-- Insert with valid response status
INSERT INTO request (id, params, response)
VALUES
    (11, '{"user_id": 2, "action": "reset_password"}', '{"status": "success", "message": "E-mail sent with link to reset password "}'),
    (12, '{"user_id": 3, "action": "view_dashboard"}', '{"status": "success", "message": "Dashboard loaded successfully"}');

-- Update the request's response schema with the original status enum
UPDATE json_schema.request
SET schema['properties']['status']['enum'] = '["success", "error"]'
WHERE colname = 'response';

-- Confirm that the change was applied
SELECT schema->'properties'->'status'->'enum'
FROM json_schema.request
WHERE colname = 'response';

-- Insert with valid response status again
INSERT INTO request (id, params, response)
VALUES
    (11, '{"user_id": 2, "action": "reset_password"}', '{"status": "success", "message": "E-mail sent with link to reset password "}'),
    (12, '{"user_id": 3, "action": "view_dashboard"}', '{"status": "success", "message": "Dashboard loaded successfully"}');


-- TEST JSON VALIDATION

-- Insert with invalid action param and response status
INSERT INTO request (id, params, response)
VALUES
    (13, '{"user_id": 1, "action": "delete_account"}', '{"status": "success", "message": "Login successful"}'),
    (14, '{"user_id": 1, "action": "view_dashboard"}', '{"status": "warning", "message": "Dashboard loaded successfully"}');

-- Insert with invalid response status only
INSERT INTO request (id, params, response)
VALUES
    (13, '{"user_id": 1, "action": "reset_password"}', '{"status": "success", "message": "Login successful"}'),
    (14, '{"user_id": 1, "action": "view_dashboard"}', '{"status": "warning", "message": "Dashboard loaded successfully"}');

-- Insert with fully valid params and response
INSERT INTO request (id, params, response)
VALUES
    (13, '{"user_id": 1, "action": "reset_password"}', '{"status": "success", "message": "E-mail sent with link to reset password "}'),
    (14, '{"user_id": 1, "action": "view_dashboard"}', '{"status": "success", "message": "Dashboard loaded successfully"}');

-- Update with invalid action param
UPDATE request
SET params['action'] = '"delete_account"',
WHERE id = 1;

-- Update with invalid response status
UPDATE request
SET response['status'] = '"warning"'
WHERE id = 1;

-- Change response schema to accept "warning" status
UPDATE json_schema.request
SET schema = jsonb_set(
    schema,
    '{properties,status,enum}',
    (schema->'properties'->'status'->'enum' || '["warning"]')
)
WHERE colname = 'response';

-- Confirm that the changes were done
SELECT schema->'properties'->'status'->'enum'
FROM json_schema.request
WHERE colname = 'response';

-- Update with now valid response status
UPDATE request
SET response['status'] = '"warning"'
WHERE id = 1;

-- Confirm that the status was updated
SELECT *
FROM request
ORDER BY id;
