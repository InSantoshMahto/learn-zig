const std = @import("std");
const pg = @import("pg");

pub const PgError = error{
    ConnectionFailed,
    QueryFailed,
    NoResult,
    InvalidConnection,
};

pub const PgPool = struct {
    pool: *pg.Pool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, connection_string: []const u8, pool_size: u16) !*PgPool {
        const pg_pool_wrapper = try allocator.create(PgPool);
        errdefer allocator.destroy(pg_pool_wrapper);

        // Parse connection string (format: postgresql://user:password@host:port/database)
        const uri = std.Uri.parse(connection_string) catch {
            std.debug.print("Failed to parse connection string: {s}\n", .{connection_string});
            return PgError.ConnectionFailed;
        };

        const pool = try pg.Pool.initUri(allocator, uri, .{
            .size = pool_size,
            .timeout = 10_000,
        });

        pg_pool_wrapper.* = PgPool{
            .pool = pool,
            .allocator = allocator,
        };

        std.debug.print("PostgreSQL pool initialized with {d} connections\n", .{pool_size});
        return pg_pool_wrapper;
    }

    pub fn deinit(self: *PgPool) void {
        self.pool.deinit();
        self.allocator.destroy(self);
    }

    pub fn acquire(self: *PgPool) !*pg.Conn {
        return self.pool.acquire() catch |err| {
            std.debug.print("Failed to acquire connection: {}\n", .{err});
            return PgError.NoResult;
        };
    }

    pub fn release(self: *PgPool, conn: *pg.Conn) void {
        self.pool.release(conn);
    }
};

pub const PgResult = struct {
    result: pg.Result,
    allocator: std.mem.Allocator,
    pool: ?*PgPool = null,
    conn: ?*pg.Conn = null,

    pub fn deinit(self: *PgResult) void {
        self.result.deinit();
        if (self.pool) |pool| {
            if (self.conn) |conn| {
                pool.release(conn);
            }
        }
    }

    pub fn getRowCount(self: *PgResult) i32 {
        var count: i32 = 0;
        var iter_result = self.result;
        while (iter_result.next() catch null) |_| {
            count += 1;
        }
        return count;
    }

    pub fn getValue(self: *PgResult, row: i32, col: i32) ?[]const u8 {
        _ = self;
        _ = row;
        _ = col;
        // This method is not directly compatible with pg.zig's iteration model
        // Need to redesign the API
        return null;
    }

    pub fn getValueAlloc(self: *PgResult, row: i32, col: i32) !?[]u8 {
        _ = self;
        _ = row;
        _ = col;
        return null;
    }
};

pub fn executeQuery(conn: *pg.Conn, allocator: std.mem.Allocator, query: []const u8) !PgResult {
    _ = allocator;

    const result = conn.query(query, .{}) catch |err| {
        if (conn.err) |pge| {
            std.debug.print("Query failed: {s}\nQuery: {s}\n", .{ pge.message, query });
        }
        return err;
    };

    return PgResult{
        .result = result,
        .allocator = conn.allocator,
    };
}

pub fn executeQueryParams(
    conn: *pg.Conn,
    allocator: std.mem.Allocator,
    query: []const u8,
    params: []const []const u8,
) !PgResult {
    _ = allocator;
    _ = params;

    // pg.zig uses compile-time known parameters
    // This would need to be refactored to match pg.zig's API
    const result = conn.query(query, .{}) catch |err| {
        if (conn.err) |pge| {
            std.debug.print("Query failed: {s}\nQuery: {s}\n", .{ pge.message, query });
        }
        return err;
    };

    return PgResult{
        .result = result,
        .allocator = conn.allocator,
    };
}
