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
    const musubi = b.dependency("Musubi", .{ .target = target, .optimize = optimize });

    const exe = b.addExecutable(.{ .name = "day11", .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }) });
    exe.root_module.addImport(data.name, data.module);
    exe.root_module.addImport(utils.name, utils.module);
    exe.root_module.addImport("musubi", musubi.artifact("Musubi").root_module);
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
    test_exe.root_module.addImport("musubi", musubi.artifact("Musubi").root_module);

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

/// Add a unit test step using the given file
///
/// @param[inout] b: Mutable pointer to the Build object
/// @param[in] cmd: The build step name ('zig build cmd')
/// @param[in] description: The description for 'zig build -l'
/// @param[in] path: The zig file to test
/// @param[in] optimize: Build optimization settings
fn addTest(b: *std.Build, cmd: []const u8, description: []const u8, root_module: *std.Build.Module, modules: []const Module) void {
    const test_exe = b.addTest(.{
        .root_module = root_module,
    });
    for (modules) |mod| {
        test_exe.root_module.addImport(mod.name, mod.module);
    }

    const run_step = b.addRunArtifact(test_exe);
    run_step.has_side_effects = true; // Force the test to always be run on command
    const step = b.step(cmd, description);
    step.dependOn(&run_step.step);
}
