const std = @import("std");

const assert = std.debug.assert;

const stdout = std.io.getStdOut().writer();
const stdout_handle = std.io.getStdOut().handle;

const stdin = std.io.getStdIn().reader();
const stdin_handle = std.io.getStdIn().handle;

const ESCAPE = '\x1B';

pub const State = struct {
    original: std.posix.termios,
    termios: std.posix.termios,

    pub fn init() !State {
        const original = try std.posix.tcgetattr(stdin_handle);
        return .{ .original = original, .termios = original };
    }

    pub fn uncook(self: *State) !void {
        self.termios.lflag.ECHO = false;
        self.termios.lflag.ICANON = false;
        self.termios.lflag.ISIG = false;
        self.termios.lflag.IEXTEN = false;

        self.termios.iflag.IXON = false;
        self.termios.iflag.ICRNL = false;
        self.termios.iflag.BRKINT = false;
        self.termios.iflag.INPCK = false;
        self.termios.iflag.ISTRIP = false;

        self.termios.oflag.OPOST = false;

        self.termios.cflag.CSIZE = .CS8;

        self.termios.cc[@intFromEnum(std.posix.V.TIME)] = 0;
        self.termios.cc[@intFromEnum(std.posix.V.MIN)] = 1;

        try std.posix.tcsetattr(stdin_handle, .FLUSH, self.termios);
    }

    pub fn restore(self: *State) anyerror!void {
        try std.posix.tcsetattr(std.io.getStdIn().handle, .FLUSH, self.original);
        self.termios = self.original;
    }
};

pub fn readChar() !u8 {
    return try stdin.readByte();
}

pub fn writeChar(comptime fmt: []const u8, args: anytype) !void {
    try stdout.print(fmt, args);
    try stdout.writeAll("\x1b[D");
}

pub fn clearScreen() !void {
    try stdout.writeAll("\x1b[2J");
}

pub fn hideCursor() !void {
    try stdout.writeAll("\x1b[?25l");
}

pub fn resetCursorPos() !void {
    try stdout.writeAll("\x1b[H");
}

pub fn getCursorPos() !struct { row: usize, col: usize } {
    try stdout.writeAll("\x1b[6n");
    var buf: [32]u8 = undefined;

    const esc = try stdin.readUntilDelimiter(&buf, 'R');
    assert(esc.len >= 5);
    assert(esc[0] == '\x1b');
    assert(esc[1] == '[');

    const sep = std.mem.indexOfScalar(u8, esc, ';').?;
    const row = try std.fmt.parseInt(usize, esc[2..sep], 10);
    const col = try std.fmt.parseInt(usize, esc[sep + 1 ..], 10);

    return .{ .row = row, .col = col };
}

pub const Cursor = struct {
    row: usize,
    col: usize,

    term_rows: usize,
    term_cols: usize,

    shown: bool = true,

    pub fn init() !Cursor {
        var buf: std.posix.system.winsize = undefined;
        const errno = std.posix.errno(std.posix.system.ioctl(
            stdout_handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&buf),
        ));

        const pos = try getCursorPos();

        return switch (errno) {
            .SUCCESS => .{
                .row = pos.row,
                .col = pos.col,
                .term_rows = buf.ws_row,
                .term_cols = buf.ws_col,
            },
            else => error.IoctlError,
        };
    }

    pub fn deinit(self: *Cursor) !void {
        try self.move(1, 1);
        try self.show();
    }

    pub fn hide(self: *Cursor) !void {
        try stdout.writeAll("\x1b[?25l");
        self.shown = false;
    }

    pub fn show(self: *Cursor) !void {
        try stdout.writeAll("\x1b[?25h");
        self.shown = true;
    }

    pub fn reset(self: *Cursor) !void {
        try self.show();
        try self.move(1, 1);
    }

    pub fn move(self: *Cursor, row: usize, col: usize) !void {
        assert(row > 0);
        assert(row <= self.term_rows);
        assert(col > 0);
        assert(col <= self.term_cols);
        try stdout.print("\x1b[{d};{d}H", .{ row, col });
        self.row = row;
        self.col = col;
    }

    pub fn moveUp(self: *Cursor) !void {
        assert(self.row > 0);
        if (self.row == 1) return;
        try stdout.writeAll("\x1b[A");
        self.row -= 1;
    }

    pub fn moveDown(self: *Cursor) !void {
        assert(self.row <= self.term_rows);
        if (self.row == self.term_rows) return;
        try stdout.writeAll("\x1b[B");
        self.row += 1;
    }

    pub fn moveRight(self: *Cursor) !void {
        assert(self.col <= self.term_cols);
        if (self.col == self.term_cols) return;
        try stdout.writeAll("\x1b[C");
        self.col += 1;
    }

    pub fn moveLeft(self: *Cursor) !void {
        assert(self.col > 0);
        if (self.col == 1) return;
        try stdout.writeAll("\x1b[D");
        self.col -= 1;
    }

    pub fn writeChar(self: *Cursor, char: u8) !void {
        try stdout.writeByte(char);
        if (self.col == self.term_cols) return;
        self.col += 1;
    }

    pub fn printPos(self: *Cursor) !void {
        const row = self.row;
        const col = self.col;

        try stdout.writeAll("\x1b[s");
        try self.move(1, 1);
        // empty space is to clear old position
        try stdout.print("{d};{d}    ", .{ row, col });
        try stdout.writeAll("\x1b[u");

        self.row = row;
        self.col = col;
    }
};
