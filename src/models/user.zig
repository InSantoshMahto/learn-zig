const std = @import("std");

pub const User = struct {
    id: i32,
    name: []const u8,
    email: []const u8,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,

    pub fn deinit(self: *User, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.email);
        if (self.created_at) |created| {
            allocator.free(created);
        }
        if (self.updated_at) |updated| {
            allocator.free(updated);
        }
    }

    pub fn toJson(self: User, allocator: std.mem.Allocator) ![]u8 {
        var buffer: std.ArrayList(u8) = .empty;
        defer buffer.deinit(allocator);

        try buffer.appendSlice(allocator, "{\"id\":");
        try buffer.appendSlice(allocator, try std.fmt.allocPrint(allocator, "{d}", .{self.id}));
        try buffer.appendSlice(allocator, ",\"name\":\"");
        try buffer.appendSlice(allocator, self.name);
        try buffer.appendSlice(allocator, "\",\"email\":\"");
        try buffer.appendSlice(allocator, self.email);
        try buffer.appendSlice(allocator, "\"");

        if (self.created_at) |created| {
            try buffer.appendSlice(allocator, ",\"created_at\":\"");
            try buffer.appendSlice(allocator, created);
            try buffer.appendSlice(allocator, "\"");
        }

        if (self.updated_at) |updated| {
            try buffer.appendSlice(allocator, ",\"updated_at\":\"");
            try buffer.appendSlice(allocator, updated);
            try buffer.appendSlice(allocator, "\"");
        }

        try buffer.appendSlice(allocator, "}");

        return allocator.dupe(u8, buffer.items);
    }
};

pub const CreateUserRequest = struct {
    name: []const u8,
    email: []const u8,

    pub fn fromJson(allocator: std.mem.Allocator, json_str: []const u8) !CreateUserRequest {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;

        const name_value = obj.get("name") orelse return error.MissingFields;
        const email_value = obj.get("email") orelse return error.MissingFields;

        if (name_value != .string or email_value != .string) {
            return error.InvalidJson;
        }

        return CreateUserRequest{
            .name = try allocator.dupe(u8, name_value.string),
            .email = try allocator.dupe(u8, email_value.string),
        };
    }

    pub fn deinit(self: *CreateUserRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.email);
    }
};

pub const UpdateUserRequest = struct {
    name: ?[]const u8 = null,
    email: ?[]const u8 = null,

    pub fn fromJson(allocator: std.mem.Allocator, json_str: []const u8) !UpdateUserRequest {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
        defer parsed.deinit();

        const obj = parsed.value.object;

        var name: ?[]const u8 = null;
        var email: ?[]const u8 = null;

        if (obj.get("name")) |name_value| {
            if (name_value == .string) {
                name = try allocator.dupe(u8, name_value.string);
            }
        }

        if (obj.get("email")) |email_value| {
            if (email_value == .string) {
                email = try allocator.dupe(u8, email_value.string);
            }
        }

        return UpdateUserRequest{
            .name = name,
            .email = email,
        };
    }

    pub fn deinit(self: *UpdateUserRequest, allocator: std.mem.Allocator) void {
        if (self.name) |n| allocator.free(n);
        if (self.email) |e| allocator.free(e);
    }
};
