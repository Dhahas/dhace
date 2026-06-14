const std = @import("std");
const builtin = @import("builtin");
const zgui = @import("zgui");
const zglfw = @import("zglfw");
const zopengl = @import("zopengl");

const App = @import("app.zig").App;
const main_window = @import("view/main_window.zig");

// Reference core modules so their tests run
comptime {
    _ = @import("core/language_manager.zig");
}

// Load platform-specific utilities conditionally
const platform = switch (builtin.os.tag) {
    .windows => @import("platform/win32.zig"),
    else => @import("platform/linux.zig"),
};

pub fn main(init: std.process.Init) !void {
    // 1. Initialize Memory Allocator
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
    const window = try zglfw.Window.create(1280, 720, "dhace", null, null);
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

    // Load custom high-resolution modern font
    _ = zgui.io.addFontFromFile("assets/JetBrainsMono-Regular.ttf", 18.0);

    // Switch to ImGui light mode globally
    zgui.styleColorsLight(zgui.getStyle());

    // 4. Initialize Core Application State (The Model)
    const app = try App.init(allocator, init.io);
    defer app.deinit();

    window.setUserPointer(app);
    _ = window.setCharCallback(charCallback);

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
        main_window.render(app, @floatFromInt(w), @floatFromInt(h));

        // Clear display buffer
        zopengl.bindings.viewport(0, 0, w, h);
        zopengl.bindings.clearColor(0.90, 0.90, 0.92, 1.0); // Modern premium light-gray background
        zopengl.bindings.clear(zopengl.bindings.COLOR_BUFFER_BIT);

        // Render ImGui draw lists to the screen
        zgui.backend.draw();

        window.swapBuffers();
    }
}

fn charCallback(window: *zglfw.Window, codepoint: u32) callconv(.c) void {
    const app_ptr = window.getUserPointer(App);
    if (app_ptr) |app| {
        if (codepoint < 128) {
            app.char_queue.append(app.allocator, @intCast(codepoint)) catch {};
        }
    }
}
