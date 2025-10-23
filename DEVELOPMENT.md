# Development Guide

This guide provides detailed information for developers working on the Zig 0.15.2 CRUD API project using native Zig dependencies.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Code Structure](#code-structure)
3. [Development Workflow](#development-workflow)
4. [Best Practices](#best-practices)
5. [Testing](#testing)
6. [Performance Optimization](#performance-optimization)
7. [Debugging](#debugging)
8. [Common Patterns](#common-patterns)

## Architecture Overview

### System Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP/JSON
       ▼
┌─────────────────────────────────────┐
│         HTTP Server                 │
│  (server.zig - Thread per request) │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│          Router                     │
│  (router.zig - Route matching)     │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│        Handlers                     │
│  (handlers/users.zig - Business)   │
└──────┬──────────────┬───────────────┘
       │              │
       ▼              ▼
┌─────────────┐ ┌─────────────┐
│   Redis     │ │  PostgreSQL │
│ zig-okredis │ │   pg.zig    │
│ (redis.zig) │ │(postgres.zig)│
└─────────────┘ └─────────────┘
```

### Request Flow

1. **HTTP Request** → Server receives raw TCP connection
2. **Parse** → Extract method, path, headers, body
3. **Route** → Match request to handler
4. **Cache Check** → Check Redis for cached data
5. **Database Query** → If cache miss, query PostgreSQL
6. **Cache Update** → Store result in Redis
7. **Response** → Format and send JSON response

### Component Responsibilities

#### `main.zig`
- Application entry point
- Initialize configuration
- Set up database connections
- Start HTTP server

#### `config.zig`
- Environment variable parsing
- Default configuration values
- Configuration validation

#### `server.zig`
- TCP connection handling
- HTTP request parsing
- Response formatting
- Thread management

#### `router.zig`
- URL pattern matching
- Route to handler mapping
- Error response generation

#### `handlers/users.zig`
- Business logic for user operations
- Database queries
- Cache management
- Data validation

#### `db/postgres.zig`
- Connection pool wrapper for pg.zig
- Query execution using native Zig driver
- Result iteration and parsing
- Error handling

#### `db/redis.zig`
- Redis client wrapper for zig-okredis
- Zero-allocation cache operations (GET, SET, DEL)
- TTL management
- Pure Zig implementation

#### `models/user.zig`
- Data structures
- JSON serialization/deserialization
- Validation logic

## Code Structure

### Directory Layout

```
src/
├── main.zig              # Entry point
├── config.zig            # Configuration
├── server.zig            # HTTP server
├── router.zig            # Routing logic
├── db/
│   ├── postgres.zig      # PostgreSQL client
│   └── redis.zig         # Redis client
├── handlers/
│   └── users.zig         # User CRUD handlers
├── models/
│   └── user.zig          # User model
└── middleware/           # Future middleware (logging, auth, etc.)
```

### File Naming Conventions

- Use snake_case for file names: `user_handler.zig`
- One main type per file
- Related types can be in the same file
- Test files: `filename_test.zig`

### Code Organization

Each module should follow this structure:

```zig
const std = @import("std");
const OtherModule = @import("other.zig");

// Constants
const BUFFER_SIZE = 4096;

// Type definitions
pub const MyType = struct {
    field1: i32,
    field2: []const u8,
    
    pub fn init() MyType {
        // ...
    }
    
    pub fn deinit(self: *MyType) void {
        // ...
    }
    
    // Public methods
    pub fn doSomething(self: *MyType) !void {
        // ...
    }
    
    // Private methods
    fn helperFunction(self: *MyType) void {
        // ...
    }
};

// Module-level functions
pub fn utilityFunction() void {
    // ...
}

// Tests
test "MyType basic test" {
    // ...
}
```

## Development Workflow

### 1. Setting Up Development Environment

```bash
# Clone repository
git clone <repo-url>
cd learn-zig

# Install Zig 0.15.2
brew install zig  # macOS
# or download from https://ziglang.org/download/

# Fetch native Zig dependencies
zig fetch --save git+https://github.com/karlseguin/pg.zig#master
zig fetch --save git+https://github.com/kristoff-it/zig-okredis#master

# Start services (PostgreSQL and Redis)
./setup.sh

# Verify setup
make curl-test
```

### 2. Making Changes

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes to src/

# Build and test
zig build
zig build test

# Run application
zig build run

# Test manually
./test_api.sh
```

### 3. Code Review Checklist

- [ ] Code compiles without warnings
- [ ] Tests pass
- [ ] Memory leaks checked (no allocator leaks)
- [ ] Error handling implemented
- [ ] Documentation updated
- [ ] API endpoints tested
- [ ] Cache invalidation works correctly

### 4. Commit Guidelines

```bash
# Commit message format
<type>(<scope>): <subject>

# Types: feat, fix, docs, style, refactor, test, chore

# Examples:
git commit -m "feat(users): add pagination support"
git commit -m "fix(cache): correct TTL calculation"
git commit -m "docs(api): update endpoint documentation"
```

## Best Practices

### Memory Management

**Always pair init with deinit:**

```zig
var user = try User.init(allocator);
defer user.deinit(); // Always defer immediately
```

**Note: In Zig 0.15.2, ArrayList API has changed:**

```zig
// New API - ArrayList is now unmanaged
var list: std.ArrayList(i32) = .empty;
defer list.deinit(allocator);

try list.append(allocator, 42);
try list.appendSlice(allocator, &[_]i32{1, 2, 3});
```

**Check for memory leaks:**

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer {
    const leaked = gpa.deinit();
    if (leaked == .leak) {
        std.debug.print("Memory leak detected!\n", .{});
    }
}
```

### Error Handling

**Use error unions:**

```zig
pub fn getUser(id: i32) !User {
    const user = database.query(id) catch |err| {
        std.debug.print("Database error: {}\n", .{err});
        return err;
    };
    return user;
}
```

**Define custom errors:**

```zig
pub const UserError = error{
    NotFound,
    InvalidEmail,
    DuplicateEmail,
};
```

### Thread Safety

**Use mutexes for shared resources:**

```zig
pub const ThreadSafeCounter = struct {
    value: usize,
    mutex: std.Thread.Mutex,
    
    pub fn increment(self: *ThreadSafeCounter) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
    }
};
```

### Database Queries

**Use parameterized queries with pg.zig:**

```zig
// ✅ Good - pg.zig uses compile-time parameters
const result = try conn.query("SELECT * FROM users WHERE id = $1", .{user_id});
defer result.deinit();

while (try result.next()) |row| {
    const id = row.get(i32, 0);
    const name = row.get([]const u8, 1);
    // Process row...
}

// For single row results
const row_result = try conn.row("SELECT * FROM users WHERE id = $1", .{user_id});
const row = row_result orelse return error.NotFound;
defer row_result.?.deinit() catch {};
```

**Always release connections:**

```zig
const conn = try pool.acquire();
defer pool.release(conn);  // No error in pg.zig release

// Use connection...
```

### Cache Strategy

**Cache read-heavy data with zig-okredis:**

```zig
// Check cache first (handle both error and null)
if (redis.get(cache_key) catch null) |cached| {
    return cached;
}

// Fetch from database
const data = try db.query();

// Update cache
redis.set(cache_key, data, ttl) catch {};
```

**Invalidate on writes:**

```zig
// Update database
try db.update(user);

// Invalidate related caches
try redis.del(user_cache_key);
try redis.del(users_list_key);
```

**Using zig-okredis for zero-allocation operations:**

```zig
// zig-okredis uses compile-time known commands
try client.send(void, .{"SET", "key", "value"});
const value = try client.send(i64, .{"GET", "counter"});
const exists = try client.send(i64, .{"EXISTS", "key"}) > 0;
```

## Testing

### Unit Tests

```zig
test "User.toJson" {
    const allocator = std.testing.allocator;
    
    var user = User{
        .id = 1,
        .name = "Test",
        .email = "test@example.com",
        .created_at = null,
        .updated_at = null,
    };
    
    const json = try user.toJson(allocator);
    defer allocator.free(json);
    
    try std.testing.expect(std.mem.indexOf(u8, json, "\"id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"Test\"") != null);
}
```

### Integration Tests

Run the test suite:

```bash
./test_api.sh
```

### Manual Testing

```bash
# Start server
zig build run

# In another terminal
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@example.com"}'
```

### Load Testing

```bash
# Install Apache Bench
brew install apache2

# Test GET endpoint
ab -n 1000 -c 10 http://localhost:8080/api/users

# Expected results:
# - Requests per second: > 1000
# - Time per request: < 10ms (with cache)
```

## Performance Optimization

### Connection Pooling

Increase pool size for high traffic (note: pg.zig pool size is u16):

```zig
const pg_pool = try PgPool.init(allocator, cfg.database_url, 10); // Increased from 5
```

**pg.zig Pool Configuration:**

The pool uses native Zig connection management with automatic reconnection for invalid connections.

### Cache Configuration

Adjust TTL based on data freshness requirements:

```zig
// Frequently changing data: shorter TTL
redis.set(cache_key, data, 30) catch {};

// Relatively static data: longer TTL
redis.set(cache_key, data, 300) catch {};
```

### Query Optimization

Add indexes for frequently queried columns:

```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
```

### Response Compression

Consider implementing gzip compression for large responses.

## Debugging

### Debug Logging

Add debug prints:

```zig
std.debug.print("User ID: {d}, Name: {s}\n", .{user.id, user.name});
```

### Database Debugging

Check queries in PostgreSQL:

```sql
-- Enable query logging
ALTER DATABASE crud_api SET log_statement = 'all';

-- View slow queries
SELECT query, calls, total_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;
```

### Redis Debugging

Monitor Redis commands:

```bash
docker compose exec redis redis-cli MONITOR
```

### Memory Debugging

Use Valgrind (Linux):

```bash
valgrind --leak-check=full ./zig-out/bin/api
```

### Network Debugging

Monitor HTTP traffic:

```bash
# Using tcpdump
sudo tcpdump -i lo0 -A -s 0 'tcp port 8080'

# Using ngrep
ngrep -d any -W byline port 8080
```

## Common Patterns

### Adding a New Endpoint

1. **Define Model** (`src/models/post.zig`):

```zig
pub const Post = struct {
    id: i32,
    title: []const u8,
    content: []const u8,
    user_id: i32,
    
    pub fn toJson(self: Post, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(allocator);
        
        try buffer.appendSlice(allocator, "{\"id\":");
        // ... JSON serialization
        
        return allocator.dupe(u8, buffer.items);
    }
};
```

2. **Create Handler** (`src/handlers/posts.zig`):

```zig
pub const PostHandlers = struct {
    pub fn getAllPosts(self: *PostHandlers) ![]u8 {
        // Implementation
    }
};
```

3. **Add Route** (`src/router.zig`):

```zig
if (std.mem.startsWith(u8, path, "/api/posts")) {
    return self.handlePostRoutes(method, path, body);
}
```

4. **Create Migration** (`migrations/002_create_posts.sql`):

```sql
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Error Response Pattern

```zig
return try Response.error_response(
    self.allocator,
    404,
    "Resource not found"
);
```

### Pagination Pattern

```zig
pub fn getPaginated(
    self: *Handler,
    page: u32,
    limit: u32
) ![]u8 {
    const offset = (page - 1) * limit;
    const query = 
        \\SELECT * FROM users 
        \\ORDER BY id 
        \\LIMIT $1 OFFSET $2
    ;
    
    const conn = try self.pg_pool.acquire();
    defer self.pg_pool.release(conn);
    
    // pg.zig uses compile-time parameters
    var result = try conn.query(query, .{limit, offset});
    defer result.deinit();
    
    while (try result.next()) |row| {
        // Process row...
    }
}
```

## Contributing

### Before Submitting PR

1. Run all tests: `zig build test`
2. Run API tests: `./test_api.sh`
3. Format code: `make format`
4. Check for memory leaks
5. Update documentation
6. Add tests for new features

### Code Review Process

1. Create pull request
2. Automated tests run
3. Code review by maintainer
4. Address feedback
5. Merge when approved

## Resources

- [Zig Language Reference](https://ziglang.org/documentation/0.15.2/)
- [Zig Standard Library](https://ziglang.org/documentation/0.15.2/std/)
- [pg.zig Documentation](https://github.com/karlseguin/pg.zig)
- [zig-okredis Documentation](https://github.com/kristoff-it/zig-okredis)
- [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Best Practices](https://redis.io/docs/manual/patterns/)
- [Zig 0.15 Release Notes](https://ziglang.org/download/0.15.0/release-notes.html)

## Getting Help

- Read existing code and comments
- Check the API documentation
- Review test cases for examples
- Open an issue on GitHub
- Ask in community forums

---

**Happy developing! 🚀**