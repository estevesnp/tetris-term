const std = @import("std");
const posix = std.posix;

const assert = std.debug.assert;

const stdout_handle = std.io.getStdOut().handle;
const stdin_handle = std.io.getStdIn().handle;

pub const ESCAPE = "\x1B[";

pub const CLEAR_SCREEN = ESCAPE ++ "2J";

pub const MOVE_LEFT = ESCAPE ++ "D";

pub const RESET_BG = ESCAPE ++ "0m";
pub const WHITE_BG = ESCAPE ++ "47m";

pub const HIDE_CURSOR = ESCAPE ++ "?25l";
pub const SHOW_CURSOR = ESCAPE ++ "?25h";

pub const State = struct {
    original: posix.termios,
    termios: posix.termios,
    rows: usize,
    cols: usize,

    pub fn init() !State {
        const original = try posix.tcgetattr(stdin_handle);

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

        self.termios.cc[@intFromEnum(posix.V.TIME)] = 0;
        self.termios.cc[@intFromEnum(posix.V.MIN)] = 0;

        try posix.tcsetattr(stdin_handle, .FLUSH, self.termios);
    }

    pub fn restore(self: *State) anyerror!void {
        try posix.tcsetattr(stdin_handle, .FLUSH, self.original);
        self.termios = self.original;
    }
};

fn getTermSize() !struct { rows: usize, cols: usize } {
    var buf: posix.winsize = undefined;
    const errno = posix.errno(std.posix.system.ioctl(
        stdout_handle,
        posix.T.IOCGWINSZ,
        @intFromPtr(&buf),
    ));

    return switch (errno) {
        .SUCCESS => .{
            .rows = buf.row,
            .cols = buf.col,
        },
        else => error.IoctlError,
    };
}

pub fn moveCursor(writer: anytype, rows: usize, cols: usize) !void {
    assert(rows > 0);
    assert(cols > 0);

    try writer.print(ESCAPE ++ "{d};{d}H", .{ rows, cols });
}

test "ref all decls" {
    std.testing.refAllDeclsRecursive(@This());
}
