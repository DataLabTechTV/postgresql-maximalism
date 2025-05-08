#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 [-c] DUMP_FILE"
    exit 1
fi

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/../.env"

pg_user=${PGUSER:-postgres}
pg_database=${PGDATABASE:-postgres}

if [ "$1" = "-c" ]; then
    shift

    echo "==> DROP TABLE movie_embeddings_store CASCADE"
    docker exec postgresql-maximalism psql \
        -U "$pg_user" \
        -h localhost \
        -d "$pg_database" \
        -c "DROP TABLE movie_embeddings_store CASCADE"
fi

path=$(readlink -f "$1")
filename=$(basename "$path")

echo "==> Copying $path to container"
docker cp "$path" "postgresql-maximalism:."

echo "==> Running pg_restore on container"
docker exec postgresql-maximalism pg_restore \
    -U "$pg_user" \
    -h localhost \
    -d "$pg_database" \
    -t movie_embeddings_store \
    "$filename"

echo "==> Deleting $filename from container"
docker exec postgresql-maximalism rm "$filename"
