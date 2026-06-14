const std = @import("std");
const language = @import("../core/language.zig");
const HighlightToken = language.HighlightToken;
const TokenType = language.TokenType;
const LanguagePlugin = language.LanguagePlugin;

fn isWhitespace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\r' or c == '\n';
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn highlightLine(line: []const u8, state: ?*anyopaque, allocator: std.mem.Allocator) anyerror![]HighlightToken {
    _ = state;
    var tokens = std.ArrayList(HighlightToken).empty;
    errdefer tokens.deinit(allocator);

    var i: usize = 0;
    while (i < line.len) {
        if (isWhitespace(line[i])) {
            i += 1;
            continue;
        }

        // Strings
        if (line[i] == '"') {
            const start = i;
            i += 1;
            while (i < line.len and line[i] != '"') {
                if (line[i] == '\\' and i + 1 < line.len) {
                    i += 2; // skip escaped characters
                } else {
                    i += 1;
                }
            }
            if (i < line.len) i += 1; // consume closing quote
            try tokens.append(allocator, .{ .start = start, .end = i, .token_type = .string });
            continue;
        }

        // Numbers (simplistic parsing for demo)
        if (isDigit(line[i]) or line[i] == '-') {
            const start = i;
            i += 1;
            while (i < line.len and (isDigit(line[i]) or line[i] == '.' or line[i] == 'e' or line[i] == 'E' or line[i] == '+' or line[i] == '-')) {
                i += 1;
            }
            try tokens.append(allocator, .{ .start = start, .end = i, .token_type = .number });
            continue;
        }

        // Keywords
        const keywords = [_][]const u8{ "true", "false", "null" };
        var found_keyword = false;
        for (keywords) |kw| {
            if (i + kw.len <= line.len and std.mem.eql(u8, line[i .. i + kw.len], kw)) {
                // Ensure it's not a prefix of another word
                if (i + kw.len == line.len or !std.ascii.isAlphanumeric(line[i + kw.len])) {
                    const start = i;
                    i += kw.len;
                    try tokens.append(allocator, .{ .start = start, .end = i, .token_type = .keyword });
                    found_keyword = true;
                    break;
                }
            }
        }
        if (found_keyword) continue;

        // Identifiers / normal (e.g., braces, brackets, commas, colons)
        const start = i;
        i += 1;
        try tokens.append(allocator, .{ .start = start, .end = i, .token_type = .normal });
    }

    // Fill gaps with normal tokens (if we want full coverage), 
    // or we can assume gaps are normal/whitespace.
    // For simplicity, we just return the parsed tokens. The caller can map everything else to .normal.
    return tokens.toOwnedSlice(allocator);
}

pub const plugin = LanguagePlugin{
    .name = "JSON",
    .file_extensions = &[_][]const u8{".json"},
    .state = null,
    .initFn = null,
    .deinitFn = null,
    .highlightLineFn = highlightLine,
};
