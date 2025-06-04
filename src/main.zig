const std = @import("std");
const assert = std.debug.assert;

const term = @import("term.zig");
const State = term.State;
const Game = @import("Game.zig");

const GAME_ROWS: usize = 20;
const GAME_COLS: usize = 20;

const GAME_TICK_MS = 1000;

const MIN_ROWS = GAME_ROWS + 2;
const MIN_COLS = GAME_COLS + 2;

const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();
const stdin = std.io.getStdIn().reader();

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debug_allocator.deinit() == .ok);

    const gpa = debug_allocator.allocator();

    var term_state: State = try .init();

    if (term_state.rows < MIN_ROWS or term_state.cols < MIN_COLS) {
        try stderr.print(
            "have term dimensions of {d}x{d}, need at least {d}x{d}\n",
            .{ term_state.cols, term_state.rows, MIN_ROWS, MIN_COLS },
        );

        std.process.exit(1);
    }

    try init(&term_state);
    defer restore(&term_state) catch |err| panicErr("error restoring terminal: {s}", err);

    var game: Game = try .init(gpa, GAME_ROWS, GAME_COLS);
    defer game.deinit();

    try game.setup();

    for (game.board) |row| {
        for (0..row.len) |idx| {
            if (idx % 2 == 0) {
                row[idx] = true;
            }
        }
    }

    var quit = false;
    var timer = std.time.milliTimestamp();

    while (!quit) {
        const new_timer = std.time.milliTimestamp();
        if (new_timer - timer >= GAME_TICK_MS) {
            timer = new_timer;

            try game.tick();
        }
        try game.renderFrame();

        const in = stdin.readByte() catch continue;
        if (in == 'q') {
            quit = true;
        }
    }
}

fn init(term_state: *State) !void {
    try term_state.uncook();
    try stdout.writeAll(term.HIDE_CURSOR);
}

fn restore(term_state: *State) !void {
    try term_state.restore();
    try stdout.writeAll(term.CLEAR_SCREEN);
    try stdout.writeAll(term.SHOW_CURSOR);
    try term.moveCursor(stdout, 1, 1);
}

fn panicErr(comptime fmt: []const u8, err: anyerror) noreturn {
    std.debug.panic(fmt, .{@errorName(err)});
}

test "ref all decls" {
    std.testing.refAllDeclsRecursive(@This());
}
