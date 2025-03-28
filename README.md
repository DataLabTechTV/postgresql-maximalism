# postgresql-maximalism

A repository dedicated to using PostgreSQL for everything.

A docker image will be built based on PostgreSQL 16, containing the following selection of extensions:

| Name | Category | Description |
|------|----------|-------------|
| [pg_jsonschema](https://github.com/supabase/pg_jsonschema) | Document Store | Ensures a JSON schema is respected for JSON or JSONB. |
| [pg_mooncake](https://github.com/Mooncake-Labs/pg_mooncake) | Column Store and Analytics | Adds support for Iceberg and Delta Lake, along with DuckDB based analytics. |
| [timescaledb](https://github.com/timescale/timescaledb) | Time Series Store and Real-Time | Adds performance improvements, like partitioning or incremental views, to handle large scale time series data efficiently and in real-time. |
| [pgvector](https://github.com/pgvector/pgvector) | Vector Store | Adds two approximate indexing approaches along with functions to efficiently compute vector similarities. |
| [pg_search](https://github.com/paradedb/paradedb) | Full-Text Search | Extends full-text search capabilities with Lucene-like features, based on [Tantivy](https://github.com/quickwit-oss/tantivy), like segmented indexing, BM25 scoring, tokenizers, or stemming. |
| [pgrouting](https://github.com/pgRouting/pgrouting) | Graph Analytics | While no specialized graph storage is provided (i.e., no index-free adjacency), this adds several useful graph algorithms, like shortest-distance (e.g., Dijkstra, A*, Floyd-Warshall), centralities (betweenness), or minimum spanning tree (Kruskal, Prim). |
| [pgmq](https://github.com/tembo-io/pgmq) | Message Queuing | Supports multiple queues, with read/write operations. Similar to [AWS SQS](https://aws.amazon.com/sqs/) or [RSMQ](https://github.com/smrchy/rsmq). |

## Requirements

- Docker (>= 20.10.0, with `docker compose`)

## Setup

After cloning the repository, copy the `.env.example` to `.env` and replace the values with your own username, password, and database name:

```bash
POSTGRES_USER=<username>
POSTGRES_PASSWORD=<password>
POSTGRES_DB=<database>
```

You can then build the image and start a PostgreSQL 16 container named `postgresql-maximalism`:

```bash
docker compose up --build -d
```

## Connecting

You can then connect to the database using whatever client you prefer. For example, on Debian 12, you can install the `psql` client as follows:

```bash
sudo curl -o /usr/share/keyrings/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

sudo apt install -y postgresql-client-16
```

And you establish a link to PostgreSQL by running the following command and using the same values as the ones configured in the `.env`:

```bash
psql -h localhost -u <username>
```

This will interactively ask you for the password.

## Extensions

All extensions should be created and ready to use. You can list available extensions as follows:

```sql
SELECT extname FROM pg_extension;
```
