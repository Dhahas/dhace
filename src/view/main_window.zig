const std = @import("std");
const zgui = @import("zgui");
const App = @import("../app.zig").App;
const components = @import("components.zig");
const settings_panel = @import("settings_panel.zig");

/// Renders the primary workspace window and manages overlays.
pub fn render(app: *App) void {
    // Dock main window at standard location initially
    zgui.setNextWindowPos(.{ .x = 40, .y = 40, .cond = .first_use_ever });
    zgui.setNextWindowSize(.{ .w = 500, .h = 400, .cond = .first_use_ever });

    if (zgui.begin("Dashboard Control Panel", .{})) {
        zgui.textColored(.{ 0.5, 0.7, 1.0, 1.0 }, "Zig + zgui Native Application Architecture", .{});
        zgui.separator();
        zgui.spacing();

        zgui.text("This workspace illustrates clean separation of concerns in Zig.", .{});
        zgui.spacing();

        // 1. Render custom counter component
        if (components.counterButton("Workspace Actions", app.counter)) {
            app.incrementCounter();
        }

        zgui.spacing();
        zgui.separator();
        zgui.spacing();

        // 2. Action buttons
        if (zgui.button("Open Application Settings", .{ .w = -1 })) {
            app.show_settings = true;
        }

        zgui.spacing();

        // 3. Status display
        components.statusIndicator("Internal Database State", app.database_connected);
    }
    zgui.end();

    // Render child views if toggled open
    if (app.show_settings) {
        settings_panel.render(app);
    }
}
