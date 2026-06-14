const std = @import("std");
const builtin = @import("builtin");
const zgui = @import("zgui");
const zglfw = @import("zglfw");

const App = @import("app.zig").App;
const main_window = @import("view/main_window.zig");

const zopengl = @import("zopengl");

// Load platform-specific utilities conditionally
const platform = switch (builtin.os.tag) {
    .windows => @import("platform/win32.zig"),
    else => @import("platform/linux.zig"),
};

pub fn main() !void {
    // 1. Initialize Memory Allocator
    // Since we compile GLFW from source and link libc, we can use the native C allocator directly.
    const allocator = std.heap.c_allocator;

    // 2. Initialize zglfw
    try zglfw.init();
    defer zglfw.terminate();

    // Set GLFW window hints for OpenGL 3.3 Core Profile
    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    if (builtin.os.tag == .macos) {
        zglfw.windowHint(.opengl_forward_compat, true);
    }

    // Create Main Window
    const window = try zglfw.Window.create(1280, 720, "Zig + zgui Application", null, null);
    defer window.destroy();

    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1); // Enable v-sync to prevent screen tearing

    // Initialize OpenGL loader (zopengl)
    try zopengl.loadCoreProfile(zglfw.getProcAddress, 3, 3);

    // 3. Initialize zgui (Dear ImGui bindings)
    zgui.init(allocator);
    defer zgui.deinit();

    // Initialize zgui backend for GLFW and OpenGL3
    zgui.backend.init(window);
    defer zgui.backend.deinit();

    // 4. Initialize Core Application State (The Model)
    const app = try App.init(allocator);
    defer app.deinit();

    // Trigger platform-specific window start alert
    platform.showAlert("System Startup", "Zig + zgui application started successfully.");

    // 5. Main Render/Event Loop
    while (!window.shouldClose()) {
        zglfw.pollEvents();

        // Retrieve current window dimensions
        const size = window.getFramebufferSize();
        const w = size[0];
        const h = size[1];

        // Start new ImGui frame
        zgui.backend.newFrame(@intCast(w), @intCast(h));

        // Render main view
        main_window.render(app);

        // Clear display buffer
        zopengl.bindings.viewport(0, 0, w, h);
        zopengl.bindings.clearColor(0.09, 0.09, 0.1, 1.0); // Modern sleek dark-mode background
        zopengl.bindings.clear(zopengl.bindings.COLOR_BUFFER_BIT);

        // Render ImGui draw lists to the screen
        zgui.backend.draw();

        window.swapBuffers();
    }
}
