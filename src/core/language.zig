const std = @import("std");

/// Represents the different types of tokens that can be highlighted.
/// This enum maps directly to different color themes in the editor UI.
pub const TokenType = enum {
    normal,
    keyword,
    string,
    number,
    comment,
    identifier,
};

/// Represents a tokenized segment of a line.
/// `start` and `end` are byte indices within the line slice.
/// `end` is exclusive, like Zig slice indices.
pub const HighlightToken = struct {
    start: usize,
    end: usize,
    token_type: TokenType,
};

/// The interface that all language plugins must implement.
/// This uses a struct of function pointers to achieve dynamic dispatch without
/// relying on Object-Oriented paradigms.
pub const LanguagePlugin = struct {
    /// The display name of the language (e.g., "JSON", "Plain Text").
    name: []const u8,

    /// A list of file extensions associated with this language (e.g., ".json").
    file_extensions: []const []const u8,

    /// Opaque pointer to the internal state of the plugin, if any.
    state: ?*anyopaque = null,

    /// Initialize the plugin state.
    initFn: ?*const fn (allocator: std.mem.Allocator) anyerror!*anyopaque = null,

    /// Clean up the plugin state.
    deinitFn: ?*const fn (state: ?*anyopaque) void = null,

    /// Tokenize a single line of text.
    /// The plugin must allocate the resulting slice using the provided `allocator`.
    /// The caller is responsible for freeing the returned slice.
    highlightLineFn: *const fn (line: []const u8, state: ?*anyopaque, allocator: std.mem.Allocator) anyerror![]HighlightToken,
};
