#!/bin/sh

if ! which pgbench >/dev/null; then
    echo "pgbench: not found"
    exit 1
fi

#
# Load DB config
#

script_dir=$(dirname "$(realpath "$0")")

# shellcheck source=/dev/null
. "${script_dir}/../../../.env"

export PGHOST
export PGUSER
export PGPASSWORD
export PGDATABASE

#
# Initialize pgbench
#

pgbench_check=$(
    psql -t -c "SELECT to_regclass('public.pgbench_accounts')" |
        tr -d '[:space:]'
)

if [ "$pgbench_check" != "pgbench_accounts" ]; then
    echo "==> pgbench tables not found, initializing"
    pgbench -i
    echo
fi

#
# Run tests
#

echo "==> Running pre stage script"
psql -f "$script_dir/../00-pre.sql"
echo

for sql_script in "$script_dir"/*.sql; do
    echo "==> Testing $(basename "$sql_script")"
    pgbench -f "$sql_script" -T 30
    echo
done

echo "==> Running post stage script"
psql -f "$script_dir/../99-post.sql"
