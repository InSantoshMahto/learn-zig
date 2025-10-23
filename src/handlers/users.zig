const std = @import("std");
const User = @import("../models/user.zig").User;
const CreateUserRequest = @import("../models/user.zig").CreateUserRequest;
const UpdateUserRequest = @import("../models/user.zig").UpdateUserRequest;
const PgPool = @import("../db/postgres.zig").PgPool;
const RedisClient = @import("../db/redis.zig").RedisClient;
const postgres = @import("../db/postgres.zig");

pub const UserHandlers = struct {
    pg_pool: *PgPool,
    redis: *RedisClient,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, pg_pool: *PgPool, redis: *RedisClient) UserHandlers {
        return UserHandlers{
            .pg_pool = pg_pool,
            .redis = redis,
            .allocator = allocator,
        };
    }

    // GET /api/users - Get all users
    pub fn getAllUsers(self: *UserHandlers) ![]u8 {
        const cache_key = "users:all";

        // Try cache first
        if (self.redis.get(cache_key) catch null) |cached| {
            std.debug.print("Cache hit for all users\n", .{});
            return cached;
        }

        const conn = try self.pg_pool.acquire();
        defer self.pg_pool.release(conn);

        const query = "SELECT id, name, email, created_at::text, updated_at::text FROM users ORDER BY id";
        var result = try conn.query(query, .{});
        defer result.deinit();

        var users: std.ArrayList(User) = .empty;
        defer {
            for (users.items) |*user| {
                user.deinit(self.allocator);
            }
            users.deinit(self.allocator);
        }

        while (try result.next()) |row| {
            const id = row.get(i32, 0);
            const name = try self.allocator.dupe(u8, row.get([]const u8, 1));
            const email = try self.allocator.dupe(u8, row.get([]const u8, 2));
            const created_at_slice = row.get(?[]const u8, 3);
            const updated_at_slice = row.get(?[]const u8, 4);

            const created_at = if (created_at_slice) |ca| try self.allocator.dupe(u8, ca) else null;
            const updated_at = if (updated_at_slice) |ua| try self.allocator.dupe(u8, ua) else null;

            try users.append(self.allocator, User{
                .id = id,
                .name = name,
                .email = email,
                .created_at = created_at,
                .updated_at = updated_at,
            });
        }

        // Build JSON array
        var json: std.ArrayList(u8) = .empty;
        defer json.deinit(self.allocator);

        try json.appendSlice(self.allocator, "[");
        for (users.items, 0..) |user, idx| {
            const user_json = try user.toJson(self.allocator);
            defer self.allocator.free(user_json);
            try json.appendSlice(self.allocator, user_json);
            if (idx < users.items.len - 1) {
                try json.appendSlice(self.allocator, ",");
            }
        }
        try json.appendSlice(self.allocator, "]");

        const response = try self.allocator.dupe(u8, json.items);

        // Cache for 60 seconds
        self.redis.set(cache_key, response, 60) catch |err| {
            std.debug.print("Cache set failed: {}\n", .{err});
        };

        return response;
    }

    // GET /api/users/:id - Get user by ID
    pub fn getUserById(self: *UserHandlers, id: i32) ![]u8 {
        const cache_key = try std.fmt.allocPrint(self.allocator, "user:{d}", .{id});
        defer self.allocator.free(cache_key);

        // Try cache first
        if (self.redis.get(cache_key) catch null) |cached| {
            std.debug.print("Cache hit for user {d}\n", .{id});
            return cached;
        }

        const conn = try self.pg_pool.acquire();
        defer self.pg_pool.release(conn);

        const query = "SELECT id, name, email, created_at::text, updated_at::text FROM users WHERE id = $1";
        var row_result = try conn.row(query, .{id});
        const row = row_result orelse return error.NotFound;
        defer row_result.?.deinit() catch {};

        const user_id = row.get(i32, 0);
        const name = try self.allocator.dupe(u8, row.get([]const u8, 1));
        const email = try self.allocator.dupe(u8, row.get([]const u8, 2));
        const created_at_slice = row.get(?[]const u8, 3);
        const updated_at_slice = row.get(?[]const u8, 4);

        const created_at = if (created_at_slice) |ca| try self.allocator.dupe(u8, ca) else null;
        const updated_at = if (updated_at_slice) |ua| try self.allocator.dupe(u8, ua) else null;

        const user = User{
            .id = user_id,
            .name = name,
            .email = email,
            .created_at = created_at,
            .updated_at = updated_at,
        };

        const response = try user.toJson(self.allocator);

        // Cache for 60 seconds
        self.redis.set(cache_key, response, 60) catch |err| {
            std.debug.print("Cache set failed: {}\n", .{err});
        };

        return response;
    }

    // POST /api/users - Create new user
    pub fn createUser(self: *UserHandlers, body: []const u8) ![]u8 {
        var create_req = try CreateUserRequest.fromJson(self.allocator, body);
        defer create_req.deinit(self.allocator);

        const conn = try self.pg_pool.acquire();
        defer self.pg_pool.release(conn);

        const query =
            \\INSERT INTO users (name, email)
            \\VALUES ($1, $2)
            \\RETURNING id, name, email, created_at::text, updated_at::text
        ;

        var row_result = try conn.row(query, .{ create_req.name, create_req.email });
        const row = row_result orelse return error.CreateFailed;
        defer row_result.?.deinit() catch {};

        const id = row.get(i32, 0);
        const name = try self.allocator.dupe(u8, row.get([]const u8, 1));
        const email = try self.allocator.dupe(u8, row.get([]const u8, 2));
        const created_at_slice = row.get(?[]const u8, 3);
        const updated_at_slice = row.get(?[]const u8, 4);

        const created_at = if (created_at_slice) |ca| try self.allocator.dupe(u8, ca) else null;
        const updated_at = if (updated_at_slice) |ua| try self.allocator.dupe(u8, ua) else null;

        const user = User{
            .id = id,
            .name = name,
            .email = email,
            .created_at = created_at,
            .updated_at = updated_at,
        };

        // Invalidate all users cache
        self.redis.del("users:all") catch {};

        return try user.toJson(self.allocator);
    }

    // PUT /api/users/:id - Update user
    pub fn updateUser(self: *UserHandlers, id: i32, body: []const u8) ![]u8 {
        var update_req = try UpdateUserRequest.fromJson(self.allocator, body);
        defer update_req.deinit(self.allocator);

        if (update_req.name == null and update_req.email == null) {
            return error.NoFieldsToUpdate;
        }

        const conn = try self.pg_pool.acquire();
        defer self.pg_pool.release(conn);

        // For simplicity, we'll handle the common cases
        // pg.zig doesn't support dynamic parameter lists easily
        const query = if (update_req.name != null and update_req.email != null)
            "UPDATE users SET name = $1, email = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING id, name, email, created_at::text, updated_at::text"
        else if (update_req.name != null)
            "UPDATE users SET name = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING id, name, email, created_at::text, updated_at::text"
        else if (update_req.email != null)
            "UPDATE users SET email = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 RETURNING id, name, email, created_at::text, updated_at::text"
        else
            "SELECT id, name, email, created_at::text, updated_at::text FROM users WHERE id = $1";

        var row_result = if (update_req.name != null and update_req.email != null)
            try conn.row(query, .{ update_req.name.?, update_req.email.?, id })
        else if (update_req.name != null)
            try conn.row(query, .{ update_req.name.?, id })
        else if (update_req.email != null)
            try conn.row(query, .{ update_req.email.?, id })
        else
            try conn.row(query, .{id});

        const row = row_result orelse return error.NotFound;
        defer row_result.?.deinit() catch {};

        const updated_id = row.get(i32, 0);
        const name = try self.allocator.dupe(u8, row.get([]const u8, 1));
        const email = try self.allocator.dupe(u8, row.get([]const u8, 2));
        const created_at_slice = row.get(?[]const u8, 3);
        const updated_at_slice = row.get(?[]const u8, 4);

        const created_at = if (created_at_slice) |ca| try self.allocator.dupe(u8, ca) else null;
        const updated_at = if (updated_at_slice) |ua| try self.allocator.dupe(u8, ua) else null;

        const user = User{
            .id = updated_id,
            .name = name,
            .email = email,
            .created_at = created_at,
            .updated_at = updated_at,
        };

        // Invalidate caches
        const cache_key = try std.fmt.allocPrint(self.allocator, "user:{d}", .{id});
        defer self.allocator.free(cache_key);
        self.redis.del(cache_key) catch {};
        self.redis.del("users:all") catch {};

        return try user.toJson(self.allocator);
    }

    // DELETE /api/users/:id - Delete user
    pub fn deleteUser(self: *UserHandlers, id: i32) !void {
        const conn = try self.pg_pool.acquire();
        defer self.pg_pool.release(conn);

        const query = "DELETE FROM users WHERE id = $1";
        _ = try conn.exec(query, .{id});

        // Invalidate caches
        const cache_key = try std.fmt.allocPrint(self.allocator, "user:{d}", .{id});
        defer self.allocator.free(cache_key);
        self.redis.del(cache_key) catch {};
        self.redis.del("users:all") catch {};
    }
};
