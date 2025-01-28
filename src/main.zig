const std = @import("std");

const term = @import("term.zig");

const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var term_state = try term.State.init();
    defer term_state.restore() catch std.debug.print("error restoring term", .{});

    try term_state.uncook();
    try term.clearScreen();

    var cursor = try term.Cursor.init();
    defer cursor.deinit() catch std.debug.print("error restoring cursor", .{});

    while (true) {
        const char = try term.readChar();
        if (char == comptime ctrl('q')) break;

        switch (char) {
            'h' => try cursor.moveLeft(),
            'j' => try cursor.moveDown(),
            'k' => try cursor.moveUp(),
            'l' => try cursor.moveRight(),
            else => {
                if (!std.ascii.isPrint(char)) continue;
                try cursor.writeChar(char);
            },
        }
        try cursor.printPos();
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
