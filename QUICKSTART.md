# Quick Start Guide

Get up and running with the Zig CRUD API in under 5 minutes!

## Prerequisites

- Docker and Docker Compose installed
- Zig 0.13.0+ (for local development)

## Option 1: Fastest Setup (Docker Only)

```bash
# 1. Start services and run migrations
./setup.sh

# 2. Build and run the API
zig build run
```

That's it! Your API is now running at `http://localhost:8080`

## Option 2: Manual Setup

### Step 1: Start Database Services

```bash
docker compose up -d
```

Wait a few seconds for services to initialize.

### Step 2: Run Migrations

```bash
docker compose exec -T postgres psql -U postgres -d crud_api < migrations/001_create_users_table.sql
```

### Step 3: Build and Run

```bash
zig build run
```

## Verify Installation

### Test with curl

```bash
# Health check
curl http://localhost:8080/health

# Get all users
curl http://localhost:8080/api/users

# Create a user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

# Get user by ID
curl http://localhost:8080/api/users/1

# Update user
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe"}'

# Delete user
curl -X DELETE http://localhost:8080/api/users/1
```

### Test with Make

```bash
make curl-test
```

### Run Test Suite

```bash
./test_api.sh
```

## What's Running?

- **API Server**: `http://localhost:8080`
- **PostgreSQL**: `localhost:5432` (user: `postgres`, password: `password`)
- **Redis**: `localhost:6379`

## Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Connect to database
docker compose exec postgres psql -U postgres -d crud_api

# Connect to Redis
docker compose exec redis redis-cli

# Rebuild application
zig build

# Clean build artifacts
make clean
```

## Troubleshooting

### Port 8080 already in use?

Change the port in `.env`:
```env
PORT=3000
```

### Can't connect to PostgreSQL?

Check if it's running:
```bash
docker compose ps
```

### Can't connect to Redis?

Verify Redis is up:
```bash
docker compose exec redis redis-cli ping
```

Should return `PONG`.

## Next Steps

1. Read the [API Documentation](API.md) for detailed endpoint information
2. Check out the [README](README.md) for advanced configuration
3. Explore the source code in `src/` directory
4. Try modifying the code and see changes in real-time

## Sample API Workflow

```bash
# 1. Create multiple users
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com"}'

curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob","email":"bob@example.com"}'

# 2. List all users (check caching in logs)
curl http://localhost:8080/api/users

# 3. Update a user
curl -X PUT http://localhost:8080/api/users/4 \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice Smith","email":"alice.smith@example.com"}'

# 4. Get updated user
curl http://localhost:8080/api/users/4

# 5. Delete user
curl -X DELETE http://localhost:8080/api/users/4
```

## Development Tips

### Auto-rebuild on changes (requires `entr`)

```bash
# Install entr
brew install entr  # macOS
sudo apt-get install entr  # Linux

# Watch for changes
make watch
```

### Format code

```bash
make format
```

### View database content

```bash
docker compose exec postgres psql -U postgres -d crud_api -c "SELECT * FROM users;"
```

### Monitor Redis cache

```bash
docker compose exec redis redis-cli
> KEYS *
> GET users:all
> TTL users:all
```

## Performance Testing

### Using Apache Bench

```bash
# Install Apache Bench
brew install apache2  # macOS
sudo apt-get install apache2-utils  # Linux

# Test GET endpoint
ab -n 1000 -c 10 http://localhost:8080/api/users

# Test POST endpoint
ab -n 100 -c 5 -p post_data.json -T application/json http://localhost:8080/api/users
```

### Create test data file

```bash
cat > post_data.json << 'EOF'
{"name":"Test User","email":"test@example.com"}
EOF
```

## Environment Variables

Create `.env` file for custom configuration:

```env
DATABASE_URL=postgres://postgres:password@localhost:5432/crud_api
REDIS_URL=redis://localhost:6379
PORT=8080
```

## Stopping Everything

```bash
# Stop API server
Ctrl+C

# Stop Docker services
docker compose down

# Remove volumes (deletes data!)
docker compose down -v
```

## Getting Help

- Read the [full README](README.md)
- Check [API Documentation](API.md)
- Review source code comments
- Open an issue on GitHub

---

**Happy coding! 🚀**