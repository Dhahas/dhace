const std = @import("std");

/// Represents the global application state.
/// This acts as the single source of truth for the entire application.
pub const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,

    // File state
    file_path: ?[]const u8 = null,
    editor_buf: [:0]u8,

    // Buffers for UI text inputs
    status_message: [256:0]u8 = std.mem.zeroes([256:0]u8),
    cmd_input_buf: [256:0]u8 = std.mem.zeroes([256:0]u8),
    open_dialog_path_buf: [512:0]u8 = std.mem.zeroes([512:0]u8),
    last_action_message: [256:0]u8 = std.mem.zeroes([256:0]u8),

    // Dialog flags
    show_open_dialog: bool = false,
    show_about_dialog: bool = false,

    /// Initializes and returns the global App state structure.
    pub fn init(allocator: std.mem.Allocator, io: std.Io) !*App {
        const self = try allocator.create(App);

        // Allocate a 64KB editor buffer with sentinel 0
        const buf = try allocator.allocSentinel(u8, 65535, 0);
        @memset(buf, 0);

        self.* = .{
            .allocator = allocator,
            .io = io,
            .file_path = null,
            .editor_buf = buf,
        };

        // Set initial status message
        _ = std.fmt.bufPrintZ(&self.status_message, "Ready", .{}) catch {};

        return self;
    }

    /// Cleans up any resources allocated by the app.
    pub fn deinit(self: *App) void {
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
        self.allocator.free(self.editor_buf);
        self.allocator.destroy(self);
    }

    /// Open a file and load its content into the editor buffer
    pub fn openFile(self: *App, path: []const u8) !void {
        // Validate file extension is .txt
        if (!std.mem.endsWith(u8, path, ".txt")) {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Only .txt files are allowed", .{}) catch {};
            return error.InvalidFileType;
        }

        const cwd = std.Io.Dir.cwd();
        var file = cwd.openFile(self.io, path, .{}) catch |err| {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Failed to open file: {s}", .{@errorName(err)}) catch {};
            return err;
        };
        defer file.close(self.io);

        const stat_info = file.stat(self.io) catch |err| {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Failed to stat file: {s}", .{@errorName(err)}) catch {};
            return err;
        };
        const size = stat_info.size;

        if (size >= self.editor_buf.len) {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: File too large (max 64KB)", .{}) catch {};
            return error.FileTooLarge;
        }

        const bytes_read = file.readPositionalAll(self.io, self.editor_buf[0..size], 0) catch |err| {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Failed to read file: {s}", .{@errorName(err)}) catch {};
            return err;
        };
        self.editor_buf[bytes_read] = 0; // null terminator

        // Free previous path if any
        if (self.file_path) |p| {
            self.allocator.free(p);
            self.file_path = null;
        }

        self.file_path = try self.allocator.dupe(u8, path);
        _ = std.fmt.bufPrintZ(&self.status_message, "Opened: {s}", .{path}) catch {};
    }

    /// Save the editor buffer content to the open file
    pub fn saveFile(self: *App) !void {
        const path = self.file_path orelse {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: No file is currently open to save", .{}) catch {};
            return error.NoFileOpen;
        };

        const cwd = std.Io.Dir.cwd();
        var file = cwd.createFile(self.io, path, .{}) catch |err| {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Failed to save: {s}", .{@errorName(err)}) catch {};
            return err;
        };
        defer file.close(self.io);

        const len = std.mem.len(self.editor_buf.ptr);
        try file.writeStreamingAll(self.io, self.editor_buf[0..len]);
        _ = std.fmt.bufPrintZ(&self.status_message, "Saved: {s}", .{path}) catch {};
    }

    /// Clear current file content and path
    pub fn clearFile(self: *App) void {
        if (self.file_path) |p| {
            self.allocator.free(p);
            self.file_path = null;
        }
        @memset(self.editor_buf, 0);
        _ = std.fmt.bufPrintZ(&self.status_message, "New file created", .{}) catch {};
    }
};

test "App file operations" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    const app = try App.init(allocator, io);
    defer app.deinit();

    // Verify initial state
    try std.testing.expect(app.file_path == null);
    try std.testing.expectEqual(std.mem.len(app.editor_buf.ptr), 0);

    // Test invalid extension
    try std.testing.expectError(error.InvalidFileType, app.openFile("test.dat"));

    // Create a temporary file
    const test_filename = "test_temp_file.txt";
    const content = "Hello, Zig editor!";
    {
        const cwd = std.Io.Dir.cwd();
        var file = try cwd.createFile(io, test_filename, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, content);
    }
    defer {
        const cwd = std.Io.Dir.cwd();
        cwd.deleteFile(io, test_filename) catch {};
    }

    // Test opening file
    try app.openFile(test_filename);
    try std.testing.expect(app.file_path != null);
    try std.testing.expectEqualStrings(test_filename, app.file_path.?);
    try std.testing.expectEqualStrings(content, std.mem.sliceTo(app.editor_buf, 0));

    // Test editing and saving
    const new_content = "Hello, Zig editor! Modified.";
    @memcpy(app.editor_buf[0..new_content.len], new_content);
    app.editor_buf[new_content.len] = 0;

    try app.saveFile();

    // Re-read file to verify
    {
        const cwd = std.Io.Dir.cwd();
        var file = try cwd.openFile(io, test_filename, .{});
        defer file.close(io);
        var temp_buf: [100]u8 = undefined;
        const read_len = try file.readPositionalAll(io, &temp_buf, 0);
        try std.testing.expectEqualStrings(new_content, temp_buf[0..read_len]);
    }

    // Test clearFile
    app.clearFile();
    try std.testing.expect(app.file_path == null);
    try std.testing.expectEqual(std.mem.len(app.editor_buf.ptr), 0);
}
