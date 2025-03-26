FROM quay.io/tembo/timeseries-pg:v0.1.7 AS base

USER root

ENV PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config

RUN apt-get update && apt-get install -y \
    postgresql-server-dev-16 build-essential pkg-config \
    liblz4-dev libssl-dev libclang-dev \
    cmake curl flex bison git

RUN git config --global advice.detachedHead false

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . /root/.cargo/env \
    && rustup update stable

ENV PATH="/root/.cargo/bin:$PATH"

RUN cargo install --locked cargo-pgrx --version 0.13.0
RUN cargo pgrx init --pg16=/usr/lib/postgresql/16/bin/pg_config


#
# Apache AGE
#

FROM base AS build-age

RUN git clone --branch PG16/v1.5.0-rc0 --depth 1 https://github.com/apache/age \
    && cd age \
    && make \
    && make install


#
# pg_mooncake
#

FROM base AS build-pg_mooncake

RUN git clone --branch v0.1.2 --depth 1 https://github.com/Mooncake-Labs/pg_mooncake \
    && cd pg_mooncake \
    && git submodule update --init --recursive \
    && make release -j$(nproc) \
    && make install


#
# ParadeDB (pg_search)
#

FROM base AS build-pgvector

RUN git clone --branch v0.8.0 --depth 1 https://github.com/pgvector/pgvector \
    && cd pgvector \
    && make \
    && make install

FROM base AS build-paradedb

RUN git clone --branch v0.15.11 --depth 1 https://github.com/paradedb/paradedb \
    && cd paradedb/pg_search \
    && cargo pgrx install


#
# Main
#

FROM postgres:16

# pg_timeseries
COPY --from=base /usr/lib/postgresql/16/lib/* /usr/lib/postgresql/16/lib/
COPY --from=base /usr/share/postgresql/16/extension/* /usr/share/postgresql/16/extension/

COPY --from=build-age /usr/lib/postgresql/16/lib/* /usr/lib/postgresql/16/lib/
COPY --from=build-age /usr/share/postgresql/16/extension/* /usr/share/postgresql/16/extension/

COPY --from=build-pg_mooncake /usr/lib/postgresql/16/lib/* /usr/lib/postgresql/16/lib/
COPY --from=build-pg_mooncake /usr/share/postgresql/16/extension/* /usr/share/postgresql/16/extension/

COPY --from=build-pgvector /usr/lib/postgresql/16/lib/* /usr/lib/postgresql/16/lib/
COPY --from=build-pgvector /usr/share/postgresql/16/extension/* /usr/share/postgresql/16/extension/

COPY --from=build-paradedb /usr/lib/postgresql/16/lib/* /usr/lib/postgresql/16/lib/
COPY --from=build-paradedb /usr/share/postgresql/16/extension/* /usr/share/postgresql/16/extension/

CMD ["postgres"]
