const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to select
    // between CPU architectures, OSs, etc.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dhace",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Link zglfw (compiles GLFW from source)
    const zglfw_dep = b.dependency("zglfw", .{});
    exe.root_module.addImport("zglfw", zglfw_dep.module("root"));
    exe.root_module.linkLibrary(zglfw_dep.artifact("glfw"));

    // OS-specific library linking
    if (target.result.os.tag == .windows) {
        exe.root_module.linkSystemLibrary("opengl32", .{});
        exe.root_module.linkSystemLibrary("gdi32", .{});
        exe.root_module.linkSystemLibrary("user32", .{});
        exe.root_module.linkSystemLibrary("shell32", .{});
    } else if (target.result.os.tag == .macos) {
        exe.root_module.linkFramework("OpenGL", .{});
        exe.root_module.linkFramework("Cocoa", .{});
        exe.root_module.linkFramework("IOKit", .{});
        exe.root_module.linkFramework("CoreVideo", .{});
    } else {
        exe.root_module.linkSystemLibrary("GL", .{});
    }

    // Add zgui dependency from package manager
    const zgui_dep = b.dependency("zgui", .{
        .shared = false,
        .with_implot = false,
        .backend = .glfw_opengl3,
    });
    exe.root_module.addImport("zgui", zgui_dep.module("root"));
    exe.root_module.linkLibrary(zgui_dep.artifact("imgui"));

    // Add zopengl dependency
    const zopengl_dep = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl_dep.module("root"));

    // Install build artifacts
    b.installArtifact(exe);

    // Add run step for convenient testing/execution
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Set up unit testing
    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
