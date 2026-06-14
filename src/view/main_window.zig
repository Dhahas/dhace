const std = @import("std");
const zgui = @import("zgui");
const App = @import("../app.zig").App;

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
                app.show_open_dialog = true;
                @memset(&app.open_dialog_path_buf, 0);
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

    // 2. Open File Modal Dialog
    if (app.show_open_dialog) {
        zgui.openPopup("Open File Dialog", .{});
    }
    zgui.setNextWindowSize(.{ .w = 400.0, .h = 150.0 });
    if (zgui.beginPopupModal("Open File Dialog", .{})) {
        zgui.text("Enter path to a .txt file:", .{});
        zgui.spacing();

        // Input text for path
        _ = zgui.inputText("##path", .{ .buf = &app.open_dialog_path_buf });

        zgui.spacing();
        zgui.separator();
        zgui.spacing();

        if (zgui.button("Open", .{ .w = 80.0 })) {
            const path = std.mem.sliceTo(&app.open_dialog_path_buf, 0);
            app.openFile(path) catch {};
            app.show_open_dialog = false;
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{ .w = 80.0 })) {
            app.show_open_dialog = false;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
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

    // 4. Editor Page Panel (Centered horizontally, fills height vertically)
    var page_width: f32 = 800.0;
    if (w < 840.0) {
        page_width = w - 40.0;
    }
    const page_x = (w - page_width) / 2.0;
    const page_y = menu_h;
    const page_height = h - menu_h - bottom_h;

    zgui.setNextWindowPos(.{ .x = page_x, .y = page_y });
    zgui.setNextWindowSize(.{ .w = page_width, .h = page_height });

    // Push style to make it look like a clean white sheet of paper
    zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = .{ 1.0, 1.0, 1.0, 1.0 } }); // white background
    zgui.pushStyleColor4f(.{ .idx = .border, .c = .{ 0.85, 0.85, 0.88, 1.0 } }); // soft border
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 20.0, 20.0 } });
    zgui.pushStyleVar1f(.{ .idx = .window_border_size, .v = 1.0 });

    if (zgui.begin("EditorPage", .{
        .flags = .{
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_collapse = true,
            .no_scrollbar = true, // We want the text area scrollbar, not the window scrollbar
            .no_background = false,
        },
    })) {
        // Push colors to hide border of the input text and match white background
        zgui.pushStyleColor4f(.{ .idx = .frame_bg, .c = .{ 1.0, 1.0, 1.0, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .frame_bg_hovered, .c = .{ 1.0, 1.0, 1.0, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .frame_bg_active, .c = .{ 1.0, 1.0, 1.0, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 0.12, 0.12, 0.12, 1.0 } }); // dark text
        zgui.pushStyleVar1f(.{ .idx = .frame_border_size, .v = 0.0 });
        zgui.pushStyleVar2f(.{ .idx = .frame_padding, .v = .{ 0.0, 0.0 } });

        _ = zgui.inputTextMultiline("##EditorInput", .{
            .buf = app.editor_buf,
            .w = -1.0,
            .h = -1.0,
            .flags = .{ .allow_tab_input = true },
        });

        zgui.popStyleVar(.{ .count = 2 });
        zgui.popStyleColor(.{ .count = 4 });
    }
    zgui.end();

    zgui.popStyleVar(.{ .count = 2 });
    zgui.popStyleColor(.{ .count = 2 });

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
