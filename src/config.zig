const std = @import("std");

pub const Config = struct {
    database_url: []const u8,
    redis_host: []const u8,
    redis_port: u16,
    server_port: u16,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Config {
        const database_url = std.process.getEnvVarOwned(allocator, "DATABASE_URL") catch |err| {
            if (err == error.EnvironmentVariableNotFound) {
                return Config{
                    .database_url = try allocator.dupe(u8, "postgres://postgres:password@localhost:5432/crud_api"),
                    .redis_host = try allocator.dupe(u8, "localhost"),
                    .redis_port = 6379,
                    .server_port = 8080,
                    .allocator = allocator,
                };
            }
            return err;
        };

        const redis_url = std.process.getEnvVarOwned(allocator, "REDIS_URL") catch try allocator.dupe(u8, "redis://localhost:6379");
        defer allocator.free(redis_url);

        const port_str = std.process.getEnvVarOwned(allocator, "PORT") catch try allocator.dupe(u8, "8080");
        defer allocator.free(port_str);

        // Parse Redis URL (simple parsing for redis://host:port)
        var redis_host: []const u8 = "localhost";
        var redis_port: u16 = 6379;

        if (std.mem.startsWith(u8, redis_url, "redis://")) {
            const host_port = redis_url[8..];
            if (std.mem.indexOf(u8, host_port, ":")) |colon_idx| {
                redis_host = try allocator.dupe(u8, host_port[0..colon_idx]);
                const port_part = host_port[colon_idx + 1 ..];
                redis_port = std.fmt.parseInt(u16, port_part, 10) catch 6379;
            } else {
                redis_host = try allocator.dupe(u8, host_port);
            }
        } else {
            redis_host = try allocator.dupe(u8, redis_host);
        }

        const server_port = std.fmt.parseInt(u16, port_str, 10) catch 8080;

        return Config{
            .database_url = database_url,
            .redis_host = redis_host,
            .redis_port = redis_port,
            .server_port = server_port,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Config) void {
        self.allocator.free(self.database_url);
        self.allocator.free(self.redis_host);
    }
};
