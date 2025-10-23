# API Documentation

## Base URL
```
http://localhost:8080
```

## Headers
All requests and responses use JSON format.

```
Content-Type: application/json
```

---

## Endpoints

### Health Check

#### GET /health
Check if the server is running.

**Response:**
```json
{
  "status": "ok"
}
```

**Status Codes:**
- `200 OK` - Server is healthy

---

## Users

### Get All Users

#### GET /api/users
Retrieve a list of all users.

**Response:**
```json
[
  {
    "id": 1,
    "name": "Alice Johnson",
    "email": "alice@example.com",
    "created_at": "2024-01-15 10:30:00",
    "updated_at": "2024-01-15 10:30:00"
  },
  {
    "id": 2,
    "name": "Bob Smith",
    "email": "bob@example.com",
    "created_at": "2024-01-15 11:30:00",
    "updated_at": "2024-01-15 11:30:00"
  }
]
```

**Status Codes:**
- `200 OK` - Success
- `500 Internal Server Error` - Database error

**Caching:**
- Cache TTL: 60 seconds
- Cache Key: `users:all`

**Example:**
```bash
curl http://localhost:8080/api/users
```

---

### Get User by ID

#### GET /api/users/:id
Retrieve a specific user by their ID.

**Parameters:**
- `id` (integer, required) - User ID in the URL path

**Response:**
```json
{
  "id": 1,
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "created_at": "2024-01-15 10:30:00",
  "updated_at": "2024-01-15 10:30:00"
}
```

**Status Codes:**
- `200 OK` - User found
- `400 Bad Request` - Invalid user ID format
- `404 Not Found` - User not found
- `500 Internal Server Error` - Database error

**Caching:**
- Cache TTL: 60 seconds
- Cache Key: `user:{id}`

**Example:**
```bash
curl http://localhost:8080/api/users/1
```

---

### Create User

#### POST /api/users
Create a new user.

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com"
}
```

**Required Fields:**
- `name` (string) - User's full name
- `email` (string) - User's email address (must be unique)

**Response:**
```json
{
  "id": 3,
  "name": "John Doe",
  "email": "john@example.com",
  "created_at": "2024-01-15 12:30:00",
  "updated_at": "2024-01-15 12:30:00"
}
```

**Status Codes:**
- `201 Created` - User created successfully
- `400 Bad Request` - Missing required fields or invalid JSON
- `500 Internal Server Error` - Database error (e.g., duplicate email)

**Cache Invalidation:**
- Invalidates: `users:all`

**Example:**
```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

---

### Update User

#### PUT /api/users/:id
Update an existing user.

**Parameters:**
- `id` (integer, required) - User ID in the URL path

**Request Body:**
```json
{
  "name": "Jane Doe",
  "email": "jane@example.com"
}
```

**Optional Fields:**
- `name` (string) - User's full name
- `email` (string) - User's email address

**Note:** At least one field must be provided.

**Response:**
```json
{
  "id": 1,
  "name": "Jane Doe",
  "email": "jane@example.com",
  "created_at": "2024-01-15 10:30:00",
  "updated_at": "2024-01-15 13:30:00"
}
```

**Status Codes:**
- `200 OK` - User updated successfully
- `400 Bad Request` - No fields to update or invalid JSON
- `404 Not Found` - User not found
- `500 Internal Server Error` - Database error

**Cache Invalidation:**
- Invalidates: `user:{id}`, `users:all`

**Example:**
```bash
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe"}'
```

---

### Delete User

#### DELETE /api/users/:id
Delete a user.

**Parameters:**
- `id` (integer, required) - User ID in the URL path

**Response:**
```json
{
  "message": "User deleted successfully"
}
```

**Status Codes:**
- `200 OK` - User deleted successfully
- `400 Bad Request` - Invalid user ID format
- `500 Internal Server Error` - Database error

**Cache Invalidation:**
- Invalidates: `user:{id}`, `users:all`

**Example:**
```bash
curl -X DELETE http://localhost:8080/api/users/1
```

---

## Error Responses

All error responses follow this format:

```json
{
  "error": "Error message description"
}
```

### Common Error Messages

#### 400 Bad Request
```json
{
  "error": "Invalid JSON"
}
```
```json
{
  "error": "Missing required fields: name, email"
}
```
```json
{
  "error": "Invalid user ID"
}
```
```json
{
  "error": "No fields to update"
}
```
```json
{
  "error": "Request body required"
}
```

#### 404 Not Found
```json
{
  "error": "User not found"
}
```
```json
{
  "error": "Not Found"
}
```

#### 405 Method Not Allowed
```json
{
  "error": "Method Not Allowed"
}
```

#### 500 Internal Server Error
```json
{
  "error": "Internal Server Error"
}
```

---

## Caching Strategy

The API uses Redis for caching to improve performance:

### Cache Keys
- `users:all` - List of all users
- `user:{id}` - Individual user by ID

### Cache TTL
- All cache entries: **60 seconds**

### Cache Invalidation
- **Create User**: Invalidates `users:all`
- **Update User**: Invalidates `user:{id}` and `users:all`
- **Delete User**: Invalidates `user:{id}` and `users:all`

### Cache Behavior
- On cache hit: Returns cached data immediately
- On cache miss: Fetches from PostgreSQL and caches the result

---

## Rate Limiting

Currently, there is no rate limiting implemented. Consider adding rate limiting for production use.

---

## Testing the API

### Using cURL

**Get all users:**
```bash
curl http://localhost:8080/api/users
```

**Get user by ID:**
```bash
curl http://localhost:8080/api/users/1
```

**Create a user:**
```bash
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'
```

**Update a user:**
```bash
curl -X PUT http://localhost:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name","email":"updated@example.com"}'
```

**Delete a user:**
```bash
curl -X DELETE http://localhost:8080/api/users/1
```

### Using httpie

```bash
# Get all users
http GET localhost:8080/api/users

# Create user
http POST localhost:8080/api/users name="Test User" email="test@example.com"

# Update user
http PUT localhost:8080/api/users/1 name="Updated Name"

# Delete user
http DELETE localhost:8080/api/users/1
```

### Using Make

```bash
make curl-test
```

---

## Database Schema

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

**Constraints:**
- `email` must be unique
- `name` and `email` are required fields

---

## Performance Considerations

### Connection Pooling
- PostgreSQL connection pool size: **5 connections**
- Connections are reused across requests
- Automatic connection management

### Concurrency
- Each HTTP request is handled in a separate thread
- Thread-safe database connection pool
- Thread-safe Redis client with mutex locking

### Caching Benefits
- Reduces database load for frequently accessed data
- Improves response times for cached queries
- Automatic cache invalidation on data changes

---

## Future Enhancements

Potential improvements for the API:

1. **Authentication & Authorization**
   - JWT token-based authentication
   - Role-based access control

2. **Pagination**
   - Limit and offset for large datasets
   - Cursor-based pagination

3. **Filtering & Sorting**
   - Query parameters for filtering
   - Sort by different fields

4. **Validation**
   - Email format validation
   - Input sanitization
   - Custom validation rules

5. **Rate Limiting**
   - Per-IP rate limiting
   - API key-based quotas

6. **Logging & Monitoring**
   - Request/response logging
   - Performance metrics
   - Error tracking

7. **API Versioning**
   - Version prefixes (e.g., `/api/v1/users`)
   - Backward compatibility

8. **Additional Resources**
   - Posts, comments, or other entities
   - Relationships between resources

9. **Search**
   - Full-text search capabilities
   - ElasticSearch integration

10. **WebSocket Support**
    - Real-time updates
    - Live notifications