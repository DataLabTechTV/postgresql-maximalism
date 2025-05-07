#!/bin/sh

if [ $# -lt 1 ]; then
    echo "Usage: $0 OUTPUT_DIR"
    exit 1
fi

output_dir=$1
timestamp=$(date +%Y%m%d%H%M)
filename=datalabtech-movie_embeddings_store-${timestamp}.dump

echo "==> Running pg_dump"
docker exec postgresql-maximalism pg_dump -Fc \
    -U datalabtech \
    -h localhost \
    -d datalabtech \
    -t movie_embeddings_store \
    -f "$filename"

echo "==> Copying dump from container to $output_dir/$filename"
docker cp "postgresql-maximalism:$filename" "${output_dir}/"

echo "==> Deleting $filename from container"
docker exec postgresql-maximalism rm "$filename"
