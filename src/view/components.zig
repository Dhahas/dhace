const std = @import("std");
const zgui = @import("zgui");

/// Renders a highly reusable styled counter button.
/// Changes button color dynamically to look premium, and returns true if clicked.
pub fn counterButton(label: [:0]const u8, count: i32) bool {
    // Apply a modern violet-blue button color theme
    zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.35, 0.3, 0.75, 1.0 } });
    zgui.pushStyleColor4f(.{ .idx = .button_hovered, .c = .{ 0.45, 0.4, 0.85, 1.0 } });
    zgui.pushStyleColor4f(.{ .idx = .button_active, .c = .{ 0.25, 0.2, 0.65, 1.0 } });
    defer zgui.popStyleColor(.{ .count = 3 });

    var buffer: [128]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buffer, "{s}: {d}", .{ label, count }) catch "Counter";

    return zgui.button(text, .{ .w = 200, .h = 0 });
}

/// Renders a unified status indicator with text and custom badge coloring.
pub fn statusIndicator(label: []const u8, connected: bool) void {
    zgui.alignTextToFramePadding();
    zgui.text("{s}: ", .{label});
    zgui.sameLine(.{});
    if (connected) {
        zgui.textColored(.{ 0.2, 0.85, 0.2, 1.0 }, "ONLINE", .{});
    } else {
        zgui.textColored(.{ 0.85, 0.2, 0.2, 1.0 }, "OFFLINE", .{});
    }
}
