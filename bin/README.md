# Bin Scripts Documentation

This directory contains executable scripts for convenient application management.

## Available Scripts

### 🚀 bin/server

Start the application server with automatic checks and configuration.

**Usage:**
```bash
bin/server
```

**Features:**
- Checks for `.env` file (offers to create from `.env.example`)
- Validates Ruby version
- Installs dependencies if needed
- Displays server configuration
- Shows useful URLs (app, health check)
- Supports environment variables:
  - `HOST` - Server host (default: 0.0.0.0)
  - `PORT` - Server port (default: 9292)
  - `RACK_ENV` - Environment (default: development)

**Example:**
```bash
# Start on default port 9292
bin/server

# Start on custom port
PORT=3000 bin/server

# Start in production mode
RACK_ENV=production bin/server
```

---

### 🔧 bin/setup

One-command project setup for new installations.

**Usage:**
```bash
bin/setup
```

**What it does:**
1. Checks Ruby version compatibility
2. Creates `.env` from `.env.example` if needed
3. Installs gem dependencies
4. Verifies database connection
5. Checks if database table exists

**When to use:**
- First time cloning the repository
- After pulling major changes
- When setting up a new development environment

---

### 💻 bin/console

Interactive Ruby console with pre-loaded application context.

**Usage:**
```bash
bin/console
```

**Features:**
- Loads environment variables from `.env`
- Connects to database automatically
- Provides `DB` object for queries
- Shows helpful examples on startup

**Examples:**
```ruby
# Count all hits
DB[:hits].count

# Get last 10 hits
DB[:hits].order(:created_at.desc).limit(10).all

# Count hits by host
DB[:hits].group(:host).count

# Filter by IP
DB[:hits].where(ip: '1.2.3.4').all

# Get hits from today
DB[:hits].where{created_at >= Date.today}.count
```

---

### 🐳 bin/docker

Docker Compose wrapper with convenient commands.

**Usage:**
```bash
bin/docker [command]
```

**Commands:**

| Command | Description |
|---------|-------------|
| `up`, `start` | Start services with build (default) |
| `down`, `stop` | Stop all services |
| `restart` | Stop and start services |
| `logs [service]` | Show logs (default: app) |
| `ps`, `status` | Show service status |
| `build` | Build Docker images |
| `clean` | Remove containers and volumes |
| `shell [service]` | Open bash shell (default: app) |
| `db` | Connect to PostgreSQL |
| `health` | Check application health |
| `help` | Show help message |

**Examples:**
```bash
# Start all services
bin/docker up

# Show application logs
bin/docker logs app

# Show database logs
bin/docker logs db

# Connect to PostgreSQL
bin/docker db

# Open shell in app container
bin/docker shell app

# Check health endpoint
bin/docker health

# Restart everything
bin/docker restart

# Clean up (removes data!)
bin/docker clean
```

---

## Workflow Examples

### First Time Setup

```bash
# 1. Setup project
bin/setup

# 2. Start server
bin/server

# 3. In another terminal, check health
curl http://localhost:9292/health
```

### Development Workflow

```bash
# Start server
bin/server

# In another terminal, open console to query data
bin/console

# Check logs
tail -f log/development.log  # if using logging to file
```

### Docker Development

```bash
# Start services
bin/docker up

# In another terminal, view logs
bin/docker logs app

# Check health
bin/docker health

# Connect to database
bin/docker db

# When done
bin/docker down
```

### Database Management

```bash
# Open console
bin/console

# Run queries
DB[:hits].where{created_at >= Date.today}.delete  # Delete today's hits
DB[:hits].truncate  # Clear all hits (careful!)

# Or use bin/docker for PostgreSQL
bin/docker db
# Then use SQL directly
SELECT COUNT(*) FROM hits;
```

---

## Environment Variables

Scripts respect these environment variables:

### bin/server
- `HOST` - Server bind address (default: 0.0.0.0)
- `PORT` - Server port (default: 9292)
- `RACK_ENV` - Environment (development/production)

### All scripts
- `DATABASE_URL` - PostgreSQL connection string
- `ALLOWED_HOSTS` - Comma-separated list of allowed hostnames
- `REDIRECT_URL` - Default redirect destination
- `LOG_LEVEL` - Logging level (DEBUG/INFO/WARN/ERROR)

---

## Troubleshooting

### "Ruby version mismatch"
```bash
# Install correct Ruby version
rbenv install $(cat .ruby-version)

# Or with rvm
rvm install $(cat .ruby-version)
```

### "Database connection failed"
```bash
# Start PostgreSQL with Docker
docker compose up -d db

# Or check local PostgreSQL
pg_isready

# Verify DATABASE_URL in .env
cat .env | grep DATABASE_URL
```

### "Bundle install failed"
```bash
# Update bundler
gem install bundler

# Try again
bundle install
```

### Scripts not executable
```bash
# Make scripts executable
chmod +x bin/*
```

---

## Creating Custom Scripts

To add your own script:

1. Create file in `bin/` directory:
```bash
touch bin/my-script
chmod +x bin/my-script
```

2. Add shebang and content:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# Your script here
puts "Hello from my script!"
```

3. Run it:
```bash
bin/my-script
```

---

## Best Practices

1. **Always use bin/setup first** when cloning the project
2. **Use bin/server** instead of direct `rackup` for better UX
3. **Use bin/console** for database queries instead of raw SQL
4. **Use bin/docker** for Docker operations (cleaner, documented)
5. **Check scripts are executable** after git pull: `chmod +x bin/*`

---

## Contributing

When adding new scripts:
- Make them executable: `chmod +x bin/script-name`
- Add documentation in this file
- Update main README.md if user-facing
- Add examples of usage
- Include error handling
- Show helpful messages

---

*Last updated: February 17, 2026*
