#!/bin/sh

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 DATA_CACHE_DIR"
    exit 1
fi

if ! which curl >/dev/null; then
    echo "!!! curl: not found"
    exit 2
fi

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# shellcheck source=/dev/null
. "$SCRIPT_DIR/../.env"

export PGUSER
export PGPASSWORD
export PGHOST
export PGDATABASE

data_dir=$(readlink -f "$1")
dataset_url=https://snap.stanford.edu/data/twitch_gamers.zip
archive_path=${data_dir}/$(basename $dataset_url)
dataset_path=${archive_path%.zip}

if [ ! -e "$archive_path" ]; then
    echo "==> Downloading $dataset_url into $archive_path"
    curl -L $dataset_url -o "$archive_path"
fi

if [ ! -d "$dataset_path" ]; then
    if [ -e "$dataset_path" ]; then
        echo "!!! $dataset_path: path exists, but it's not a directory"
        exit 3
    fi

    echo "==> Uncompressing dataset into $dataset_path"
    unzip "$archive_path" -d "$dataset_path"
fi

echo "==> Creating twitch schema and tables twitch.nodes and twitch.edges"
psql <<EOF
DROP SCHEMA IF EXISTS twitch CASCADE;

CREATE SCHEMA twitch;

CREATE TABLE twitch.nodes (
    numeric_id integer PRIMARY KEY,
    created_at date,
    updated_at date,
    views integer,
    mature boolean,
    life_time integer,
    dead_account boolean,
    language character(5),
    affiliate boolean
);

CREATE TABLE twitch.edges (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    numeric_id_1 integer,
    numeric_id_2 integer
);
EOF

echo "==> Loading data into twitch_graph"
psql <<EOF
\COPY twitch.nodes( \
        views, mature, life_time, created_at, updated_at, numeric_id, \
        dead_account, language, affiliate \
    ) \
FROM '$dataset_path/large_twitch_features.csv' \
WITH (FORMAT csv, HEADER true)

\COPY twitch.edges(numeric_id_1, numeric_id_2) \
FROM '$dataset_path/large_twitch_edges.csv' \
WITH (FORMAT csv, HEADER true)
EOF
