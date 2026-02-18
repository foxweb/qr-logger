# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version is stored in the `VERSION` file at the root of the project.

## [2.2.0] - 2026-02-18

### ✨ New Features

- **Admin Panel** - New web-based admin interface at `/admin`
  - HTTP Basic Authentication for security
  - Real-time statistics dashboard (total hits, unique IPs, today's hits, hosts count)
  - Comprehensive system information panel:
    - Application version and Ruby version
    - Database status and PostgreSQL version
    - Memory usage and uptime tracking
    - OS information
  - Paginated hits table (50 records per page)
  - Advanced filtering:
    - Filter by IP address
    - Filter by hostname
    - Combined filters support
  - Responsive design with modern UI
  - Russian localization
- **Admin credentials** - Configurable via environment variables:
  - `ADMIN_USER` (default: "admin")
  - `ADMIN_PASSWORD` (default: "changeme")
- **Rate limiting configuration** - Made configurable via ENV:
  - `RATE_LIMIT_GENERAL` - General requests per minute (default: 100)
  - `RATE_LIMIT_HITS` - Hit logging per minute (default: 10)

### 🔧 Refactoring

- **Code organization** - Split monolithic `config.ru` into modules:
  - `app/config.rb` - Configuration and environment variables
  - `app/database.rb` - Database connection and operations
  - `app/hit_log_app.rb` - Main application logic
  - `app/admin.rb` - Admin panel functionality
  - `config.ru` - Middleware and routing (39 lines, was 171)
- **Database module** - Extracted database operations into reusable methods:
  - `Database.log_hit()` - Log hit with validation
  - `Database.get_hits()` - Paginated hits with filters
  - `Database.get_hosts()` - Get unique hosts list
  - `Database.get_stats()` - Calculate statistics
  - `Database.health_check()` - Database health verification
  - `Database.get_postgresql_version()` - Get PostgreSQL version
- **Better separation of concerns** - Clear module boundaries
- **Improved maintainability** - Smaller, focused files

### 🐳 Docker Improvements

- **Removed bundle_path volume** - Gems now installed in Docker image only
  - Faster container startup
  - No need for runtime gem installation
  - Production-ready approach
- **Removed BUNDLE_PATH environment variable** - Use default gem location
- **PostgreSQL upgraded to 17** - Updated from PostgreSQL 15

### 🔒 Security Fixes

- **Rack 3.x compliance** - Fixed header names to lowercase:
  - `'Content-Type'` → `'content-type'`
  - Fixes `Rack::Lint::LintError` in development mode
- **ActiveSupport integration fixed** - Added proper requires:
  - `require 'active_support/isolated_execution_state'`
  - Fixes `NameError: uninitialized constant ActiveSupport::IsolatedExecutionState`

### 📦 Dependencies

- **Added activesupport 8.1.2** - For Rack::Attack cache store
  - Includes: base64, concurrent-ruby, connection_pool, drb, i18n, minitest, tzinfo, uri
- **Updated gems**:
  - rack 3.2.0 → 3.2.5
  - rackup 2.2.1 → 2.3.1
  - All gems updated to latest compatible versions

### 🎨 UI/UX Improvements

- **Admin panel design**:
  - Modern card-based layout
  - Dark-themed system information panel
  - Color-coded status indicators (green for OK, red for errors)
  - Hover effects on table rows
  - Sticky table headers for long lists
  - Mobile-responsive design
- **Better error pages** - Rack::ShowExceptions with detailed error info in development

### 📚 Documentation

- **Added VERSIONING.md** - Complete guide for semantic versioning
  - How to update versions
  - Git tagging workflow
  - Release checklist
- **Added VERSION_IMPLEMENTATION_SUMMARY.md** - Technical implementation details
- **Updated .env.example** - Added new admin credentials and rate limit variables
- **Updated .gitignore** - Added backup files pattern

### 🔧 Technical Improvements

- **Configurable rate limits** - Can be adjusted via environment variables
- **Better IP detection** - Handles X-Forwarded-For header correctly
- **Uptime tracking** - Application start time recorded for monitoring
- **Memory usage monitoring** - RSS memory tracking in admin panel
- **PostgreSQL version detection** - Display in admin panel
- **Better error handling** - All database operations wrapped in error handlers

### ⚠️ Breaking Changes

- **Admin panel requires authentication** - Default credentials MUST be changed in production
- **Docker volume structure changed** - bundle_path volume removed (gems in image)
- **config.ru restructured** - If you have custom middleware, review new structure

### 🔄 Migration from 2.1.0

1. Update `.env` file with new variables:
   ```bash
   ADMIN_USER=your_admin_username
   ADMIN_PASSWORD=your_secure_password
   RATE_LIMIT_GENERAL=100
   RATE_LIMIT_HITS=10
   ```

2. Rebuild Docker image (gems now in image):
   ```bash
   docker compose down
   docker compose build
   docker compose up -d
   ```

3. Access admin panel at `http://localhost:9292/admin`

## [2.1.0] - 2026-02-17

### ⬆️ Upgrades

- **Ruby upgraded to 4.0.1** - Updated from Ruby 3.4.5 to 4.0.1
- **Bundler upgraded to 4.0.6** - Updated from Bundler 2.7.1 to 4.0.6
- **Updated .ruby-version** - Now points to Ruby 4.0.1
- **Updated Dockerfile** - Now uses ruby:4.0.1 base image
- **Regenerated Gemfile.lock** - Updated for Ruby 4.0.1 and Bundler 4.0.6
- **Added logger gem** - Required explicitly in Ruby 4.0 (no longer in stdlib)
- **Updated gems** - pg 1.6.3, puma 7.2.0, sequel 5.101.0, bigdecimal 4.0.1

### ✨ New Features

- **VERSION file** - Single source of truth for application version
  - Version displayed in logs and health check
  - Semantic versioning (SemVer) support
- **bin/server** - Convenient script to start the application
  - Automatic .env setup check
  - Ruby version validation
  - Dependency installation check
  - Server configuration display
- **bin/setup** - One-command project setup
  - Environment file creation
  - Dependency installation
  - Database connection verification
- **bin/console** - Interactive Ruby console
  - Pre-loaded database connection
  - Quick access to DB queries
  - Environment variables access
- **bin/docker** - Docker Compose wrapper
  - Simplified Docker commands
  - Log viewing
  - Database connection
  - Health check
  - Shell access

## [2.0.0] - 2025-02-17

### 🔒 Security Improvements (CRITICAL)

- **Removed hardcoded credentials** - All database credentials moved to environment variables
- **Added rate limiting** - Protection against DDoS and spam (rack-attack)
  - 100 requests per minute per IP (general)
  - 10 hits per minute per IP (logging endpoints)
- **Input validation** - User agent and referer fields sanitized and truncated
- **Host validation** - Configurable allowed hosts list
- **Better IP detection** - Supports X-Forwarded-For and X-Real-IP headers

### ✨ New Features

- **Health check endpoint** - `/health` returns JSON with database status
- **Structured logging** - Timestamps, severity levels, and formatted output
- **Error handling** - Comprehensive error recovery and logging
- **Database indexes** - Added indexes on ip, created_at, host for better performance
- **Environment-based config** - All settings configurable via .env file

### 🐳 Docker Improvements

- **Healthchecks** - Both app and database containers have health monitoring
- **Dependency management** - App waits for database to be healthy
- **Better caching** - Optimized Dockerfile layer caching
- **Environment support** - Full .env file integration

### 📚 Documentation

- **Updated README** - Complete setup and configuration guide
- **Added .env.example** - Template for environment variables
- **Added SECURITY.md** - Security features and best practices
- **Added CHANGELOG.md** - Version history

### 🔧 Technical Changes

- Added gems:
  - `dotenv` - Environment variable management
  - `rack-attack` - Rate limiting and request filtering
- Database improvements:
  - Automatic index creation
  - Connection error handling
  - pg_inet extension enabled
- Code improvements:
  - Frozen string literals
  - Better error messages
  - Cleaner code organization

### 📦 Dependencies

```ruby
gem 'dotenv'       # NEW
gem 'rack-attack'  # NEW
gem 'pg'
gem 'puma'
gem 'rack', '~> 3.2'
gem 'rackup'
gem 'sequel'
```

### ⚠️ Breaking Changes

- **Environment variables required** - Application will not start without proper configuration
- **Database connection string format** - Must use DATABASE_URL environment variable
- **Host validation** - Requests from non-whitelisted hosts will be blocked (444 status)

### 🔄 Migration Guide

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update `.env` with your credentials

3. Run `bundle install` to get new dependencies:
   ```bash
   bundle install
   ```

4. Restart the application

For Docker users:
```bash
docker compose down
docker compose up --build
```

## [1.0.0] - Previous Version

### Features
- Basic hit logging
- Static file serving
- PostgreSQL storage
- Docker support
- Simple redirect functionality
