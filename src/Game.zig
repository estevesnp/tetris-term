const std = @import("std");
const term = @import("term.zig");

const Game = @This();

const stdout = std.io.getStdOut().writer();

const init_board_row: usize = 2;
const init_board_col: usize = 2;

arena: *std.heap.ArenaAllocator,
rows: usize,
cols: usize,
board: [][]bool,

pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Game {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = .init(allocator);

    const gpa = arena.allocator();

    const board = try gpa.alloc([]bool, rows);
    for (0..rows) |idx| {
        const row = try gpa.alloc(bool, cols);
        @memset(row, false);

        board[idx] = row;
    }

    return .{
        .arena = arena,
        .rows = rows,
        .cols = cols,
        .board = board,
    };
}

pub fn deinit(self: *Game) void {
    const allocator = self.arena.child_allocator;
    self.arena.deinit();
    allocator.destroy(self.arena);
}

pub fn setup(self: *Game) !void {
    var buf_writer = std.io.bufferedWriter(stdout);
    defer buf_writer.flush() catch |err| panicErr("error flushing stdout: {s}", err);
    const writer = buf_writer.writer();

    const start_row = 1;
    const start_col = 1;

    try writer.writeAll(term.CLEAR_SCREEN);
    try term.moveCursor(writer, 1, 1);

    try writer.writeAll("┌");
    try writer.writeBytesNTimes("─", self.cols);
    try writer.writeAll("┐\n" ++ term.MOVE_LEFT);

    try writer.writeBytesNTimes("│\n" ++ term.MOVE_LEFT, self.rows);

    try term.moveCursor(writer, start_row + 1, start_col);

    try writer.writeBytesNTimes("│\n" ++ term.MOVE_LEFT, self.rows);

    try writer.writeAll("└");
    try writer.writeBytesNTimes("─", self.cols);
    try writer.writeAll("┘");
}

pub fn renderFrame(self: *Game) !void {
    var buf_writer = std.io.bufferedWriter(stdout);
    defer buf_writer.flush() catch |err| panicErr("error flushing stdout: {s}", err);
    const writer = buf_writer.writer();

    var curr_row = init_board_row;

    for (self.board) |rows| {
        try term.moveCursor(writer, curr_row, init_board_col);

        for (rows) |filled| {
            if (filled) {
                try writer.writeAll(term.WHITE_BG ++ " " ++ term.RESET_BG);
            } else {
                try writer.writeByte(' ');
            }
        }

        curr_row += 1;
    }
}

pub fn tick(self: *Game) !void {
    for (self.board) |row| {
        for (0..row.len) |idx| {
            row[idx] = !row[idx];
        }
    }
}

fn panicErr(comptime fmt: []const u8, err: anyerror) noreturn {
    std.debug.panic(fmt, .{@errorName(err)});
}

test "ref all decls" {
    std.testing.refAllDeclsRecursive(@This());
}
