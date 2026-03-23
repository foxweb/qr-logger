# syntax=docker/dockerfile:1

# Multi-stage: compile native gems (pg, puma/nio4r) in builder; runtime image stays small (no gcc/libpq-dev).
# Build for amd64 VPS: docker buildx build --platform linux/amd64 -t foxweb/qr-logger:latest .
# Or: docker compose build app

FROM ruby:4.0.2-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  libpq-dev \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install

FROM ruby:4.0.2-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl \
  libpq5 \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .

EXPOSE 9292

CMD ["/bin/bash"]
