const std = @import("std");
const assert = std.debug.assert;

const term = @import("term.zig");

const Game = @This();

const TETRIS_ROWS = 20;
const TETRIS_COLS = 10;

total_rows: usize,
total_cols: usize,
board: [][]bool,

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Game {
    assert(rows > TETRIS_ROWS);
    assert(cols > TETRIS_COLS);

    var board = try allocator.alloc([]bool, TETRIS_ROWS);
    for (0..TETRIS_ROWS) |r| {
        const row = try allocator.alloc(bool, TETRIS_COLS);
        @memset(row, false);
        board[r] = row;
    }
    return .{
        .board = board,
        .total_rows = rows,
        .total_cols = cols,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Game) void {
    for (self.board) |row| {
        self.allocator.free(row);
    }
    self.allocator.free(self.board);
}

fn cena(a: anytype) void {
    _ = a;
}

pub fn drawBoard(self: *Game) !void {
    var buf_stdout = std.io.bufferedWriter(term.stdout);
    const writer = buf_stdout.writer();

    const sidebar_rows = usizeMultFloat(self.total_rows, 0.7);
    const sidebar_cols = usizeMultFloat(self.total_cols, 0.2);

    try term.drawRectangle(writer, 1, 1, self.total_rows, self.total_cols);

    try term.drawRectangle(writer, 2, self.total_cols - sidebar_cols - 1, sidebar_rows, sidebar_cols);

    try buf_stdout.flush();
}

fn usizeMultFloat(u: usize, f: f64) usize {
    const u_as_float: f64 = @floatFromInt(u);
    return @intFromFloat(u_as_float * f);
}
