const std = @import("std");
const posix = std.posix;

const stdout_handle = std.io.getStdOut().handle;
const stdin_handle = std.io.getStdIn().handle;

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
        self.termios.cc[@intFromEnum(posix.V.MIN)] = 1;

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

test "ref all decls" {
    std.testing.refAllDeclsRecursive(@This());
}
