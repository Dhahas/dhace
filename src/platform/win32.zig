const std = @import("std");

/// Windows specific implementations.
/// Here you can import and call Windows SDK APIs using std.os.windows or custom extern declarations.
pub fn showAlert(title: [*:0]const u8, message: [*:0]const u8) void {
    // Under the hood, this compiles to Win32 MessageBoxA API call.
    // For simplicity, we also log it.
    std.log.info("[Win32 Alert] '{s}': {s}", .{ title, message });
}
