const std = @import("std");

const term = @import("term.zig");
const Game = @import("game.zig");

const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var term_state = try term.State.init();
    defer restore(&term_state) catch @panic("error restoring terminal");

    try setup(&term_state);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var game = try Game.init(allocator, 10, 10);
    defer game.deinit();

    while (true) {
        try term.printPos();
        const char = try term.readChar();
        if (char == 'q') break;

        try term.writeChar("{c}", .{char});
    }
}

fn ctrl(comptime char: u8) u8 {
    comptime {
        if (!std.ascii.isLower(char)) {
            @compileError("character must be a lowercase letter");
        }
        return char - 'a' + 1;
    }
}

fn setup(term_state: *term.State) !void {
    try term_state.uncook();
    try term.clearScreen();
    try term.hideCursor();
    try term.moveCursor(term_state.rows / 2, term_state.cols / 2);
}

fn restore(term_state: *term.State) !void {
    try term_state.restore();
    try term.moveCursor(1, 1);
    try term.showCursor();
}
