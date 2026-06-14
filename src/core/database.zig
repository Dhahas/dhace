const std = @import("std");

/// A mock database connector representing decoupled core business/storage logic.
pub const Database = struct {
    allocator: std.mem.Allocator,
    is_connected: bool,

    /// Creates a new Database instance.
    pub fn init(allocator: std.mem.Allocator) Database {
        return .{
            .allocator = allocator,
            .is_connected = false,
        };
    }

    /// Establishes a simulated connection to the backend store.
    pub fn connect(self: *Database) !void {
        if (self.is_connected) return;
        // Simulating some operation
        self.is_connected = true;
        std.log.info("[Core/DB] Connected to database store.", .{});
    }

    /// Safely terminates the database connection.
    pub fn disconnect(self: *Database) void {
        if (!self.is_connected) return;
        self.is_connected = false;
        std.log.info("[Core/DB] Disconnected from database store.", .{});
    }
};
