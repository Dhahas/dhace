const std = @import("std");
const zgui = @import("zgui");
const nfd = @import("nfd");
const App = @import("../app.zig").App;
const editor_canvas = @import("editor_canvas.zig");

pub fn render(app: *App, w: f32, h: f32) void {
    // Menu bar height is typically around 25 pixels.
    // Bottom panel height is 35 pixels.
    const menu_h: f32 = 25.0;
    const bottom_h: f32 = 35.0;

    // 1. Main Menu Bar
    if (zgui.beginMainMenuBar()) {
        if (zgui.beginMenu("File", true)) {
            if (zgui.menuItem("New", .{})) {
                app.clearFile();
            }
            if (zgui.menuItem("Open...", .{})) {
                const filter = app.language_manager.getAllExtensionsFilter(app.allocator) catch null;
                defer if (filter != null) app.allocator.free(filter.?);

                if (nfd.openFileDialog(filter, null) catch null) |path| {
                    defer nfd.freePath(path);

                    // Path from nfd is a null-terminated C string, convert to zig slice
                    const path_slice = std.mem.sliceTo(path, 0);
                    app.openFile(path_slice) catch {};
                }
            }
            if (zgui.menuItem("Save", .{ .enabled = app.file_path != null })) {
                app.saveFile() catch {};
            }
            zgui.separator();
            if (zgui.menuItem("Exit", .{})) {
                std.process.exit(0);
            }
            zgui.endMenu();
        }
        if (zgui.beginMenu("Help", true)) {
            if (zgui.menuItem("About", .{})) {
                app.show_about_dialog = true;
            }
            zgui.endMenu();
        }
        zgui.endMainMenuBar();
    }

    // 3. About Modal Dialog
    if (app.show_about_dialog) {
        zgui.openPopup("About dhace", .{});
    }
    zgui.setNextWindowSize(.{ .w = 300.0, .h = 120.0 });
    if (zgui.beginPopupModal("About dhace", .{})) {
        zgui.text("dhace - Minimalistic Code Editor", .{});
        zgui.text("Built with Zig and Dear ImGui.", .{});
        zgui.spacing();
        zgui.separator();
        zgui.spacing();
        if (zgui.button("Close", .{ .w = 80.0 })) {
            app.show_about_dialog = false;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }

    // 4. Editor Page Panel (80% of width, centered, 100% of available height)
    const page_width = w * 0.8;
    const page_x = (w - page_width) / 2.0;
    const page_y = menu_h;
    const page_height = h - menu_h - bottom_h;

    zgui.setNextWindowPos(.{ .x = page_x, .y = page_y });
    editor_canvas.renderEditorCanvas(app, page_width, page_height);

    // 5. Bottom Panel (Vim-like, 100% width)
    zgui.setNextWindowPos(.{ .x = 0.0, .y = h - bottom_h });
    zgui.setNextWindowSize(.{ .w = w, .h = bottom_h });

    // Stylize the bottom panel background
    zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = .{ 0.94, 0.94, 0.96, 1.0 } });
    zgui.pushStyleColor4f(.{ .idx = .border, .c = .{ 0.85, 0.85, 0.88, 1.0 } });
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 10.0, 6.0 } });
    zgui.pushStyleVar1f(.{ .idx = .window_border_size, .v = 1.0 });

    if (zgui.begin("BottomPanel", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
        .no_scrollbar = true,
    } })) {
        zgui.alignTextToFramePadding();

        const status = std.mem.sliceTo(&app.status_message, 0);
        zgui.textColored(.{ 0.3, 0.3, 0.3, 1.0 }, "Status: {s}", .{status});

        zgui.sameLine(.{});

        const last_act = std.mem.sliceTo(&app.last_action_message, 0);
        if (last_act.len > 0) {
            zgui.textColored(.{ 0.2, 0.5, 0.2, 1.0 }, " | Action: {s}", .{last_act});
        }

        // Align right for input text and send button
        const input_width: f32 = 250.0;
        const button_width: f32 = 70.0;
        const spacing = zgui.getStyle().item_spacing[0];
        const right_x = w - input_width - button_width - spacing - 20.0;

        zgui.sameLine(.{ .offset_from_start_x = right_x });

        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = .{ 5.0, 3.0 } });

        _ = zgui.inputText("##cmd_input", .{ .buf = &app.cmd_input_buf });

        zgui.sameLine(.{});

        // Violet-blue styled button
        zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.31, 0.27, 0.90, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .button_hovered, .c = .{ 0.39, 0.40, 0.95, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .button_active, .c = .{ 0.22, 0.19, 0.64, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1.0, 1.0, 1.0, 1.0 } });

        if (zgui.button("Send", .{ .w = button_width })) {
            const msg = std.mem.sliceTo(&app.cmd_input_buf, 0);
            if (msg.len > 0) {
                @memset(&app.last_action_message, 0);
                @memcpy(app.last_action_message[0..msg.len], msg);
                @memset(&app.cmd_input_buf, 0);
            }
        }

        zgui.popStyleColor(.{ .count = 4 });
        zgui.popStyleVar(.{ .count = 1 });
    }
    zgui.end();

    zgui.popStyleVar(.{ .count = 2 });
    zgui.popStyleColor(.{ .count = 2 });
}
