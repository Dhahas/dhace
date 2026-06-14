const std = @import("std");
const zgui = @import("zgui");
const App = @import("../app.zig").App;
const TokenType = @import("../core/language.zig").TokenType;

pub fn renderEditorCanvas(app: *App, width: f32, height: f32) void {
    zgui.setNextWindowSize(.{ .w = width, .h = height });
    
    zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = .{ 1.0, 1.0, 1.0, 1.0 } }); // white background
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 10.0, 10.0 } });
    
    if (zgui.begin("EditorCanvas", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .horizontal_scrollbar = true,
            .no_bring_to_front_on_focus = true,
        },
    })) {
        const draw_list = zgui.getWindowDrawList();
        const base_pos = zgui.getCursorScreenPos();
        const line_height = zgui.getTextLineHeight();
        
        // Handle input if window is focused
        if (zgui.isWindowFocused(.{})) {
            handleInput(app);
        }

        const scroll_y = zgui.getScrollY();
        const first_visible_line = @as(usize, @intFromFloat(scroll_y / line_height));
        const visible_lines_count = @as(usize, @intFromFloat(height / line_height)) + 2;

        const start_line = first_visible_line;
        var end_line = start_line + visible_lines_count;
        if (end_line > app.editor_buf.lines.items.len) {
            end_line = app.editor_buf.lines.items.len;
        }

        // Dummy to force scrollbar bounds
        const total_height = @as(f32, @floatFromInt(app.editor_buf.lines.items.len)) * line_height;
        zgui.dummy(.{ .w = 1.0, .h = total_height });

        // Get extension for highlighting
        const ext = if (app.file_path) |p| std.fs.path.extension(p) else ".txt";
        const plugin = app.language_manager.getPluginForExtension(ext);

        var y_pos = base_pos[1] + (@as(f32, @floatFromInt(start_line)) * line_height);

        for (start_line..end_line) |line_idx| {
            const line = app.editor_buf.lines.items[line_idx];
            
            // Draw Cursor
            if (line_idx == app.editor_buf.cursor_line and zgui.isWindowFocused(.{})) {
                // simple blink
                // simple solid cursor for now to ensure compilation
                if (true) {
                    const text_up_to_cursor = line.items[0..app.editor_buf.cursor_col];
                    const text_size = zgui.calcTextSize(text_up_to_cursor, .{});
                    const cursor_x = base_pos[0] + text_size[0];
                    draw_list.addLine(.{
                        .p1 = .{ cursor_x, y_pos },
                        .p2 = .{ cursor_x, y_pos + line_height },
                        .col = zgui.colorConvertFloat4ToU32(.{ 0.0, 0.0, 0.0, 1.0 })
                    });
                }
            }

            if (line.items.len == 0) {
                y_pos += line_height;
                continue;
            }

            const tokens = plugin.highlightLineFn(line.items, plugin.state, app.allocator) catch continue;
            defer app.allocator.free(tokens);

            var x_pos = base_pos[0];

            for (tokens) |token| {
                const token_str = line.items[token.start..token.end];
                const color = getColorForToken(token.token_type);
                
                draw_list.addText(
                    .{ x_pos, y_pos },
                    zgui.colorConvertFloat4ToU32(color),
                    "{s}",
                    .{token_str}
                );
                
                const token_size = zgui.calcTextSize(token_str, .{});
                x_pos += token_size[0];
            }

            y_pos += line_height;
        }
    }
    zgui.end();
    
    zgui.popStyleVar(.{ .count = 1 });
    zgui.popStyleColor(.{ .count = 1 });
}

fn handleInput(app: *App) void {
    if (zgui.isKeyPressed(.up_arrow, true)) app.editor_buf.moveCursorUp();
    if (zgui.isKeyPressed(.down_arrow, true)) app.editor_buf.moveCursorDown();
    if (zgui.isKeyPressed(.left_arrow, true)) app.editor_buf.moveCursorLeft();
    if (zgui.isKeyPressed(.right_arrow, true)) app.editor_buf.moveCursorRight();
    if (zgui.isKeyPressed(.back_space, true)) app.editor_buf.backspace() catch {};
    if (zgui.isKeyPressed(.enter, true)) app.editor_buf.insertNewline() catch {};
    
    // Consume char queue
    for (app.char_queue.items) |c| {
        app.editor_buf.insertChar(c) catch {};
    }
    app.char_queue.clearRetainingCapacity();
}

fn getColorForToken(t: TokenType) [4]f32 {
    return switch (t) {
        .keyword => .{ 0.8, 0.2, 0.8, 1.0 }, // Purple
        .string => .{ 0.2, 0.6, 0.2, 1.0 },  // Green
        .number => .{ 0.8, 0.4, 0.1, 1.0 },  // Orange
        .comment => .{ 0.5, 0.5, 0.5, 1.0 }, // Gray
        .identifier => .{ 0.1, 0.3, 0.8, 1.0 }, // Blue
        .normal => .{ 0.1, 0.1, 0.1, 1.0 },  // Dark
    };
}
