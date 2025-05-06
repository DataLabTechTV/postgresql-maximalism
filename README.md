# postgresql-maximalism

A repository dedicated to using PostgreSQL for everything.

A docker image will be built based on PostgreSQL 16, containing the following selection of extensions:

| Name | Category | Description |
|------|----------|-------------|
| [pg_jsonschema](https://github.com/supabase/pg_jsonschema) | Documents | Ensures a JSON schema is respected for JSON or JSONB. |
| [pg_mooncake](https://github.com/Mooncake-Labs/pg_mooncake) | Analytics & Time Series | Support for Iceberg and Delta Lake, along with DuckDB based analytics. |
| [timescaledb](https://github.com/timescale/timescaledb) | Analytics & Time Series | Adds performance improvements, like partitioning or incremental views, to handle large scale time series data efficiently and in real-time. |
| [pgvector](https://github.com/pgvector/pgvector) | Vectors & AI | Two approximate indexing approaches, along with functions to efficiently compute vector similarities. |
| [pgai](https://docs.timescale.com/ai/latest/) | Vectors & AI / Search | Hugging Face dataset loading, text chunking and embedding, LLM support and RAG, similarity search. |
| [pg_search](https://github.com/paradedb/paradedb) | Search | Extends full-text search capabilities with Lucene-like features, based on [Tantivy](https://github.com/quickwit-oss/tantivy), like segmented indexing, BM25 scoring, tokenizers, or stemming. |
| [pgrouting](https://github.com/pgRouting/pgrouting) | Graphs | While no specialized graph storage is provided (i.e., no index-free adjacency), this adds several useful graph algorithms, like shortest-distance (e.g., Dijkstra, A*, Floyd-Warshall), centralities (betweenness), or minimum spanning tree (Kruskal, Prim). |
| [pgmq](https://github.com/tembo-io/pgmq) | Message Queues | Supports multiple queues, with read/write operations. Similar to [AWS SQS](https://aws.amazon.com/sqs/) or [RSMQ](https://github.com/smrchy/rsmq). |

## Requirements

- Docker (>= 20.10.0, with `docker compose`)

## Setup

After cloning the repository, copy the `.env.example` to `.env` and replace the values with your own username, password, and database name:

```bash
PGUSER=<username>
PGPASSWORD=<password>
PGDATABASE=<database>
```

And do the same for the MinIO variables:

```bash
MINIO_ROOT_USER=<username>
MINIO_ROOT_PASSWORD=<password>
MINIO_BUCKET_NAME=<bucket>
```

We create a builder with `max-parallelism=1`, as most builds are already individually parallelized. Building without this option might result in a freeze due to system overload, but feel free to increase the value, or skip this step altogether. You can build the image and start the containers for WhoDB, MinIO and PostgreSQL 16 by running the following commands:

```bash
docker buildx create \
    --name psql-max-builder \
    --driver docker-container \
    --platform linux/amd64 \
    --config buildkitd.toml \
    --use
docker compose up --build -d
```

## Connecting

You can then connect to the database using whichever client you prefer. For example, on Debian 12, you can install the `psql` client as follows:

```bash
sudo curl -o /usr/share/keyrings/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt install -y postgresql-client-16
```

And you establish a link to PostgreSQL by loading the `.env` and running the following command:

```bash
eval export $(cat .env)
psql
```

This will load the configured PostgreSQL environment variables, which are used by default by most PostgreSQL utilities.

## Extensions

All extensions should be created and ready to use. You can list available extensions by typing `\dx` or by using the following equivalent query:

```sql
SELECT
    e.extname AS "Name",
    e.extversion as "Version",
    n.nspname AS "Schema",
    d.description AS "Description"
FROM
    pg_extension e
    LEFT JOIN pg_namespace n
    ON e.extnamespace = n.oid
    LEFT JOIN pg_description d
    ON e.oid = d.objoid
ORDER BY
    e.extname;
```
