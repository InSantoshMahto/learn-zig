const std = @import("std");
const okredis = @import("okredis");

pub const RedisError = error{
    ConnectionFailed,
    CommandFailed,
    InvalidResponse,
};

pub const RedisClient = struct {
    client: okredis.Client,
    allocator: std.mem.Allocator,
    connection: std.net.Stream,

    pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) !*RedisClient {
        const redis_client = try allocator.create(RedisClient);
        errdefer allocator.destroy(redis_client);

        // Connect to Redis
        const address = try std.net.Address.parseIp(host, port);
        const connection = try std.net.tcpConnectToAddress(address);
        errdefer connection.close();

        // Create buffers for the client
        const rbuf = try allocator.alloc(u8, 4096);
        errdefer allocator.free(rbuf);
        const wbuf = try allocator.alloc(u8, 4096);
        errdefer allocator.free(wbuf);

        const client = try okredis.Client.init(connection, .{
            .reader_buffer = rbuf,
            .writer_buffer = wbuf,
        });

        redis_client.* = RedisClient{
            .client = client,
            .allocator = allocator,
            .connection = connection,
        };

        std.debug.print("Redis client initialized: {s}:{d}\n", .{ host, port });
        return redis_client;
    }

    pub fn deinit(self: *RedisClient) void {
        self.client.close();
        self.connection.close();
        self.allocator.destroy(self);
    }

    pub fn set(self: *RedisClient, key: []const u8, value: []const u8, ttl_seconds: ?u32) !void {
        if (ttl_seconds) |ttl| {
            self.client.send(void, .{ "SETEX", key, ttl, value }) catch {
                return RedisError.CommandFailed;
            };
        } else {
            self.client.send(void, .{ "SET", key, value }) catch {
                return RedisError.CommandFailed;
            };
        }
    }

    pub fn get(self: *RedisClient, key: []const u8) !?[]u8 {
        const reply = self.client.sendAlloc(?[]const u8, self.allocator, .{ "GET", key }) catch {
            return RedisError.CommandFailed;
        };

        if (reply) |value| {
            return try self.allocator.dupe(u8, value);
        }
        return null;
    }

    pub fn del(self: *RedisClient, key: []const u8) !void {
        _ = self.client.send(i64, .{ "DEL", key }) catch {
            return RedisError.CommandFailed;
        };
    }

    pub fn exists(self: *RedisClient, key: []const u8) !bool {
        const count = self.client.send(i64, .{ "EXISTS", key }) catch {
            return RedisError.CommandFailed;
        };
        return count > 0;
    }

    pub fn ping(self: *RedisClient) !bool {
        self.client.send(void, .{"PING"}) catch {
            return false;
        };
        return true;
    }

    pub fn flushAll(self: *RedisClient) !void {
        self.client.send(void, .{"FLUSHALL"}) catch {
            return RedisError.CommandFailed;
        };
    }
};
