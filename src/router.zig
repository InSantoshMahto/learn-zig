const std = @import("std");
const UserHandlers = @import("handlers/users.zig").UserHandlers;

pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    OPTIONS,

    pub fn fromString(method: []const u8) ?Method {
        if (std.mem.eql(u8, method, "GET")) return .GET;
        if (std.mem.eql(u8, method, "POST")) return .POST;
        if (std.mem.eql(u8, method, "PUT")) return .PUT;
        if (std.mem.eql(u8, method, "DELETE")) return .DELETE;
        if (std.mem.eql(u8, method, "PATCH")) return .PATCH;
        if (std.mem.eql(u8, method, "OPTIONS")) return .OPTIONS;
        return null;
    }
};

pub const Response = struct {
    status: u16,
    body: []const u8,
    content_type: []const u8 = "application/json",
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, status: u16, body: []const u8) Response {
        return Response{
            .status = status,
            .body = body,
            .content_type = "application/json",
            .allocator = allocator,
        };
    }

    pub fn json(allocator: std.mem.Allocator, status: u16, body: []const u8) Response {
        return Response{
            .status = status,
            .body = body,
            .content_type = "application/json",
            .allocator = allocator,
        };
    }

    pub fn error_response(allocator: std.mem.Allocator, status: u16, message: []const u8) !Response {
        const error_json = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{message});
        return Response{
            .status = status,
            .body = error_json,
            .content_type = "application/json",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
    }
};

pub const Router = struct {
    user_handlers: *UserHandlers,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, user_handlers: *UserHandlers) Router {
        return Router{
            .user_handlers = user_handlers,
            .allocator = allocator,
        };
    }

    pub fn route(self: *Router, method: Method, path: []const u8, body: ?[]const u8) !Response {
        std.debug.print("{s} {s}\n", .{ @tagName(method), path });

        // Health check endpoint
        if (method == .GET and std.mem.eql(u8, path, "/health")) {
            const response_body = try self.allocator.dupe(u8, "{\"status\":\"ok\"}");
            return Response.json(self.allocator, 200, response_body);
        }

        // API routes
        if (std.mem.startsWith(u8, path, "/api/users")) {
            return self.handleUserRoutes(method, path, body);
        }

        // 404 Not Found
        return try Response.error_response(self.allocator, 404, "Not Found");
    }

    fn handleUserRoutes(self: *Router, method: Method, path: []const u8, body: ?[]const u8) !Response {
        // GET /api/users - Get all users
        if (method == .GET and std.mem.eql(u8, path, "/api/users")) {
            const users_json = self.user_handlers.getAllUsers() catch |err| {
                std.debug.print("Error getting users: {}\n", .{err});
                return try Response.error_response(self.allocator, 500, "Internal Server Error");
            };
            return Response.json(self.allocator, 200, users_json);
        }

        // POST /api/users - Create user
        if (method == .POST and std.mem.eql(u8, path, "/api/users")) {
            if (body == null) {
                return try Response.error_response(self.allocator, 400, "Request body required");
            }

            const user_json = self.user_handlers.createUser(body.?) catch |err| {
                std.debug.print("Error creating user: {}\n", .{err});
                if (err == error.MissingFields) {
                    return try Response.error_response(self.allocator, 400, "Missing required fields: name, email");
                }
                if (err == error.InvalidJson) {
                    return try Response.error_response(self.allocator, 400, "Invalid JSON");
                }
                return try Response.error_response(self.allocator, 500, "Internal Server Error");
            };
            return Response.json(self.allocator, 201, user_json);
        }

        // Routes with ID parameter: /api/users/:id
        if (std.mem.startsWith(u8, path, "/api/users/")) {
            const id_str = path[11..]; // Skip "/api/users/"

            // Check if there are any more slashes (invalid path)
            if (std.mem.indexOf(u8, id_str, "/") != null) {
                return try Response.error_response(self.allocator, 404, "Not Found");
            }

            const id = std.fmt.parseInt(i32, id_str, 10) catch {
                return try Response.error_response(self.allocator, 400, "Invalid user ID");
            };

            // GET /api/users/:id - Get user by ID
            if (method == .GET) {
                const user_json = self.user_handlers.getUserById(id) catch |err| {
                    std.debug.print("Error getting user {d}: {}\n", .{ id, err });
                    if (err == error.NotFound) {
                        return try Response.error_response(self.allocator, 404, "User not found");
                    }
                    return try Response.error_response(self.allocator, 500, "Internal Server Error");
                };
                return Response.json(self.allocator, 200, user_json);
            }

            // PUT /api/users/:id - Update user
            if (method == .PUT) {
                if (body == null) {
                    return try Response.error_response(self.allocator, 400, "Request body required");
                }

                const user_json = self.user_handlers.updateUser(id, body.?) catch |err| {
                    std.debug.print("Error updating user {d}: {}\n", .{ id, err });
                    if (err == error.NotFound) {
                        return try Response.error_response(self.allocator, 404, "User not found");
                    }
                    if (err == error.NoFieldsToUpdate) {
                        return try Response.error_response(self.allocator, 400, "No fields to update");
                    }
                    if (err == error.InvalidJson) {
                        return try Response.error_response(self.allocator, 400, "Invalid JSON");
                    }
                    return try Response.error_response(self.allocator, 500, "Internal Server Error");
                };
                return Response.json(self.allocator, 200, user_json);
            }

            // DELETE /api/users/:id - Delete user
            if (method == .DELETE) {
                self.user_handlers.deleteUser(id) catch |err| {
                    std.debug.print("Error deleting user {d}: {}\n", .{ id, err });
                    return try Response.error_response(self.allocator, 500, "Internal Server Error");
                };
                const response_body = try self.allocator.dupe(u8, "{\"message\":\"User deleted successfully\"}");
                return Response.json(self.allocator, 200, response_body);
            }
        }

        // Method not allowed or not found
        return try Response.error_response(self.allocator, 405, "Method Not Allowed");
    }
};
