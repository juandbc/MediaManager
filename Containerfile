FROM node:24-alpine AS frontend-build
WORKDIR /frontend

COPY web/package*.json ./
RUN npm ci

COPY web/ ./

ARG VERSION
ARG BASE_PATH=""
RUN env PUBLIC_VERSION=${VERSION} PUBLIC_API_URL=${BASE_PATH} BASE_PATH=${BASE_PATH}/web npm run build

FROM ghcr.io/astral-sh/uv:python3.13-trixie-slim AS base

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates bash libtorrent21 \
    gcc bc locales media-types mailcap curl gzip unzip tar 7zip bzip2 unar gosu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

FROM base AS app
WORKDIR /app

ENV UV_CACHE_DIR=/home/mediamanager/.cache/uv \
    UV_LINK_MODE=copy

COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/home/mediamanager/.cache/uv \
    uv sync --locked

ARG VERSION
ARG BASE_PATH=""
LABEL author="github.com/juandbc"
LABEL version=${VERSION}
LABEL description="Docker image for MediaManager"

ENV PUBLIC_VERSION=${VERSION} \
    CONFIG_DIR="/app/config" \
    BASE_PATH=${BASE_PATH} \
    FRONTEND_FILES_DIR="/app/web/build"

COPY --chmod=755 mediamanager-startup.sh .
COPY config.example.toml .
COPY media_manager ./media_manager
COPY alembic ./alembic
COPY alembic.ini .

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000${BASE_PATH}/api/v1/health || exit 1

EXPOSE 8000
CMD ["/app/mediamanager-startup.sh"]

FROM app AS production
COPY --from=frontend-build /frontend/build /app/web/build
