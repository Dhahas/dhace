const std = @import("std");
const zgui = @import("zgui");
const App = @import("../app.zig").App;
const components = @import("components.zig");

/// Renders the settings panel window.
pub fn render(app: *App) void {
    // Setup window size constraints
    zgui.setNextWindowSize(.{ .w = 350, .h = 250, .cond = .first_use_ever });

    if (zgui.begin("Settings", .{ .popen = &app.show_settings })) {
        zgui.textUnformatted("Application Settings Panel");
        zgui.separator();
        zgui.spacing();

        // Database connection toggle inside the settings view
        zgui.textUnformatted("Database Administration:");
        if (zgui.button(if (app.database_connected) "Disconnect DB" else "Connect DB", .{})) {
            app.toggleDatabaseConnection();
        }

        zgui.spacing();
        zgui.separator();
        zgui.spacing();

        // Display current connection status
        components.statusIndicator("System DB Status", app.database_connected);

        zgui.spacing();

        if (zgui.button("Close Settings", .{ .w = -1 })) {
            app.show_settings = false;
        }
    }
    zgui.end();
}
