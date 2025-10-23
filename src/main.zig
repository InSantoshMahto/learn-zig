const std = @import("std");
const config = @import("config.zig");
const PgPool = @import("db/postgres.zig").PgPool;
const RedisClient = @import("db/redis.zig").RedisClient;
const UserHandlers = @import("handlers/users.zig").UserHandlers;
const Router = @import("router.zig").Router;
const Server = @import("server.zig").Server;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("Starting CRUD API Server...\n", .{});

    // Load configuration
    var cfg = try config.Config.init(allocator);
    defer cfg.deinit();

    std.debug.print("Configuration loaded:\n", .{});
    std.debug.print("  Database: {s}\n", .{cfg.database_url});
    std.debug.print("  Redis: {s}:{d}\n", .{ cfg.redis_host, cfg.redis_port });
    std.debug.print("  Server Port: {d}\n", .{cfg.server_port});

    // Initialize PostgreSQL connection pool
    const pg_pool = PgPool.init(allocator, cfg.database_url, 5) catch |err| {
        std.debug.print("Failed to initialize PostgreSQL pool: {}\n", .{err});
        std.debug.print("Make sure PostgreSQL is running and the connection string is correct.\n", .{});
        return err;
    };
    defer pg_pool.deinit();

    // Initialize Redis client
    const redis = RedisClient.init(allocator, cfg.redis_host, cfg.redis_port) catch |err| {
        std.debug.print("Failed to initialize Redis client: {}\n", .{err});
        std.debug.print("Make sure Redis is running and accessible.\n", .{});
        return err;
    };
    defer redis.deinit();

    // Test Redis connection
    const redis_ok = redis.ping() catch false;
    if (redis_ok) {
        std.debug.print("Redis connection: OK\n", .{});
    } else {
        std.debug.print("Redis connection: Failed\n", .{});
    }

    // Initialize handlers
    var user_handlers = UserHandlers.init(allocator, pg_pool, redis);

    // Initialize router
    var router = Router.init(allocator, &user_handlers);

    // Initialize and start server
    var server = Server.init(allocator, &router, cfg.server_port);
    try server.listen();
}

test "basic test" {
    try std.testing.expectEqual(1, 1);
}
