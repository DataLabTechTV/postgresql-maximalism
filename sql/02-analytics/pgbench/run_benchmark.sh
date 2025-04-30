#!/bin/sh

if ! which pgbench >/dev/null; then
    echo "pgbench: missing"
    exit 1
fi

script_dir=$(dirname "$(realpath "$0")")

# shellcheck source=/dev/null
. "${script_dir}/../../../.env"

export PGHOST
export PGUSER
export PGPASSWORD
export PGDATABASE

# Initialize pgbench
pgbench -i

# Run tests
for sql_script in *.sql; do
    printf "\n==> Testing %s\n" "$sql_script"
    pgbench -f "$sql_script" -T 30
done
