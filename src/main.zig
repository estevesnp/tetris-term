const std = @import("std");
const assert = std.debug.assert;

const State = @import("term.zig").State;

const GAME_ROWS: usize = 20;
const GAME_COLS: usize = 20;

const stdin = std.io.getStdIn().writer();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer assert(debug_allocator.deinit() == .ok);

    const gpa = debug_allocator.allocator();

    var term_state: State = try .init();

    if (term_state.rows < GAME_ROWS or term_state.cols < GAME_COLS) {
        try stderr.print(
            "have term dimensions of {d}x{d}, need at least {d}x{d}\n",
            .{ term_state.cols, term_state.rows, GAME_COLS, GAME_ROWS },
        );

        std.process.exit(1);
    }

    try term_state.uncook();
    defer term_state.restore() catch |err| @panic(@errorName(err));

    var game: Game = try .init(gpa, term_state.rows, term_state.cols);
    defer game.deinit();

    std.debug.print("rows: {d}; cols: {d}\r\n", .{ game.rows, game.cols });
}

test "ref all decls" {
    std.testing.refAllDeclsRecursive(@This());
}

const Game = struct {
    arena: *std.heap.ArenaAllocator,
    rows: usize,
    cols: usize,
    board: [][]bool,

    fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Game {
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

    fn deinit(self: *Game) void {
        const allocator = self.arena.child_allocator;
        self.arena.deinit();
        allocator.destroy(self.arena);
    }
};
