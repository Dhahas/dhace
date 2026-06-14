const std = @import("std");
const language = @import("../core/language.zig");
const HighlightToken = language.HighlightToken;
const TokenType = language.TokenType;
const LanguagePlugin = language.LanguagePlugin;

/// Highlight function for plain text. Returns a single token of type `.normal` covering the whole line.
fn highlightLine(line: []const u8, state: ?*anyopaque, allocator: std.mem.Allocator) anyerror![]HighlightToken {
    _ = state;
    var tokens = try allocator.alloc(HighlightToken, 1);
    tokens[0] = HighlightToken{
        .start = 0,
        .end = line.len,
        .token_type = .normal,
    };
    return tokens;
}

pub const plugin = LanguagePlugin{
    .name = "Plain Text",
    .file_extensions = &[_][]const u8{".txt", ".md", ".log"},
    .state = null,
    .initFn = null,
    .deinitFn = null,
    .highlightLineFn = highlightLine,
};
