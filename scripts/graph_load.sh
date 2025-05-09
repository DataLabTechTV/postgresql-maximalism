#!/bin/sh

set -e

if [ $# -lt 1 ]; then
	echo "Usage: $0 DATA_CACHE_DIR [facebook|twitch]"
	exit 1
fi

if [ -z "$2" ]; then
	graph=facebook
else
	graph=$2
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

download_dataset() {
	data_dir=$1
	dataset_url=$2

	archive_path=$(readlink -f "${data_dir}/$(basename "$dataset_url")")
	dataset_path="${archive_path%.zip}"

	if [ ! -e "$archive_path" ]; then
		echo "==> Downloading $dataset_url into $archive_path" >&2
		curl -L "$dataset_url" -o "$archive_path"
	fi

	if [ ! -d "$dataset_path" ]; then
		if [ -e "$dataset_path" ]; then
			echo "!!! $dataset_path: path exists, but it's not a directory" >&2
			exit 3
		fi

		echo "==> Uncompressing dataset into $dataset_path" >&2
		unzip "$archive_path" -d "$dataset_path"
	fi

	echo "$dataset_path"
}

case $graph in
twitch)
	# https://snap.stanford.edu/data/twitch_gamers.html
	echo "==> Using twitch graph"

	dataset_url=https://snap.stanford.edu/data/twitch_gamers.zip
	dataset_path=$(download_dataset "$data_dir" "$dataset_url")

	echo "==> Creating graph schema and tables graph.nodes and graph.edges"
	psql <<-EOF
		DROP SCHEMA IF EXISTS graph CASCADE;

		CREATE SCHEMA graph;

		CREATE TABLE graph.nodes (
			node_id integer PRIMARY KEY,
			created_at date,
			updated_at date,
			views integer,
			mature boolean,
			life_time integer,
			dead_account boolean,
			language character(5),
			affiliate boolean
		);

		CREATE TABLE graph.edges (
			edge_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
			source_id integer,
			target_id integer
		);
	EOF

	echo "==> Loading data into graph.nodes"
	psql <<-EOF
		\COPY graph.nodes( \
				views, mature, life_time, created_at, updated_at, node_id, \
				dead_account, language, affiliate \
			) \
		FROM '$dataset_path/large_twitch_features.csv' \
		WITH (FORMAT csv, HEADER true)
	EOF

	echo "==> Loading data into graph.edges"
	psql <<-EOF
		\COPY graph.edges(source_id, target_id) \
		FROM '$dataset_path/large_twitch_edges.csv' \
		WITH (FORMAT csv, HEADER true)
	EOF
	;;

facebook)
	# https://snap.stanford.edu/data/facebook-large-page-page-network.html
	echo "==> Using facebook graph"

	dataset_url=https://snap.stanford.edu/data/facebook_large.zip
	dataset_path=$(download_dataset "$data_dir" "$dataset_url")

	echo "==> Creating graph schema and tables graph.nodes and graph.edges"
	psql <<-EOF
		DROP SCHEMA IF EXISTS graph CASCADE;

		CREATE SCHEMA graph;

		CREATE TABLE graph.nodes (
			node_id integer PRIMARY KEY,
			facebook_id varchar(20),
			page_name text,
			page_type text
		);

		CREATE TABLE graph.edges (
			edge_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
			source_id integer,
			target_id integer
		);
	EOF

	echo "==> Loading data into graph.nodes"
	psql <<-EOF
		\COPY graph.nodes \
		FROM '$dataset_path/facebook_large/musae_facebook_target.csv' \
		WITH (FORMAT csv, HEADER true)
	EOF

	echo "==> Loading data into graph.edges"
	psql <<-EOF
		\COPY graph.edges(source_id, target_id) \
		FROM '$dataset_path/facebook_large/musae_facebook_edges.csv' \
		WITH (FORMAT csv, HEADER true)
	EOF
	;;

*)
	echo "!!! unsupported graph: $graph"
	exit 4
	;;
esac
