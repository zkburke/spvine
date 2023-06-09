pub fn build(builder: *std.Build) void {
    const target = builder.standardTargetOptions(.{});

    const optimize = builder.standardOptimizeOption(.{});

    const exe = builder.addExecutable(.{
        .name = "spvine",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    builder.installArtifact(exe);

    const run_cmd = builder.addRunArtifact(exe);

    run_cmd.step.dependOn(builder.getInstallStep());

    if (builder.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = builder.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = builder.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = builder.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

const std = @import("std");
