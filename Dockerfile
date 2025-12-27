FROM rust:bullseye AS build

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

RUN apt update && apt install -y \
  ca-certificates \
  pkg-config \
  libssl-dev \
  libclang-11-dev \
  wget \
  tar

COPY . /src/surfpool

WORKDIR /src/surfpool/

RUN mkdir /out

RUN cargo build --release --bin surfpool --locked

RUN cp /src/surfpool/target/release/surfpool /out

FROM debian:bullseye-slim

# Set default network host
ENV SURFPOOL_NETWORK_HOST=0.0.0.0

RUN apt update && apt install -y ca-certificates libssl-dev wget

# Install Caddy for reverse proxy
RUN wget -O /tmp/caddy.tar.gz https://github.com/caddyserver/caddy/releases/download/v2.7.6/caddy_2.7.6_linux_amd64.tar.gz && \
    tar -xzf /tmp/caddy.tar.gz -C /usr/local/bin caddy && \
    rm /tmp/caddy.tar.gz

COPY --from=build /out/ /bin/
COPY Caddyfile /etc/caddy/Caddyfile

WORKDIR /workspace

# Single port for Railway (Caddy reverse proxy)
EXPOSE 8080

# Create entrypoint that starts both Caddy and surfpool
RUN echo '#!/bin/bash\n\
# Start Caddy reverse proxy in background\n\
caddy start --config /etc/caddy/Caddyfile\n\
\n\
# Start surfpool\n\
exec surfpool start --no-tui\n\
' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
