#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 OUTPUT_DIR"
    exit 1
fi

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/../.env"

pg_user=${PGUSER:-postgres}
pg_database=${PGDATABASE:-postgres}

output_dir=$(readlink -f "$1")
latest_dir=${output_dir}/latest
timestamp=$(date +%Y%m%d%H%M)
base_filename=$pg_database-movie_embeddings_store
filename=${base_filename}-${timestamp}.dump
latest_filename=${base_filename}.dump

echo "==> Running pg_dump on container"
docker exec postgresql-maximalism pg_dump -Fc \
    -U "$pg_user" \
    -h localhost \
    -d "$pg_database" \
    -t movie_embeddings_store \
    -f "$filename"

echo "==> Copying dump from container to $output_dir/$filename"
docker cp "postgresql-maximalism:$filename" "${output_dir}/"

echo "==> Deleting $filename from container"
docker exec postgresql-maximalism rm "$filename"

echo "==> Updating latest symlink for ${base_filename}"
mkdir -p "$latest_dir" &&
    ln -s -f "${output_dir}/${filename}" "${latest_dir}/${latest_filename}" ||
    echo "!!! Could not create $latest_dir"
