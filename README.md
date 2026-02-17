# QR logger

Simple rack application for logging IP and useragent into PostgreSQL table with rate limiting and security features.

**Version 2.1.0** | **Ruby 4.0.1** | **Bundler 4.0.6** | **Rack 3.2** | **PostgreSQL 17**

## Features

- 🔒 Environment-based configuration (no hardcoded credentials)
- 🛡️ Rate limiting (100 req/min general, 10 hits/min per IP)
- 📊 Indexed database for better performance
- 🏥 Health check endpoint
- 📝 Structured logging
- 🐳 Docker support with healthchecks
- ⚡ Error handling and recovery

## Quick start (Local)

### Using bin/setup and bin/server (Recommended)

```sh
# One-time setup
bin/setup

# Start the server
bin/server
```

### Manual setup

1. Copy environment file:
```sh
cp .env.example .env
```

2. Edit `.env` with your settings (optional)

3. Install dependencies and run:
```sh
bundle install
rackup
```

## Docker start

### Using bin/docker (Recommended)

```sh
# Start services
bin/docker up

# Other useful commands
bin/docker logs       # Show logs
bin/docker db         # Connect to database
bin/docker health     # Check application health
bin/docker help       # Show all commands
```

### Manual Docker commands

1. Copy environment file:
```sh
cp .env.example .env
```

2. Edit `.env` if needed, then start:
```sh
docker compose up --build
```

The application will be available at `http://localhost:9292`

## Environment Variables

See `.env.example` for all available configuration options:

- `DATABASE_URL` - PostgreSQL connection string
- `ALLOWED_HOSTS` - Comma-separated list of allowed hostnames
- `REDIRECT_URL` - Default redirect destination
- `LOG_LEVEL` - Logging level (DEBUG, INFO, WARN, ERROR)

## Endpoints

- `GET /` - Static landing page
- `GET /y` or `GET /youtube` - Log hit and redirect
- `GET /test` - Display user agent and IP (for testing)
- `GET /health` - Health check (returns JSON with status)

## Security Features

- No hardcoded credentials
- Rate limiting per IP address
- Input validation and sanitization
- Host validation
- Comprehensive error handling
- Database connection pooling

## Convenience Scripts

The `bin/` directory contains helpful scripts:

| Script | Description |
|--------|-------------|
| `bin/server` | Start the application server with automatic setup checks |
| `bin/setup` | Initial project setup (install deps, create .env, check DB) |
| `bin/console` | Interactive Ruby console with database access |
| `bin/docker` | Docker Compose wrapper with useful commands |

### Examples

```sh
# Setup project (first time)
bin/setup

# Start development server
bin/server

# Open console to query database
bin/console

# Start with Docker
bin/docker up

# View logs
bin/docker logs app

# Connect to PostgreSQL
bin/docker db

# Check application health
bin/docker health
```

## Versioning

The application uses **Semantic Versioning** via a `VERSION` file.

Current version is included in:
- Health check response (`/health`)
- Application logs on startup
- Docker container metadata

See [VERSIONING.md](VERSIONING.md) for details.

## Monitoring

Health check endpoint returns:
```json
{
  "status": "healthy",
  "version": "2.1.0",
  "database": "ok",
  "timestamp": "2026-02-17T..."
}
```

Use for Docker healthcheck or monitoring tools.
