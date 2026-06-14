const std = @import("std");
const LanguageManager = @import("core/language_manager.zig").LanguageManager;
const EditorBuffer = @import("core/editor_buffer.zig").EditorBuffer;

/// Represents the global application state.
/// This acts as the single source of truth for the entire application.
pub const App = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    language_manager: LanguageManager,

    // File state
    file_path: ?[]const u8 = null,
    editor_buf: *EditorBuffer,

    // Buffers for UI text inputs
    status_message: [256:0]u8 = std.mem.zeroes([256:0]u8),
    cmd_input_buf: [256:0]u8 = std.mem.zeroes([256:0]u8),
    last_action_message: [256:0]u8 = std.mem.zeroes([256:0]u8),
    char_queue: std.ArrayList(u8),

    // Dialog flags
    show_about_dialog: bool = false,

    /// Initializes and returns the global App state structure.
    pub fn init(allocator: std.mem.Allocator, io: std.Io) !*App {
        const self = try allocator.create(App);

        const buf = try EditorBuffer.init(allocator);

        const lm = try LanguageManager.init(allocator);

        self.* = .{
            .allocator = allocator,
            .io = io,
            .language_manager = lm,
            .file_path = null,
            .editor_buf = buf,
            .char_queue = std.ArrayList(u8).empty,
        };

        // Set initial status message
        _ = std.fmt.bufPrintZ(&self.status_message, "Ready", .{}) catch {};

        return self;
    }

    /// Cleans up any resources allocated by the app.
    pub fn deinit(self: *App) void {
        self.char_queue.deinit(self.allocator);
        self.language_manager.deinit();
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
        self.editor_buf.deinit();
        self.allocator.destroy(self);
    }

    /// Open a file and load its content into the editor buffer
    pub fn openFile(self: *App, path: []const u8) !void {
        const ext = std.fs.path.extension(path);
        
        if (!self.language_manager.isExtensionSupported(ext)) {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Unsupported file type '{s}'", .{ext}) catch {};
            return error.InvalidFileType;
        }

        self.editor_buf.loadFromFile(self.io, path) catch |err| {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Failed to open file: {s}", .{@errorName(err)}) catch {};
            return err;
        };

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

        self.editor_buf.saveToFile(self.io, path) catch |err| {
            _ = std.fmt.bufPrintZ(&self.status_message, "Error: Failed to save: {s}", .{@errorName(err)}) catch {};
            return err;
        };
        _ = std.fmt.bufPrintZ(&self.status_message, "Saved: {s}", .{path}) catch {};
    }

    /// Clear current file content and path
    pub fn clearFile(self: *App) void {
        if (self.file_path) |p| {
            self.allocator.free(p);
            self.file_path = null;
        }
        self.editor_buf.clear() catch {};
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
    try std.testing.expectEqual(std.mem.len(app.editor_buf.lines.items), 1);
    try std.testing.expectEqual(std.mem.len(app.editor_buf.lines.items[0].items), 0);

    // Test invalid extension
    try std.testing.expectError(error.InvalidFileType, app.openFile("test.dat"));

    // Create a temporary text file
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

    // Create a temporary JSON file
    const test_json_filename = "test_temp_file.json";
    const json_content = "{\"hello\": \"world\"}";
    {
        const cwd = std.Io.Dir.cwd();
        var file = try cwd.createFile(io, test_json_filename, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, json_content);
    }
    defer {
        const cwd = std.Io.Dir.cwd();
        cwd.deleteFile(io, test_json_filename) catch {};
    }

    // Test opening text file
    try app.openFile(test_filename);
    try std.testing.expect(app.file_path != null);
    try std.testing.expectEqualStrings(test_filename, app.file_path.?);
    try std.testing.expectEqualStrings(content, app.editor_buf.lines.items[0].items);

    // Test opening JSON file
    try app.openFile(test_json_filename);
    try std.testing.expect(app.file_path != null);
    try std.testing.expectEqualStrings(test_json_filename, app.file_path.?);
    try std.testing.expectEqualStrings(json_content, app.editor_buf.lines.items[0].items);

    // Test editing and saving
    const new_content = "Hello, Zig editor! Modified.";
    try app.editor_buf.clear();
    for (new_content) |c| {
        try app.editor_buf.insertChar(c);
    }

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
