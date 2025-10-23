const std = @import("std");
const net = std.net;
const Router = @import("router.zig").Router;
const Method = @import("router.zig").Method;

pub const Server = struct {
    allocator: std.mem.Allocator,
    router: *Router,
    port: u16,

    pub fn init(allocator: std.mem.Allocator, router: *Router, port: u16) Server {
        return Server{
            .allocator = allocator,
            .router = router,
            .port = port,
        };
    }

    pub fn listen(self: *Server) !void {
        const address = try net.Address.parseIp("0.0.0.0", self.port);

        var server = try address.listen(.{
            .reuse_address = true,
        });
        defer server.deinit();

        std.debug.print("Server listening on http://0.0.0.0:{d}\n", .{self.port});
        std.debug.print("Ready to accept connections...\n", .{});

        while (true) {
            const connection = try server.accept();

            // Handle connection in a separate thread for concurrent requests
            const thread = try std.Thread.spawn(.{}, handleConnection, .{ self, connection });
            thread.detach();
        }
    }

    fn handleConnection(self: *Server, connection: net.Server.Connection) void {
        defer connection.stream.close();

        self.handleRequest(connection.stream) catch |err| {
            std.debug.print("Error handling request: {}\n", .{err});
            const error_response = "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n";
            _ = connection.stream.write(error_response) catch {};
        };
    }

    fn handleRequest(self: *Server, stream: net.Stream) !void {
        var buffer: [8192]u8 = undefined;
        const bytes_read = try stream.read(&buffer);

        if (bytes_read == 0) {
            return;
        }

        const request = buffer[0..bytes_read];

        // Parse HTTP request
        const parsed = try self.parseRequest(request);
        defer {
            self.allocator.free(parsed.method);
            self.allocator.free(parsed.path);
            if (parsed.body) |body| {
                self.allocator.free(body);
            }
        }

        // Get method enum
        const method = Method.fromString(parsed.method) orelse {
            try self.sendResponse(stream, 405, "Method Not Allowed", "application/json");
            return;
        };

        // Route the request
        var response = try self.router.route(method, parsed.path, parsed.body);
        defer response.deinit();

        // Send response
        try self.sendJsonResponse(stream, response.status, response.body);
    }

    const ParsedRequest = struct {
        method: []u8,
        path: []u8,
        headers: std.StringHashMap([]const u8),
        body: ?[]u8,
    };

    fn parseRequest(self: *Server, request: []const u8) !ParsedRequest {
        var lines = std.mem.splitSequence(u8, request, "\r\n");

        // Parse request line (e.g., "GET /path HTTP/1.1")
        const request_line = lines.next() orelse return error.InvalidRequest;
        var parts = std.mem.splitSequence(u8, request_line, " ");

        const method = parts.next() orelse return error.InvalidRequest;
        const path = parts.next() orelse return error.InvalidRequest;

        var headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer headers.deinit();

        // Parse headers
        var content_length: ?usize = null;
        while (lines.next()) |line| {
            if (line.len == 0) break; // Empty line signals end of headers

            if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
                const key = std.mem.trim(u8, line[0..colon_pos], " \t");
                const value = std.mem.trim(u8, line[colon_pos + 1 ..], " \t");

                try headers.put(key, value);

                // Check for Content-Length
                if (std.ascii.eqlIgnoreCase(key, "content-length")) {
                    content_length = try std.fmt.parseInt(usize, value, 10);
                }
            }
        }

        // Parse body if present
        var body: ?[]u8 = null;
        if (content_length) |len| {
            if (len > 0) {
                // Find the start of the body (after headers)
                const header_end = std.mem.indexOf(u8, request, "\r\n\r\n") orelse return error.InvalidRequest;
                const body_start = header_end + 4;

                if (body_start < request.len) {
                    const body_data = request[body_start..];
                    const actual_len = @min(len, body_data.len);
                    body = try self.allocator.dupe(u8, body_data[0..actual_len]);
                }
            }
        }

        headers.deinit(); // We don't need to keep headers around

        return ParsedRequest{
            .method = try self.allocator.dupe(u8, method),
            .path = try self.allocator.dupe(u8, path),
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = body,
        };
    }

    fn sendResponse(self: *Server, stream: net.Stream, status: u16, body: []const u8, content_type: []const u8) !void {
        const status_text = getStatusText(status);

        const response_header = try std.fmt.allocPrint(self.allocator, "HTTP/1.1 {d} {s}\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Content-Length: {d}\r\n" ++
            "Connection: close\r\n" ++
            "\r\n", .{ status, status_text, content_type, body.len });
        defer self.allocator.free(response_header);

        _ = try stream.write(response_header);
        _ = try stream.write(body);
    }

    fn sendJsonResponse(self: *Server, stream: net.Stream, status: u16, body: []const u8) !void {
        try self.sendResponse(stream, status, body, "application/json");
    }

    fn getStatusText(status: u16) []const u8 {
        return switch (status) {
            200 => "OK",
            201 => "Created",
            204 => "No Content",
            400 => "Bad Request",
            404 => "Not Found",
            405 => "Method Not Allowed",
            500 => "Internal Server Error",
            else => "Unknown",
        };
    }
};
