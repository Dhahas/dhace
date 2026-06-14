const std = @import("std");
const language = @import("language.zig");
const LanguagePlugin = language.LanguagePlugin;

// Built-in plugins
const plain_text = @import("../plugins/plain_text.zig").plugin;
const json = @import("../plugins/json.zig").plugin;

pub const LanguageManager = struct {
    allocator: std.mem.Allocator,
    plugins: std.ArrayList(*const LanguagePlugin),

    pub fn init(allocator: std.mem.Allocator) !LanguageManager {
        var self = LanguageManager{
            .allocator = allocator,
            .plugins = .empty,
        };

        // Register built-ins
        try self.registerPlugin(&plain_text);
        try self.registerPlugin(&json);

        return self;
    }

    pub fn deinit(self: *LanguageManager) void {
        self.plugins.deinit(self.allocator);
    }

    pub fn registerPlugin(self: *LanguageManager, plugin: *const LanguagePlugin) !void {
        try self.plugins.append(self.allocator, plugin);
    }

    pub fn getPluginForExtension(self: *const LanguageManager, ext: []const u8) *const LanguagePlugin {
        for (self.plugins.items) |plugin| {
            for (plugin.file_extensions) |plugin_ext| {
                if (std.mem.eql(u8, ext, plugin_ext)) {
                    return plugin;
                }
            }
        }
        return self.getDefaultPlugin();
    }

    pub fn isExtensionSupported(self: *const LanguageManager, ext: []const u8) bool {
        for (self.plugins.items) |plugin| {
            for (plugin.file_extensions) |plugin_ext| {
                if (std.mem.eql(u8, ext, plugin_ext)) {
                    return true;
                }
            }
        }
        return false;
    }

    pub fn getDefaultPlugin(self: *const LanguageManager) *const LanguagePlugin {
        _ = self;
        return &plain_text;
    }

    /// Caller must free the returned string. Returns a comma-separated list of extensions (e.g. "txt,json,md") without the leading dot.
    pub fn getAllExtensionsFilter(self: *const LanguageManager, allocator: std.mem.Allocator) ![:0]u8 {
        var buf = std.ArrayList(u8).empty;
        errdefer buf.deinit(allocator);

        var first = true;
        for (self.plugins.items) |plugin| {
            for (plugin.file_extensions) |ext| {
                if (!first) {
                    try buf.append(allocator, ',');
                }
                first = false;
                // ext includes the dot (e.g. ".txt"). We skip it.
                if (ext.len > 1 and ext[0] == '.') {
                    try buf.appendSlice(allocator, ext[1..]);
                } else {
                    try buf.appendSlice(allocator, ext);
                }
            }
        }
        return buf.toOwnedSliceSentinel(allocator, 0);
    }
};

test "LanguageManager basic functionality" {
    const allocator = std.testing.allocator;
    var manager = try LanguageManager.init(allocator);
    defer manager.deinit();

    // Test default fallback
    const default_plugin = manager.getPluginForExtension(".unknown");
    try std.testing.expectEqualStrings("Plain Text", default_plugin.name);

    // Test JSON resolution
    const json_plugin = manager.getPluginForExtension(".json");
    try std.testing.expectEqualStrings("JSON", json_plugin.name);

    // Test Plain Text execution (leak-free check)
    {
        const line = "Hello World";
        const tokens = try default_plugin.highlightLineFn(line, default_plugin.state, allocator);
        defer allocator.free(tokens);

        try std.testing.expectEqual(@as(usize, 1), tokens.len);
        try std.testing.expectEqual(language.TokenType.normal, tokens[0].token_type);
        try std.testing.expectEqual(@as(usize, 0), tokens[0].start);
        try std.testing.expectEqual(line.len, tokens[0].end);
    }

    // Test JSON execution (leak-free check)
    {
        const line = "{\"key\": 123, \"valid\": true}";
        const tokens = try json_plugin.highlightLineFn(line, json_plugin.state, allocator);
        defer allocator.free(tokens);

        // Very basic checks - parsing strings, numbers, keywords, and normal
        try std.testing.expect(tokens.len > 0);
        
        var found_string = false;
        var found_number = false;
        var found_keyword = false;

        for (tokens) |token| {
            switch (token.token_type) {
                .string => found_string = true,
                .number => found_number = true,
                .keyword => found_keyword = true,
                else => {},
            }
        }

        try std.testing.expect(found_string);
        try std.testing.expect(found_number);
        try std.testing.expect(found_keyword);
    }
}
