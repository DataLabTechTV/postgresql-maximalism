FROM quay.io/tembo/timeseries-pg:v0.1.7

USER root

RUN apt-get update && apt-get install -y \
    postgresql-server-dev-16 build-essential liblz4-dev \
    cmake curl flex bison git

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source $HOME/.cargo/env && \
    rustup update stable

ENV PATH="/root/.cargo/bin:$PATH"

#
# Apache AGE
#

RUN git clone \
    --branch PG16/v1.5.0-rc0 \
    --depth 1 \
    https://github.com/apache/age \
    /tmp/ACE

RUN cd /tmp/ACE \
    && make \
    && make install \
    && rm -rf /tmp/ACE

#
# pg_mooncake
#

RUN git clone \
    --branch v0.1.2 \
    --depth 1 \
    https://github.com/Mooncake-Labs/pg_mooncake \
    /tmp/pg_mooncake

RUN cd /tmp/pg_mooncake \
    && git submodule update --init --recursive \
    && make release -j$(nproc) \
    && make install \
    && rm -rf /tmp/pg_mooncake

USER postgres

CMD ["postgres"]
