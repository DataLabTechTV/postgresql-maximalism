FROM postgres:16 AS base

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


FROM base AS builder_pgrx_0_12_9

RUN cargo install --locked cargo-pgrx --version 0.12.9
RUN cargo pgrx init --pg16=/usr/lib/postgresql/16/bin/pg_config


FROM base AS builder_pgrx_0_13_0

RUN cargo install --locked cargo-pgrx --version 0.13.0
RUN cargo pgrx init --pg16=/usr/lib/postgresql/16/bin/pg_config


#
# pg_jsonschema
#

FROM builder_pgrx_0_12_9 AS build-pg_jsonschema

RUN git clone --depth 1 https://github.com/supabase/pg_jsonschema \
    && cd pg_jsonschema \
    && git fetch origin 14e6d7b53a2ef43048be67db79335e19a9345ade \
    && git checkout 14e6d7b53a2ef43048be67db79335e19a9345ade \
    && cargo pgrx install --release


#
# pg_mooncake
#

FROM base AS build-pg_mooncake

RUN git clone https://github.com/Mooncake-Labs/pg_mooncake \
    && cd pg_mooncake \
    && git config user.email "204358040+DataLabTechTV@users.noreply.github.com" \
    && git config user.name "Data Lab Tech" \
    && git remote add fork https://github.com/raghunandanbhat/pg_mooncake \
    && git fetch fork \
    && git checkout v0.1.2 \
    && git merge --no-edit --strategy ours fork/ceph-storage \
    && git submodule update --init --recursive \
    && make release -j$(nproc) \
    && make install


#
# timescaledb
#

FROM base AS build-timescaledb

RUN git clone --branch 2.19.0 --depth 1 https://github.com/timescale/timescaledb \
    && cd timescaledb \
    && ./bootstrap \
    && cd build \
    && make \
    && make install


FROM builder_pgrx_0_12_9 AS build-timescaledb-toolkit

RUN git clone --branch 1.21.0 --depth 1 \
        https://github.com/timescale/timescaledb-toolkit \
    && cd timescaledb-toolkit/extension \
    && cargo pgrx install --release \
    && cargo run --manifest-path ../tools/post-install/Cargo.toml -- pg_config


#
# pgvector
#

FROM base AS build-pgvector

RUN git clone --branch v0.8.0 --depth 1 https://github.com/pgvector/pgvector \
    && cd pgvector \
    && make \
    && make install


#
# pgvectorscale
#

FROM builder_pgrx_0_12_9 AS build-pgvectorscale

RUN git clone --branch 0.7.1 --depth 1 https://github.com/timescale/pgvectorscale \
    && cd pgvectorscale/pgvectorscale \
    && cargo pgrx install --release


#
# pgai
#

FROM base AS build-pgai

RUN apt-get update && apt-get install -y python3-pip postgresql-plpython3-16

RUN git clone --branch pgai-v0.9.2 --depth 1 https://github.com/timescale/pgai \
    && cd pgai \
    && projects/extension/build.py build-install

RUN pip3 install --prefix=/extra-python-packages scipy powerlaw scikit-learn


#
# ParadeDB (pg_search)
#

FROM builder_pgrx_0_13_0 AS build-paradedb

RUN git clone --branch v0.15.11 --depth 1 https://github.com/paradedb/paradedb \
    && cd paradedb/pg_search \
    && cargo pgrx install


#
# postgis
#

FROM base AS build-postgis

RUN apt-get -y install docbook-xsl-ns gettext libgdal-dev libgeos-dev libjson-c-dev \
    libproj-dev libprotobuf-c-dev libsfcgal-dev libxml2-dev libxml2-utils \
    protobuf-c-compiler xsltproc

RUN git clone --branch 3.5.2 --depth 1 https://git.osgeo.org/gitea/postgis/postgis \
    && cd postgis \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install


#
# pgrouting
#

FROM base AS build-pgrouting

RUN apt-get install -y libboost1.81-dev

RUN git clone --branch v3.7.3 --depth 1 https://github.com/pgRouting/pgrouting \
    && cd pgrouting \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && make install


#
# pg_partman
#

FROM base AS build-pg_partman

RUN git clone --branch v5.2.4 --depth 1 https://github.com/pgpartman/pg_partman \
    && cd pg_partman \
    && make \
    && make install


#
# pgmq
#

FROM base AS build-pgmq

RUN git clone --branch v1.5.1 --depth 1 https://github.com/tembo-io/pgmq \
    && cd pgmq/pgmq-extension \
    && make \
    && make install


#
# Main
#

FROM postgres:16

COPY --from=build-pg_jsonschema /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pg_jsonschema /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pg_mooncake /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pg_mooncake /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-timescaledb /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-timescaledb /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/
COPY --from=build-timescaledb-toolkit /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-timescaledb-toolkit /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pgvector /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pgvector /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pgvectorscale /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pgvectorscale /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pgai /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pgai /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/
COPY --from=build-pgai /usr/local/lib/pgai /usr/local/lib/pgai
COPY --from=build-pgai /extra-python-packages /usr

COPY --from=build-paradedb /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-paradedb /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-postgis /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-postgis /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pgrouting /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pgrouting /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pg_partman /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pg_partman /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

COPY --from=build-pgmq /usr/lib/postgresql/16/lib/* \
    /usr/lib/postgresql/16/lib/
COPY --from=build-pgmq /usr/share/postgresql/16/extension/* \
    /usr/share/postgresql/16/extension/

RUN apt-get update && apt-get install -y libproj25 libgeos-c1v5 libxml2 gettext \
    libjson-c5 libgdal32 libsfcgal1 libprotobuf-c1 postgresql-plpython3-16 python3

CMD ["postgres"]
