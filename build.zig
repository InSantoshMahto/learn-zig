const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add pg.zig dependency
    const pg = b.dependency("pg", .{
        .target = target,
        .optimize = optimize,
    });

    // Add zig-okredis dependency
    const okredis = b.dependency("okredis", .{
        .target = target,
        .optimize = optimize,
    });

    // Create the root module (modern API)
    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    root_module.addImport("pg", pg.module("pg"));
    root_module.addImport("okredis", okredis.module("okredis"));

    // Add executable
    const exe = b.addExecutable(.{
        .name = "api",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_module = root_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
