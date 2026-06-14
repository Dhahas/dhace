const std = @import("std");

/// A basic array-of-lines based text buffer structure that avoids large memmoves.
pub const EditorBuffer = struct {
    allocator: std.mem.Allocator,
    lines: std.ArrayList(std.ArrayList(u8)),
    
    cursor_line: usize = 0,
    cursor_col: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !*EditorBuffer {
        const self = try allocator.create(EditorBuffer);
        self.* = .{
            .allocator = allocator,
            .lines = std.ArrayList(std.ArrayList(u8)).empty,
            .cursor_line = 0,
            .cursor_col = 0,
        };
        // Always ensure at least one empty line exists.
        try self.lines.append(allocator, std.ArrayList(u8).empty);
        return self;
    }

    pub fn deinit(self: *EditorBuffer) void {
        for (self.lines.items) |*line| {
            line.deinit(self.allocator);
        }
        self.lines.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn clear(self: *EditorBuffer) !void {
        for (self.lines.items) |*line| {
            line.deinit(self.allocator);
        }
        self.lines.clearRetainingCapacity();
        try self.lines.append(self.allocator, std.ArrayList(u8).empty);
        self.cursor_line = 0;
        self.cursor_col = 0;
    }

    pub fn loadFromFile(self: *EditorBuffer, io_val: std.Io, path: []const u8) !void {
        try self.clear();

        const cwd = std.Io.Dir.cwd();
        var file = cwd.openFile(io_val, path, .{}) catch |err| return err;
        defer file.close(io_val);

        const stat_info = file.stat(io_val) catch |err| return err;
        if (stat_info.size == 0) return;

        const content = try self.allocator.alloc(u8, @intCast(stat_info.size));
        defer self.allocator.free(content);
        const bytes_read = try file.readPositionalAll(io_val, content, 0);
        const actual_content = content[0..bytes_read];

        // Discard the initial empty line
        self.lines.clearRetainingCapacity();

        var it = std.mem.splitScalar(u8, actual_content, '\n');
        while (it.next()) |line_str| {
            var line_arr = std.ArrayList(u8).empty;
            // Trim carriage return if it's Windows CRLF
            var len = line_str.len;
            if (len > 0 and line_str[len - 1] == '\r') {
                len -= 1;
            }
            try line_arr.appendSlice(self.allocator, line_str[0..len]);
            try self.lines.append(self.allocator, line_arr);
        }

        if (self.lines.items.len == 0) {
            try self.lines.append(self.allocator, std.ArrayList(u8).empty);
        }
        self.cursor_line = 0;
        self.cursor_col = 0;
    }

    pub fn saveToFile(self: *EditorBuffer, io_val: std.Io, path: []const u8) !void {
        const cwd = std.Io.Dir.cwd();
        var file = try cwd.createFile(io_val, path, .{});
        defer file.close(io_val);

        for (self.lines.items, 0..) |line, i| {
            try file.writeStreamingAll(io_val, line.items);
            if (i < self.lines.items.len - 1) {
                try file.writeStreamingAll(io_val, "\n");
            }
        }
    }

    /// Navigation
    pub fn moveCursorUp(self: *EditorBuffer) void {
        if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            const line_len = self.lines.items[self.cursor_line].items.len;
            if (self.cursor_col > line_len) {
                self.cursor_col = line_len;
            }
        } else {
            self.cursor_col = 0;
        }
    }

    pub fn moveCursorDown(self: *EditorBuffer) void {
        if (self.cursor_line < self.lines.items.len - 1) {
            self.cursor_line += 1;
            const line_len = self.lines.items[self.cursor_line].items.len;
            if (self.cursor_col > line_len) {
                self.cursor_col = line_len;
            }
        } else {
            self.cursor_col = self.lines.items[self.cursor_line].items.len;
        }
    }

    pub fn moveCursorLeft(self: *EditorBuffer) void {
        if (self.cursor_col > 0) {
            self.cursor_col -= 1;
        } else if (self.cursor_line > 0) {
            self.cursor_line -= 1;
            self.cursor_col = self.lines.items[self.cursor_line].items.len;
        }
    }

    pub fn moveCursorRight(self: *EditorBuffer) void {
        const line_len = self.lines.items[self.cursor_line].items.len;
        if (self.cursor_col < line_len) {
            self.cursor_col += 1;
        } else if (self.cursor_line < self.lines.items.len - 1) {
            self.cursor_line += 1;
            self.cursor_col = 0;
        }
    }

    /// Editing
    pub fn insertChar(self: *EditorBuffer, c: u8) !void {
        if (c == '\n' or c == '\r') {
            try self.insertNewline();
            return;
        }
        var line = &self.lines.items[self.cursor_line];
        try line.insert(self.allocator, self.cursor_col, c);
        self.cursor_col += 1;
    }

    pub fn insertNewline(self: *EditorBuffer) !void {
        var line = &self.lines.items[self.cursor_line];
        const right_side = try self.allocator.dupe(u8, line.items[self.cursor_col..]);
        errdefer self.allocator.free(right_side);

        line.shrinkAndFree(self.allocator, self.cursor_col);

        var new_line = std.ArrayList(u8).empty;
        try new_line.appendSlice(self.allocator, right_side);
        self.allocator.free(right_side);

        try self.lines.insert(self.allocator, self.cursor_line + 1, new_line);
        self.cursor_line += 1;
        self.cursor_col = 0;
    }

    pub fn backspace(self: *EditorBuffer) !void {
        if (self.cursor_col > 0) {
            var line = &self.lines.items[self.cursor_line];
            _ = line.orderedRemove(self.cursor_col - 1);
            self.cursor_col -= 1;
        } else if (self.cursor_line > 0) {
            var curr_line = self.lines.orderedRemove(self.cursor_line);
            defer curr_line.deinit(self.allocator);

            self.cursor_line -= 1;
            var prev_line = &self.lines.items[self.cursor_line];
            self.cursor_col = prev_line.items.len;
            
            try prev_line.appendSlice(self.allocator, curr_line.items);
        }
    }
};

test "EditorBuffer basic ops" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var buf = try EditorBuffer.init(allocator);
    defer buf.deinit();

    try buf.insertChar('H');
    try buf.insertChar('i');
    try testing.expectEqualStrings("Hi", buf.lines.items[0].items);
    try testing.expectEqual(@as(usize, 2), buf.cursor_col);

    try buf.insertNewline();
    try buf.insertChar('Z');
    try buf.insertChar('i');
    try buf.insertChar('g');

    try testing.expectEqual(@as(usize, 2), buf.lines.items.len);
    try testing.expectEqualStrings("Hi", buf.lines.items[0].items);
    try testing.expectEqualStrings("Zig", buf.lines.items[1].items);
    try testing.expectEqual(@as(usize, 1), buf.cursor_line);
    try testing.expectEqual(@as(usize, 3), buf.cursor_col);

    buf.moveCursorLeft();
    try buf.backspace();
    try testing.expectEqualStrings("Zg", buf.lines.items[1].items);
    
    // backspace across lines
    buf.moveCursorUp();
    buf.moveCursorDown();
    buf.cursor_col = 0;
    try buf.backspace();
    try testing.expectEqual(@as(usize, 1), buf.lines.items.len);
    try testing.expectEqualStrings("HiZg", buf.lines.items[0].items);
}
