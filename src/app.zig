const std = @import("std");
const Database = @import("core/database.zig").Database;

/// Represents the global application state.
/// This acts as the single source of truth for the entire application.
pub const App = struct {
    allocator: std.mem.Allocator,

    // Core database connector
    db: Database,

    // UI state flags
    show_settings: bool = false,
    counter: i32 = 0,
    database_connected: bool = false,

    /// Initializes and returns the global App state structure.
    pub fn init(allocator: std.mem.Allocator) !*App {
        const self = try allocator.create(App);
        self.* = .{
            .allocator = allocator,
            .db = Database.init(allocator),
        };
        return self;
    }

    /// Cleans up any resources allocated by the app.
    pub fn deinit(self: *App) void {
        self.db.disconnect();
        self.allocator.destroy(self);
    }

    /// Mutator method to increment the internal counter.
    pub fn incrementCounter(self: *App) void {
        self.counter += 1;
    }

    /// Toggles the connection status of the database and triggers internal logic.
    pub fn toggleDatabaseConnection(self: *App) void {
        if (self.database_connected) {
            self.db.disconnect();
            self.database_connected = false;
        } else {
            self.db.connect() catch |err| {
                std.log.err("Failed to connect database: {}", .{err});
                return;
            };
            self.database_connected = true;
        }
    }
};
