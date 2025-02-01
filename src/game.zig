const std = @import("std");
const Game = @This();

board: [][]bool,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Game {
    var board = try allocator.alloc([]bool, rows);
    for (0..rows) |r| {
        const row = try allocator.alloc(bool, cols);
        @memset(row, false);
        board[r] = row;
    }
    return .{ .board = board, .allocator = allocator };
}

pub fn deinit(self: *Game) void {
    for (self.board) |row| {
        self.allocator.free(row);
    }
    self.allocator.free(self.board);
}
