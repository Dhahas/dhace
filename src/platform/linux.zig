const std = @import("std");

/// Linux/Unix specific implementations.
pub fn showAlert(title: [*:0]const u8, message: [*:0]const u8) void {
    // Under the hood, this could invoke desktop notifications or print to standard streams.
    std.log.info("[Linux Alert] '{s}': {s}", .{ title, message });
}
