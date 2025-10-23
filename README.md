# Learn Zig - CRUD REST API

A production-ready CRUD REST API built with Zig 0.15.2, featuring PostgreSQL 18 for data persistence and Redis 8 for caching. Uses native Zig libraries (pg.zig and zig-okredis) with zero C dependencies.

## 🚀 Features

- ✅ **RESTful API** - Complete CRUD operations for user management
- ✅ **PostgreSQL 18** - Native Zig driver (pg.zig) with connection pooling
- ✅ **Redis 8** - Zero-allocation client (zig-okredis) with high performance
- ✅ **JSON Support** - Built-in serialization/deserialization
- ✅ **Concurrent Requests** - Thread-based request handling
- ✅ **Docker Support** - Easy deployment with Docker Compose
- ✅ **Database Migrations** - Version-controlled schema changes
- ✅ **Error Handling** - Comprehensive error responses
- ✅ **Cache Invalidation** - Automatic cache cleanup on updates

## 📋 Prerequisites

- **Zig** (latest version from Alpine package repository)
- **Docker** and **Docker Compose** (for local development)
- **No C dependencies required!** - Pure Zig implementation

## 🏃 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo>
cd learn-zig
```

### 2. Start Services (Automated)

```bash
./setup.sh
```

This script will:
- Create `.env` file with default configuration
- Start PostgreSQL and Redis containers
- Wait for services to be ready
- Run database migrations
- Insert sample data

### 3. Build and Run

```bash
# Build the application
zig build

# Run the application
zig build run
```

The API will be available at `http://localhost:8080`

## 🐳 Docker Deployment

### Start Services

```bash
docker compose up -d
```

### Run Migrations

```bash
make migrate
```

## 📚 API Endpoints

### Health Check

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Check server status |

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

For complete API documentation, see [API.md](API.md)

## ⚙️ Configuration

### Environment Variables

Create a `.env` file:

```env
DATABASE_URL=postgres://postgres:password@localhost:5432/crud
REDIS_URL=redis://localhost:6379
PORT=8080
```

### Default Values

If environment variables are not set, the application uses these defaults:
- **Database**: `postgres://postgres:password@localhost:5432/crud`
- **Redis Host**: `localhost`
- **Redis Port**: `6379`
- **Server Port**: `8080`

## 🗂️ Project Structure

```
learn-zig/
├── src/
│   ├── main.zig              # Application entry point
│   ├── config.zig            # Configuration management
│   ├── server.zig            # HTTP server implementation
│   ├── router.zig            # Route definitions and handling
│   ├── db/
│   │   ├── postgres.zig      # PostgreSQL connection pool
│   │   └── redis.zig         # Redis client wrapper
│   ├── handlers/
│   │   └── users.zig         # User CRUD handlers
│   └── models/
│       └── user.zig          # User model and JSON serialization
├── migrations/
│   └── 001_create_users_table.sql
├── build.zig                 # Build configuration
├── compose.yml               # Docker Compose setup
├── Dockerfile               # Multi-stage Docker build (Alpine + scratch)
├── Makefile                 # Development commands
├── setup.sh                 # Automated setup script
├── test_api.sh             # API test suite
└── README.md               # This file
```

## 🔨 Development

### Build

```bash
make build
# or
zig build
```

### Run

```bash
make run
# or
zig build run
```

### Test

```bash
# Run Zig tests
make test

# Run API integration tests
./test_api.sh

# Quick API test with curl
make curl-test
```

### Format Code

```bash
make format
```

### Clean Build Artifacts

```bash
make clean
```

## 🧪 Testing

Run the comprehensive API test suite:

```bash
./test_api.sh
```

This will test:
- Health check endpoint
- Get all users
- Create user
- Get user by ID
- Update user
- Delete user
- Error handling (invalid ID, missing fields, not found)
- Cache performance

## 📊 Database Schema

### Users Table

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
```

## 🚀 Performance

### Connection Pooling
- **PostgreSQL Pool Size**: 5 connections
- Automatic connection reuse
- Thread-safe pool management

### Caching Strategy
- **Cache Layer**: Redis
- **TTL**: 60 seconds
- **Cache Keys**:
  - `users:all` - All users list
  - `user:{id}` - Individual user
- **Auto-invalidation** on create/update/delete operations

### Concurrency
- Each request handled in a separate thread
- Thread-safe database pool
- Mutex-protected Redis operations

## 🛠️ Useful Make Commands

```bash
make help              # Show all available commands
make install-deps      # Install system dependencies (macOS)
make build            # Build the application
make run              # Run the application
make test             # Run tests
make clean            # Clean build artifacts
make docker-up        # Start Docker services
make docker-down      # Stop Docker services
make docker-logs      # View Docker logs
make migrate          # Run database migrations
make dev              # Setup complete dev environment
make db-connect       # Connect to PostgreSQL
make redis-cli        # Connect to Redis CLI
make curl-test        # Test API with curl
```

## 🐛 Troubleshooting

### PostgreSQL Connection Issues

```bash
# Check if PostgreSQL is running
docker compose ps

# Check PostgreSQL logs
docker compose logs postgres

# Verify connection
docker compose exec postgres psql -U postgres -d crud_api -c "\dt"
```

### Redis Connection Issues

```bash
# Check if Redis is running
docker compose exec redis redis-cli ping

# Check Redis logs
docker compose logs redis
```

### Build Issues

```bash
# Clean and rebuild
make clean
zig build

# Check Zig version
zig version

# Ensure dependencies are fetched
zig fetch --save git+https://github.com/karlseguin/pg.zig#master
zig fetch --save git+https://github.com/kristoff-it/zig-okredis#master
```

### Docker Image Size

The production Docker image is extremely small because:
- Uses Alpine's package manager (`apk add zig`) for build dependencies
- Final runtime image uses `scratch` (completely empty base)
- Only contains the statically-linked binary
- No shell, package manager, or other utilities in the final image

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

## 📝 Adding New Features

### Add a New Migration

1. Create a new SQL file in `migrations/`:
```sql
-- migrations/002_add_users_phone.sql
ALTER TABLE users ADD COLUMN phone VARCHAR(20);
```

2. Run the migration:
```bash
docker compose exec -T postgres psql -U postgres -d crud_api < migrations/002_add_users_phone.sql
```

### Add a New Model

1. Create model in `src/models/`:
```zig
// src/models/post.zig
pub const Post = struct {
    id: i32,
    title: []const u8,
    content: []const u8,
    user_id: i32,
};
```

2. Create handlers in `src/handlers/`
3. Update router in `src/router.zig`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- [Zig Programming Language](https://ziglang.org/)
- [PostgreSQL](https://www.postgresql.org/)
- [Redis](https://redis.io/)
- [pg.zig](https://github.com/karlseguin/pg.zig) - Native PostgreSQL driver
- [zig-okredis](https://github.com/kristoff-it/zig-okredis) - Zero-allocation Redis client

## 📖 Resources

- [Zig Documentation](https://ziglang.org/documentation/master/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/18/)
- [Redis Documentation](https://redis.io/docs/)
- [API Documentation](API.md)

## 🔮 Roadmap

- [ ] Authentication & Authorization (JWT)
- [ ] Rate Limiting
- [ ] Pagination & Filtering
- [ ] WebSocket Support
- [ ] Metrics & Monitoring
- [ ] API Versioning
- [ ] Full-text Search
- [ ] File Upload Support
- [ ] Email Validation
- [ ] Comprehensive Logging

---

**Built with ❤️ using Zig**
