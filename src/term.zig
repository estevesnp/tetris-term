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
    rows: usize,
    cols: usize,

    pub fn init() !State {
        const original = try std.posix.tcgetattr(stdin_handle);

        const term_size = try getTermSize();

        return .{
            .original = original,
            .termios = original,
            .rows = term_size.rows,
            .cols = term_size.cols,
        };
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
    while (true) {
        const char = try stdin.readByte();
        if (std.ascii.isControl(char)) continue;
        if (char != '\x1b') return char;

        while (true) {
            const c = try stdin.readByte();
            if (std.ascii.isAlphabetic(c) or c == '~') break;
        }
    }
}

pub fn writeChar(comptime fmt: []const u8, args: anytype) !void {
    try stdout.print(fmt, args);
    try stdout.writeAll("\x1b[D");
}

pub fn clearScreen() !void {
    try stdout.writeAll("\x1b[2J");
}

pub fn clearRow() !void {
    try stdout.writeAll("\x1b[2K");
}

pub fn hideCursor() !void {
    try stdout.writeAll("\x1b[?25l");
}

pub fn showCursor() !void {
    try stdout.writeAll("\x1b[?25h");
}

pub fn moveCursor(rows: usize, cols: usize) !void {
    assert(rows > 0);
    assert(cols > 0);

    try stdout.print("\x1b[{d};{d}H", .{ rows, cols });
}

pub fn storePos() !void {
    try stdout.writeAll("\x1b[s");
}

pub fn restorePos() !void {
    try stdout.writeAll("\x1b[u");
}

pub fn getTermSize() !struct { rows: usize, cols: usize } {
    var buf: std.posix.system.winsize = undefined;
    const errno = std.posix.errno(std.posix.system.ioctl(
        stdout_handle,
        std.posix.T.IOCGWINSZ,
        @intFromPtr(&buf),
    ));

    return switch (errno) {
        .SUCCESS => .{
            .rows = buf.ws_row,
            .cols = buf.ws_col,
        },
        else => error.IoctlError,
    };
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

pub fn printPos() !void {
    const cur_pos = try getCursorPos();
    try storePos();
    try moveCursor(1, 1);
    try stdout.print("{d};{d}    ", .{ cur_pos.row, cur_pos.col });
    try restorePos();
}
