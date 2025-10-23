# Learn Zig

A production-ready CRUD REST API built with Zig, featuring PostgreSQL for data persistence and Redis for caching.

## Features

- ✅ RESTful API endpoints (Create, Read, Update, Delete)
- ✅ PostgreSQL integration with connection pooling
- ✅ Redis caching layer
- ✅ JSON serialization/deserialization
- ✅ Middleware (logging, error handling)
- ✅ Docker support
- ✅ Environment configuration
- ✅ Database migrations

## Prerequisites

- Zig 0.15 or later
- Docker and Docker Compose (for local development)
- PostgreSQL 18+
- Redis 8+

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo>
cp .env.example .env
```

### 2. Start Services with Docker

```bash
docker compose up -d
```

### 3. Run Migrations

```bash
psql -h localhost -U postgres -d crud_api -f migrations/001_create_users_table.sql
```

### 4. Build and Run

```bash
zig build run
```

The API will be available at `http://localhost:8080`

## API Endpoints

### Users

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users` | Get all users |
| GET | `/api/users/:id` | Get user by ID |
| POST | `/api/users` | Create new user |
| PUT | `/api/users/:id` | Update user |
| DELETE | `/api/users/:id` | Delete user |

### Example Requests

**Create User:**

```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

**Get All Users:**

```bash
curl http://localhost:8080/api/users
```

**Get User by ID:**

```bash
curl http://localhost:8080/api/users/1
```

**Update User:**

```bash
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com"}'
```

**Delete User:**

```bash
curl -X DELETE http://localhost:8080/api/users/1
```

## Environment Variables

Create a `.env` file:

```env
DATABASE_URL=postgres://postgres:password@localhost:5432/crud_api
REDIS_URL=redis://localhost:6379
PORT=8080
```

## Development

### Building

```bash
zig build
```

### Running Tests

```bash
zig build test
```

### Docker Build

```bash
docker build -t zig-crud-api .
docker run -p 8080:8080 --env-file .env zig-crud-api
```

## Project Structure

- `src/main.zig` - Application entry point
- `src/server.zig` - HTTP server implementation
- `src/router.zig` - Route definitions
- `src/handlers/` - Request handlers
- `src/models/` - Data models
- `src/db/` - Database connections
- `src/middleware/` - Middleware functions
- `src/config.zig` - Configuration management

## License

MIT
