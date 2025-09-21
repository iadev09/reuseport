# 🚧 Build stage
FROM rust:slim AS builder

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    clang \
    build-essential \
    pkg-config \
    libssl-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Copy Cargo.toml and Cargo.lock to build dependencies first (for caching)
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to allow dependency compilation
RUN mkdir src && echo "fn main() {}" > src/main.rs

# IMPORTANT: when building relase version of real binary, change "release" to "debug"
RUN cargo build --release && rm -f target/release/deps/reuseport*

COPY src ./src

# build (debug)
RUN cargo build --bin reuseport

# 🧊 Runtime stage
FROM debian:trixie-slim

# runtime tools: curl + bash
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    bash \
    lsof \
 && rm -rf /var/lib/apt/lists/*

# binary
COPY --from=builder /app/target/debug/reuseport /usr/local/bin/reuseport
RUN chmod +x /usr/local/bin/reuseport

WORKDIR /app
COPY ./tests/test_reuseport.sh ./tests/test_reuseport.sh
RUN chmod +x tests/test_reuseport.sh

# script'in beklediği binary yolu
ENV REUSEPORT=/usr/local/bin/reuseport
ENV PORT=3000
ENV SKIP_BUILD=1

EXPOSE 3000
STOPSIGNAL SIGTERM

ENTRYPOINT ["tests/test_reuseport.sh"]