const std = @import("std");

/// Combination Build Module and name
const Module = struct {
    name: []const u8,
    module: *std.Build.Module,
};

pub fn build(b: *std.Build) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const data = createModule(b, "data", "data/data.zig", target);
    const utils = createModule(b, "utils", "../common/utils.zig", target);
    const ziglangSet = b.dependency("ziglangSet", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{ .name = "day5", .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    exe.root_module.addImport(data.name, data.module);
    exe.root_module.addImport(utils.name, utils.module);
    exe.root_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const modules: [2]Module = [_]Module{ data, utils };
    const root_module: *std.Build.Module = exe.root_module;

    const test_exe = b.addTest(.{
        .root_module = root_module,
    });
    for (modules) |mod| {
        test_exe.root_module.addImport(mod.name, mod.module);
    }
    test_exe.root_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));

    const test_step = b.addRunArtifact(test_exe);
    test_step.has_side_effects = true; // Force the test to always be run on command
    const step = b.step("test", "Run unit tests");
    step.dependOn(&test_step.step);
}

/// Create a new ModuleDependency
fn createModule(b: *std.Build, name: []const u8, source_file: []const u8, target: std.Build.ResolvedTarget) Module {
    return Module{
        .name = name,
        .module = b.addModule(name, .{ .root_source_file = b.path(source_file), .target = target }),
    };
}
