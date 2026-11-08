# Builds dopplerprint from source via maturin (Rust core + Python bindings).
# Runtime runs the built-in browser app: `dopplerprint serve` (no auth — keep
# it behind a reverse proxy / on a trusted LAN).
FROM python:3.12-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates build-essential \
    && rm -rf /var/lib/apt/lists/*

# dp-core requires Rust >= 1.90; rustup installs current stable.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path

COPY . /src
WORKDIR /src

# abi3 wheel (py311+) so the runtime's python 3.12 accepts it.
RUN pip install --no-cache-dir maturin \
    && maturin build --release -i python3.12 -o /wheels --strip

FROM python:3.12-slim

COPY --from=builder /wheels/ /tmp/wheels/
RUN pip install --no-cache-dir /tmp/wheels/*.whl && rm -rf /tmp/wheels

# /data is the persistent volume Runtipi mounts (ads-b cache, jobs, results).
ENV DOPPLERPRINT_CACHE=/data/cache
RUN mkdir -p /data/cache /data/jobs
WORKDIR /data

EXPOSE 8737
CMD ["dopplerprint", "serve", "--host", "0.0.0.0"]
